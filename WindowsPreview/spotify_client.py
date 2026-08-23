from __future__ import annotations

from dataclasses import dataclass
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
import base64
import hashlib
import json
import os
import secrets
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser

from lyricar_core import PlaybackState, Track


class SpotifyError(RuntimeError):
    pass


@dataclass
class SpotifyConfiguration:
    client_id: str
    redirect_uri: str = "http://127.0.0.1:8765/callback"


class SpotifyClient:
    scopes = "user-read-currently-playing user-read-playback-state user-modify-playback-state"

    def __init__(self, configuration: SpotifyConfiguration, token_path: Path | None = None) -> None:
        self.configuration = configuration
        if token_path is None:
            root = Path(os.environ.get("LOCALAPPDATA", Path.home() / ".config"))
            token_path = root / "LyriCar" / "spotify_token.json"
        self.token_path = token_path
        self.token_path.parent.mkdir(parents=True, exist_ok=True)
        self.authorization_url_path = self.token_path.parent / "spotify_authorization_url.txt"
        self._token_lock = threading.Lock()
        self._token = self._load_token()

    @property
    def is_authenticated(self) -> bool:
        return bool(self._token and self._token.get("refresh_token"))

    def authenticate(self, timeout: float = 180.0) -> None:
        if not self.configuration.client_id.strip():
            raise SpotifyError("Inserisci prima lo Spotify Client ID")
        verifier = self._base64url(secrets.token_bytes(64))
        challenge = self._base64url(hashlib.sha256(verifier.encode("ascii")).digest())
        state = secrets.token_urlsafe(24)
        redirect = urllib.parse.urlparse(self.configuration.redirect_uri)
        if redirect.scheme != "http" or redirect.hostname != "127.0.0.1":
            raise SpotifyError("La preview richiede un redirect loopback http://127.0.0.1")
        port = redirect.port or 80
        callback_path = redirect.path or "/"
        result: dict[str, str] = {}
        completed = threading.Event()

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):  # noqa: N802
                parsed = urllib.parse.urlparse(self.path)
                query = urllib.parse.parse_qs(parsed.query)
                if parsed.path == callback_path:
                    if "code" in query:
                        result["code"] = query["code"][0]
                    if "state" in query:
                        result["state"] = query["state"][0]
                    if "error" in query:
                        result["error"] = query["error"][0]
                    body = (
                        "<html><body style='background:#101114;color:white;font-family:sans-serif;'>"
                        "<h2>LyriCar collegata a Spotify.</h2><p>Puoi chiudere questa scheda.</p>"
                        "</body></html>"
                    ).encode("utf-8")
                    self.send_response(200)
                    self.send_header("Content-Type", "text/html; charset=utf-8")
                    self.send_header("Content-Length", str(len(body)))
                    self.end_headers()
                    self.wfile.write(body)
                    completed.set()
                else:
                    self.send_error(404)

            def log_message(self, _format, *_args):
                return

        server = HTTPServer((redirect.hostname or "127.0.0.1", port), Handler)
        server.timeout = 0.5
        authorize_url = "https://accounts.spotify.com/authorize?" + urllib.parse.urlencode(
            {
                "client_id": self.configuration.client_id,
                "response_type": "code",
                "redirect_uri": self.configuration.redirect_uri,
                "scope": self.scopes,
                "code_challenge_method": "S256",
                "code_challenge": challenge,
                "state": state,
            }
        )
        try:
            self._open_authorization_url(authorize_url)
        except Exception:
            server.server_close()
            raise
        deadline = time.monotonic() + timeout
        try:
            while not completed.is_set() and time.monotonic() < deadline:
                server.handle_request()
        finally:
            server.server_close()
        if not completed.is_set():
            raise SpotifyError("Autenticazione Spotify scaduta")
        if result.get("error"):
            raise SpotifyError(f"Spotify: {result['error']}")
        if result.get("state") != state or not result.get("code"):
            raise SpotifyError("Risposta OAuth Spotify non valida")

        token = self._token_request(
            {
                "client_id": self.configuration.client_id,
                "grant_type": "authorization_code",
                "code": result["code"],
                "redirect_uri": self.configuration.redirect_uri,
                "code_verifier": verifier,
            }
        )
        self._store_token(token)

    def disconnect(self) -> None:
        with self._token_lock:
            self._token = None
            try:
                self.token_path.unlink()
            except FileNotFoundError:
                pass

    def current_playback(self) -> PlaybackState | None:
        payload = self._api_json("GET", "/v1/me/player", allow_no_content=True)
        if not payload or not payload.get("item"):
            return None
        item = payload["item"]
        if item.get("type") not in (None, "track"):
            return None
        artists = [artist.get("name", "") for artist in item.get("artists", []) if artist.get("name")]
        album = item.get("album") or {}
        images = album.get("images") or []
        track = Track(
            track_id=item.get("id"),
            title=item.get("name") or "Brano sconosciuto",
            artists=artists,
            album=album.get("name"),
            duration=float(item.get("duration_ms") or 0) / 1000.0,
            artwork_url=images[0].get("url") if images else None,
        )
        return PlaybackState(
            track=track,
            position=float(payload.get("progress_ms") or 0) / 1000.0,
            is_playing=bool(payload.get("is_playing")),
        )

    def play(self) -> None:
        self._api_json("PUT", "/v1/me/player/play", allow_no_content=True)

    def pause(self) -> None:
        self._api_json("PUT", "/v1/me/player/pause", allow_no_content=True)

    def next(self) -> None:
        self._api_json("POST", "/v1/me/player/next", allow_no_content=True)

    def previous(self) -> None:
        self._api_json("POST", "/v1/me/player/previous", allow_no_content=True)

    def _api_json(
        self,
        method: str,
        path: str,
        allow_no_content: bool = False,
        *,
        retried_auth: bool = False,
        retried_rate_limit: bool = False,
        retried_server_error: bool = False,
    ):
        token = self._valid_access_token()
        request = urllib.request.Request(
            f"https://api.spotify.com{path}",
            method=method,
            headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                data = response.read()
                if not data and allow_no_content:
                    return None
                return json.loads(data.decode("utf-8")) if data else None
        except urllib.error.HTTPError as exc:
            if exc.code == 204 and allow_no_content:
                return None
            if exc.code == 401 and not retried_auth:
                self._refresh_token(force=True)
                return self._api_json(
                    method,
                    path,
                    allow_no_content,
                    retried_auth=True,
                    retried_rate_limit=retried_rate_limit,
                    retried_server_error=retried_server_error,
                )
            if exc.code == 403:
                raise SpotifyError(
                    "Spotify ha rifiutato il comando: verifica Premium, allowlist e dispositivo attivo"
                ) from exc
            if exc.code == 429 and not retried_rate_limit:
                retry_after = float(exc.headers.get("Retry-After", "2"))
                time.sleep(min(max(retry_after, 0.5), 10.0))
                return self._api_json(
                    method,
                    path,
                    allow_no_content,
                    retried_auth=retried_auth,
                    retried_rate_limit=True,
                    retried_server_error=retried_server_error,
                )
            if 500 <= exc.code <= 599 and not retried_server_error:
                time.sleep(0.75)
                return self._api_json(
                    method,
                    path,
                    allow_no_content,
                    retried_auth=retried_auth,
                    retried_rate_limit=retried_rate_limit,
                    retried_server_error=True,
                )
            if exc.code == 404:
                raise SpotifyError("Nessun dispositivo Spotify attivo trovato") from exc
            if exc.code == 429:
                raise SpotifyError("Limite temporaneo Spotify raggiunto") from exc
            details = exc.read().decode("utf-8", errors="replace")
            raise SpotifyError(f"Spotify HTTP {exc.code}: {details[:250]}") from exc
        except urllib.error.URLError as exc:
            raise SpotifyError(f"Spotify non raggiungibile: {exc.reason}") from exc

    def _valid_access_token(self) -> str:
        if not self._token:
            raise SpotifyError("Spotify non collegata")
        if float(self._token.get("expires_at", 0)) <= time.time() + 60:
            self._refresh_token()
        if not self._token or not self._token.get("access_token"):
            raise SpotifyError("Token Spotify non disponibile")
        return str(self._token["access_token"])

    def _refresh_token(self, force: bool = False) -> None:
        with self._token_lock:
            if not self._token or not self._token.get("refresh_token"):
                raise SpotifyError("Ricollega Spotify")
            if not force and float(self._token.get("expires_at", 0)) > time.time() + 60:
                return
            refreshed = self._token_request(
                {
                    "client_id": self.configuration.client_id,
                    "grant_type": "refresh_token",
                    "refresh_token": self._token["refresh_token"],
                }
            )
            if not refreshed.get("refresh_token"):
                refreshed["refresh_token"] = self._token["refresh_token"]
            self._store_token(refreshed, lock_already_held=True)

    def _token_request(self, values: dict) -> dict:
        request = urllib.request.Request(
            "https://accounts.spotify.com/api/token",
            data=urllib.parse.urlencode(values).encode("utf-8"),
            method="POST",
            headers={"Content-Type": "application/x-www-form-urlencoded"},
        )
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                token = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            raise SpotifyError(f"Token Spotify rifiutato (HTTP {exc.code})") from exc
        token["expires_at"] = time.time() + float(token.get("expires_in", 3600))
        return token

    def _load_token(self) -> dict | None:
        try:
            token = json.loads(self.token_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return None
        stored_client_id = str(token.get("client_id", "")).strip()
        if stored_client_id and stored_client_id != self.configuration.client_id.strip():
            return None
        return token

    def _store_token(self, token: dict, lock_already_held: bool = False) -> None:
        def store() -> None:
            token["client_id"] = self.configuration.client_id.strip()
            self._token = token
            self.token_path.write_text(json.dumps(token, indent=2), encoding="utf-8")

        if lock_already_held:
            store()
        else:
            with self._token_lock:
                store()

    def _open_authorization_url(self, url: str) -> None:
        try:
            self.authorization_url_path.write_text(url, encoding="utf-8")
        except OSError:
            pass

        opened = False
        if os.name == "nt":
            try:
                os.startfile(url)  # type: ignore[attr-defined]
                opened = True
            except (AttributeError, OSError):
                opened = False
        if not opened:
            try:
                opened = bool(webbrowser.open_new_tab(url))
            except webbrowser.Error:
                opened = False
        if not opened:
            raise SpotifyError(
                "Windows non è riuscito ad aprire il browser. "
                f"Apri manualmente il collegamento salvato in: {self.authorization_url_path}"
            )

    @staticmethod
    def _base64url(data: bytes) -> str:
        return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")
