import Foundation

public enum LyricsCacheLookup: Sendable {
    case hit(LyricsDocument)
    case cachedMiss
    case absent
}

public actor LyricsCache {
    private struct CacheRecord: Codable {
        enum Kind: String, Codable {
            case hit
            case miss
        }

        var version: Int
        var kind: Kind
        var storedAt: Date
        var document: LyricsDocument?
    }

    private let directory: URL
    private let hitTTL: TimeInterval
    private let missTTL: TimeInterval
    private let fileManager: FileManager

    public init(
        directory: URL,
        hitTTL: TimeInterval = 30 * 24 * 60 * 60,
        missTTL: TimeInterval = 24 * 60 * 60,
        fileManager: FileManager = .default
    ) throws {
        self.directory = directory
        self.hitTTL = hitTTL
        self.missTTL = missTTL
        self.fileManager = fileManager
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func lookup(_ track: TrackIdentity, now: Date = Date()) -> LyricsCacheLookup {
        let url = fileURL(for: track)
        guard let data = try? Data(contentsOf: url),
              let record = try? decodeRecord(from: data),
              record.version == 1 else {
            return .absent
        }

        let ttl = record.kind == .hit ? hitTTL : missTTL
        guard now.timeIntervalSince(record.storedAt) <= ttl else {
            try? fileManager.removeItem(at: url)
            return .absent
        }

        if record.kind == .miss { return .cachedMiss }
        guard let document = record.document else { return .absent }
        return .hit(document)
    }

    public func store(_ document: LyricsDocument, for track: TrackIdentity, now: Date = Date()) throws {
        let record = CacheRecord(version: 1, kind: .hit, storedAt: now, document: document)
        try write(record, to: fileURL(for: track))
    }

    public func storeMiss(for track: TrackIdentity, now: Date = Date()) throws {
        let record = CacheRecord(version: 1, kind: .miss, storedAt: now, document: nil)
        try write(record, to: fileURL(for: track))
    }

    public func clear() throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        for item in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
            try? fileManager.removeItem(at: item)
        }
    }

    private func fileURL(for track: TrackIdentity) -> URL {
        directory.appendingPathComponent(StableHash.fnv1a64(track.stableCacheKey)).appendingPathExtension("json")
    }

    private func decodeRecord(from data: Data) throws -> CacheRecord {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CacheRecord.self, from: data)
    }

    private func write(_ record: CacheRecord, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let decoderSafeRecord = record
        let data = try encoder.encode(decoderSafeRecord)
        try data.write(to: url, options: .atomic)
    }
}
