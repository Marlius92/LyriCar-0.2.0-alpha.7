#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CarPlay/CarPlay.h>
#import <MediaPlayer/MediaPlayer.h>

@interface LyriCarLyricLine : NSObject
@property(nonatomic, assign) NSTimeInterval time;
@property(nonatomic, copy) NSString *text;
@end

@implementation LyriCarLyricLine
@end

static CPInterfaceController *LyriCarInterfaceController = nil;
static CPNowPlayingImageButton *LyriCarLyricsButton = nil;
static CPListTemplate *LyriCarLyricsTemplate = nil;
static NSArray<LyriCarLyricLine *> *LyriCarSyncedLines = nil;
static NSString *LyriCarLoadedTrackKey = nil;
static BOOL LyriCarLyricsLoading = NO;
static NSTimer *LyriCarCarPlayWatcher = nil;
static NSTimer *LyriCarLyricsTimer = nil;
static NSInteger LyriCarLastRenderedIndex = NSNotFound;

static CPInterfaceController *LyriCarFindCarPlayInterfaceController(void) {
    if (@available(iOS 13.0, *)) {
        NSSet<UIScene *> *scenes = UIApplication.sharedApplication.connectedScenes;
        for (UIScene *scene in scenes) {
            if ([scene isKindOfClass:CPTemplateApplicationScene.class]) {
                CPTemplateApplicationScene *carPlayScene = (CPTemplateApplicationScene *)scene;
                if (carPlayScene.interfaceController != nil) {
                    return carPlayScene.interfaceController;
                }
            }
        }
    }
    return nil;
}

static id LyriCarNowPlayingInfoValue(NSString *key) {
    return MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo[key];
}

static NSString *LyriCarNowPlayingString(NSString *key, NSString *fallback) {
    id value = LyriCarNowPlayingInfoValue(key);
    if ([value isKindOfClass:NSString.class] && [(NSString *)value length] > 0) {
        return (NSString *)value;
    }
    return fallback;
}

static NSTimeInterval LyriCarNowPlayingNumber(NSString *key, NSTimeInterval fallback) {
    id value = LyriCarNowPlayingInfoValue(key);
    if ([value respondsToSelector:@selector(doubleValue)]) {
        return [value doubleValue];
    }
    return fallback;
}

static NSTimeInterval LyriCarPlaybackPosition(void) {
    NSDictionary *info = MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo;
    if (info.count == 0) {
        return 0;
    }

    NSTimeInterval elapsed = LyriCarNowPlayingNumber(MPNowPlayingInfoPropertyElapsedPlaybackTime, 0);
    double rate = LyriCarNowPlayingNumber(MPNowPlayingInfoPropertyPlaybackRate, 0);

    // MPNowPlayingInfoCenter normally keeps elapsed time current. Avoid trying to
    // extrapolate from private Spotify clocks here; the row-level refresh below
    // is conservative and re-reads the public now-playing position frequently.
    if (rate < 0) {
        rate = 0;
    }
    return MAX(0, elapsed);
}

static NSString *LyriCarCurrentTrackKey(void) {
    NSString *title = LyriCarNowPlayingString(MPMediaItemPropertyTitle, @"");
    NSString *artist = LyriCarNowPlayingString(MPMediaItemPropertyArtist, @"");
    NSTimeInterval duration = LyriCarNowPlayingNumber(MPMediaItemPropertyPlaybackDuration, 0);
    return [NSString stringWithFormat:@"%@|%@|%.0f", title, artist, duration];
}

static NSString *LyriCarURLEncode(NSString *value) {
    NSCharacterSet *allowed = [NSCharacterSet URLQueryAllowedCharacterSet];
    return [value stringByAddingPercentEncodingWithAllowedCharacters:allowed] ?: @"";
}

static NSArray<LyriCarLyricLine *> *LyriCarParseLRC(NSString *lrc) {
    if (lrc.length == 0) {
        return @[];
    }

    NSMutableArray<LyriCarLyricLine *> *lines = [NSMutableArray array];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\[(\\d{1,3}):(\\d{2})(?:[\\.:](\\d{1,3}))?\\](.*)"
                                                                               options:0
                                                                                 error:nil];

    [lrc enumerateLinesUsingBlock:^(NSString * _Nonnull rawLine, BOOL * _Nonnull stop) {
        (void)stop;
        NSTextCheckingResult *match = [regex firstMatchInString:rawLine options:0 range:NSMakeRange(0, rawLine.length)];
        if (match.numberOfRanges < 5) {
            return;
        }

        NSString *minutesText = [rawLine substringWithRange:[match rangeAtIndex:1]];
        NSString *secondsText = [rawLine substringWithRange:[match rangeAtIndex:2]];
        NSString *fractionText = [match rangeAtIndex:3].location != NSNotFound
            ? [rawLine substringWithRange:[match rangeAtIndex:3]]
            : @"";
        NSString *text = [[rawLine substringWithRange:[match rangeAtIndex:4]]
            stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];

        if (text.length == 0) {
            text = @" ";
        }

        double fraction = 0;
        if (fractionText.length == 1) {
            fraction = fractionText.doubleValue / 10.0;
        } else if (fractionText.length == 2) {
            fraction = fractionText.doubleValue / 100.0;
        } else if (fractionText.length >= 3) {
            fraction = fractionText.doubleValue / pow(10.0, MIN((NSInteger)fractionText.length, 3));
        }

        LyriCarLyricLine *line = [LyriCarLyricLine new];
        line.time = minutesText.doubleValue * 60.0 + secondsText.doubleValue + fraction;
        line.text = text;
        [lines addObject:line];
    }];

    [lines sortUsingComparator:^NSComparisonResult(LyriCarLyricLine *a, LyriCarLyricLine *b) {
        if (a.time < b.time) return NSOrderedAscending;
        if (a.time > b.time) return NSOrderedDescending;
        return NSOrderedSame;
    }];
    return lines;
}

static CPListItem *LyriCarRow(NSString *text, NSString *detail) {
    return [[CPListItem alloc] initWithText:text ?: @"" detailText:detail];
}

static void LyriCarSetLyricsRows(NSArray<CPListItem *> *rows) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (LyriCarLyricsTemplate == nil) {
            return;
        }
        CPListSection *section = [[CPListSection alloc] initWithItems:rows ?: @[]];
        [LyriCarLyricsTemplate updateSections:@[section]];
    });
}

static void LyriCarShowStatusRows(NSString *status, NSString *detail) {
    NSString *title = LyriCarNowPlayingString(MPMediaItemPropertyTitle, @"Brano corrente");
    NSString *artist = LyriCarNowPlayingString(MPMediaItemPropertyArtist, @"Spotify");
    LyriCarSetLyricsRows(@[
        LyriCarRow(title, artist),
        LyriCarRow(status ?: @"Lyrics", detail)
    ]);
}

static NSInteger LyriCarCurrentLineIndex(NSTimeInterval position) {
    if (LyriCarSyncedLines.count == 0) {
        return NSNotFound;
    }

    NSInteger result = NSNotFound;
    for (NSInteger i = 0; i < (NSInteger)LyriCarSyncedLines.count; i++) {
        if (LyriCarSyncedLines[i].time <= position + 0.05) {
            result = i;
        } else {
            break;
        }
    }
    return result;
}

static NSString *LyriCarSafeLineText(NSInteger index) {
    if (index < 0 || index >= (NSInteger)LyriCarSyncedLines.count) {
        return @" ";
    }
    NSString *text = LyriCarSyncedLines[index].text;
    return text.length > 0 ? text : @" ";
}

static void LyriCarRenderCurrentLyrics(BOOL force) {
    if (LyriCarLyricsTemplate == nil || LyriCarSyncedLines.count == 0) {
        return;
    }

    NSTimeInterval position = LyriCarPlaybackPosition();
    NSInteger index = LyriCarCurrentLineIndex(position);
    if (index == NSNotFound) {
        index = 0;
    }

    if (!force && LyriCarLastRenderedIndex == index) {
        return;
    }
    LyriCarLastRenderedIndex = index;

    // The Clio's 9.3-inch portrait display has enough vertical area to make a
    // larger lyric window useful. Keep up to four lines before and four after
    // the current line (nine lyric rows total) and shift the window at the
    // beginning/end of a song so available rows are never wasted on blanks.
    const NSInteger desiredRows = 9;
    const NSInteger preferredPrevious = 4;
    NSInteger lineCount = (NSInteger)LyriCarSyncedLines.count;

    NSInteger start = MAX(0, index - preferredPrevious);
    NSInteger end = MIN(lineCount - 1, start + desiredRows - 1);
    start = MAX(0, end - desiredRows + 1);

    NSMutableArray<CPListItem *> *rows = [NSMutableArray arrayWithCapacity:desiredRows];
    for (NSInteger rowIndex = start; rowIndex <= end; rowIndex++) {
        NSString *text = LyriCarSafeLineText(rowIndex);
        if (rowIndex == index) {
            [rows addObject:LyriCarRow([NSString stringWithFormat:@"▶︎ %@", text], nil)];
        } else {
            [rows addObject:LyriCarRow(text, nil)];
        }
    }

    LyriCarSetLyricsRows(rows);
}

static void LyriCarStopLyricsTimer(void) {
    [LyriCarLyricsTimer invalidate];
    LyriCarLyricsTimer = nil;
}

static void LyriCarStartLyricsTimer(void) {
    LyriCarStopLyricsTimer();
    LyriCarLyricsTimer = [NSTimer scheduledTimerWithTimeInterval:0.20
                                                         repeats:YES
                                                           block:^(__unused NSTimer *timer) {
        NSString *trackKey = LyriCarCurrentTrackKey();
        if (LyriCarLoadedTrackKey != nil && ![LyriCarLoadedTrackKey isEqualToString:trackKey]) {
            // Track changed while the Lyrics page is still open. Reload automatically.
            LyriCarLoadedTrackKey = nil;
            LyriCarSyncedLines = nil;
            LyriCarLastRenderedIndex = NSNotFound;
            LyriCarLyricsLoading = NO;
            LyriCarShowStatusRows(@"Cambio brano…", @"Ricerca del nuovo testo sincronizzato");
            return;
        }
        LyriCarRenderCurrentLyrics(NO);
    }];
}

static void LyriCarLoadLyricsForCurrentTrack(void) {
    NSString *title = LyriCarNowPlayingString(MPMediaItemPropertyTitle, @"");
    NSString *artist = LyriCarNowPlayingString(MPMediaItemPropertyArtist, @"");
    NSString *album = LyriCarNowPlayingString(MPMediaItemPropertyAlbumTitle, @"");
    NSTimeInterval duration = LyriCarNowPlayingNumber(MPMediaItemPropertyPlaybackDuration, 0);
    NSString *trackKey = LyriCarCurrentTrackKey();

    if (title.length == 0 || artist.length == 0) {
        LyriCarShowStatusRows(@"Brano non rilevato", @"Avvia una canzone in Spotify e riprova.");
        return;
    }

    if (LyriCarLyricsLoading) {
        return;
    }

    if ([LyriCarLoadedTrackKey isEqualToString:trackKey] && LyriCarSyncedLines.count > 0) {
        LyriCarRenderCurrentLyrics(YES);
        LyriCarStartLyricsTimer();
        return;
    }

    LyriCarLyricsLoading = YES;
    LyriCarShowStatusRows(@"Ricerca testo sincronizzato…", @"LRCLIB");

    NSMutableArray<NSString *> *queryParts = [NSMutableArray arrayWithArray:@[
        [NSString stringWithFormat:@"track_name=%@", LyriCarURLEncode(title)],
        [NSString stringWithFormat:@"artist_name=%@", LyriCarURLEncode(artist)]
    ]];
    if (album.length > 0) {
        [queryParts addObject:[NSString stringWithFormat:@"album_name=%@", LyriCarURLEncode(album)]];
    }
    if (duration > 0) {
        [queryParts addObject:[NSString stringWithFormat:@"duration=%ld", (long)llround(duration)]];
    }

    NSString *urlString = [NSString stringWithFormat:@"https://lrclib.net/api/get?%@", [queryParts componentsJoinedByString:@"&"]];
    NSURL *url = [NSURL URLWithString:urlString];
    if (url == nil) {
        LyriCarLyricsLoading = NO;
        LyriCarShowStatusRows(@"Errore Lyrics", @"Richiesta LRCLIB non valida");
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 12.0;
    [request setValue:@"LyriCarSpotify/0.2 (+https://github.com/Marlius92/LyriCar-0.2.0-alpha.7)" forHTTPHeaderField:@"User-Agent"];

    NSURLSessionDataTask *task = [NSURLSession.sharedSession dataTaskWithRequest:request
                                                              completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            LyriCarLyricsLoading = NO;

            NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
            if (error != nil || data.length == 0 || http.statusCode < 200 || http.statusCode >= 300) {
                NSString *detail = http.statusCode == 404
                    ? @"Nessun testo sincronizzato trovato su LRCLIB"
                    : @"Controlla la connessione dati e riprova";
                LyriCarShowStatusRows(@"Testo non disponibile", detail);
                return;
            }

            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSString *syncedLyrics = [json isKindOfClass:NSDictionary.class] && [json[@"syncedLyrics"] isKindOfClass:NSString.class]
                ? json[@"syncedLyrics"]
                : nil;
            NSArray<LyriCarLyricLine *> *parsed = LyriCarParseLRC(syncedLyrics);
            if (parsed.count == 0) {
                LyriCarShowStatusRows(@"Testo non sincronizzato", @"LRCLIB non ha timestamp utilizzabili per questo brano");
                return;
            }

            LyriCarLoadedTrackKey = trackKey;
            LyriCarSyncedLines = parsed;
            LyriCarLastRenderedIndex = NSNotFound;
            LyriCarRenderCurrentLyrics(YES);
            LyriCarStartLyricsTimer();
        });
    }];
    [task resume];
}

static CPListTemplate *LyriCarBuildLyricsTemplate(void) {
    NSString *title = LyriCarNowPlayingString(MPMediaItemPropertyTitle, @"Brano corrente");
    NSString *artist = LyriCarNowPlayingString(MPMediaItemPropertyArtist, @"Spotify");
    CPListSection *section = [[CPListSection alloc] initWithItems:@[
        LyriCarRow(title, artist),
        LyriCarRow(@"Ricerca testo sincronizzato…", @"LRCLIB")
    ]];
    return [[CPListTemplate alloc] initWithTitle:@"Lyrics" sections:@[section]];
}

static void LyriCarShowLyrics(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        CPInterfaceController *controller = LyriCarFindCarPlayInterfaceController();
        if (controller == nil) {
            return;
        }

        LyriCarInterfaceController = controller;
        LyriCarLyricsTemplate = LyriCarBuildLyricsTemplate();
        LyriCarLastRenderedIndex = NSNotFound;

        [controller pushTemplate:LyriCarLyricsTemplate animated:YES completion:^(BOOL animated, NSError * _Nullable error) {
            (void)animated;
            if (error == nil) {
                LyriCarLoadLyricsForCurrentTrack();
            }
        }];
    });
}

static CPNowPlayingImageButton *LyriCarMakeLyricsButton(void) {
    if (LyriCarLyricsButton != nil) {
        return LyriCarLyricsButton;
    }

    UIImage *image = [UIImage systemImageNamed:@"text.quote"];
    if (image == nil) {
        image = [UIImage systemImageNamed:@"doc.plaintext"];
    }
    if (image == nil) {
        image = [UIImage new];
    }

    LyriCarLyricsButton = [[CPNowPlayingImageButton alloc]
        initWithImage:image
        handler:^(__kindof CPNowPlayingButton *button) {
            (void)button;
            LyriCarShowLyrics();
        }];

    return LyriCarLyricsButton;
}

static BOOL LyriCarButtonsContainLyricsButton(NSArray<CPNowPlayingButton *> *buttons) {
    for (CPNowPlayingButton *button in buttons) {
        if (button == LyriCarLyricsButton) {
            return YES;
        }
    }
    return NO;
}

static void LyriCarEnsureLyricsButton(void) {
    CPInterfaceController *controller = LyriCarFindCarPlayInterfaceController();
    if (controller == nil) {
        LyriCarInterfaceController = nil;
        LyriCarLyricsTemplate = nil;
        LyriCarStopLyricsTimer();
        return;
    }

    LyriCarInterfaceController = controller;

    CPNowPlayingTemplate *nowPlaying = CPNowPlayingTemplate.sharedTemplate;
    CPNowPlayingImageButton *lyricsButton = LyriCarMakeLyricsButton();
    NSArray<CPNowPlayingButton *> *existing = nowPlaying.nowPlayingButtons ?: @[];

    if (LyriCarButtonsContainLyricsButton(existing)) {
        return;
    }

    NSMutableArray<CPNowPlayingButton *> *updated = [existing mutableCopy];

    // CarPlay permits up to five Now Playing buttons. Preserve Spotify's first
    // four controls and reserve the last slot for Lyrics if all slots are used.
    if (updated.count >= 5) {
        [updated removeObjectsInRange:NSMakeRange(4, updated.count - 4)];
    }
    [updated addObject:lyricsButton];

    [nowPlaying updateNowPlayingButtons:updated];
}

static void LyriCarStartCarPlayWatcher(void) {
    LyriCarEnsureLyricsButton();

    [LyriCarCarPlayWatcher invalidate];
    LyriCarCarPlayWatcher = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                            repeats:YES
                                                              block:^(__unused NSTimer *timer) {
        LyriCarEnsureLyricsButton();

        if (LyriCarLyricsTemplate != nil && LyriCarLyricsLoading == NO) {
            NSString *trackKey = LyriCarCurrentTrackKey();
            if (LyriCarLoadedTrackKey == nil || ![LyriCarLoadedTrackKey isEqualToString:trackKey]) {
                LyriCarLoadLyricsForCurrentTrack();
            }
        }
    }];
}

__attribute__((constructor))
static void LyriCarSpotifyInit(void) {
    @autoreleasepool {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Spotify needs a moment to finish creating its UIKit/CarPlay scenes.
            dispatch_after(
                dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                dispatch_get_main_queue(),
                ^{
                    LyriCarStartCarPlayWatcher();
                }
            );
        });
    }
}
