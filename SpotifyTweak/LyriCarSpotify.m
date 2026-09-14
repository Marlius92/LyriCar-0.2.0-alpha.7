#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CarPlay/CarPlay.h>
#import <MediaPlayer/MediaPlayer.h>

static CPInterfaceController *LyriCarInterfaceController = nil;
static CPNowPlayingImageButton *LyriCarLyricsButton = nil;
static CPListTemplate *LyriCarLyricsTemplate = nil;

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

static NSString *LyriCarNowPlayingValue(NSString *key, NSString *fallback) {
    id value = MPNowPlayingInfoCenter.defaultCenter.nowPlayingInfo[key];
    if ([value isKindOfClass:NSString.class] && [(NSString *)value length] > 0) {
        return (NSString *)value;
    }
    return fallback;
}

static CPListTemplate *LyriCarBuildProofTemplate(void) {
    NSString *title = LyriCarNowPlayingValue(MPMediaItemPropertyTitle, @"Brano corrente");
    NSString *artist = LyriCarNowPlayingValue(MPMediaItemPropertyArtist, @"Spotify");

    CPListItem *track = [[CPListItem alloc] initWithText:title detailText:artist];
    CPListItem *previous = [[CPListItem alloc] initWithText:@"Riga precedente" detailText:nil];
    CPListItem *current = [[CPListItem alloc] initWithText:@"▶︎ RIGA CORRENTE" detailText:@"LyriCar Spotify · test CarPlay"];
    CPListItem *next = [[CPListItem alloc] initWithText:@"Riga successiva" detailText:nil];
    CPListItem *future = [[CPListItem alloc] initWithText:@"Riga futura" detailText:@"Se vedi questa pagina, il tweak è attivo."];

    CPListSection *section = [[CPListSection alloc] initWithItems:@[
        track,
        previous,
        current,
        next,
        future
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
        LyriCarLyricsTemplate = LyriCarBuildProofTemplate();
        [controller pushTemplate:LyriCarLyricsTemplate animated:YES completion:nil];
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

    // CarPlay supports at most five Now Playing buttons. For the proof build,
    // preserve Spotify's first four controls and reserve the fifth slot for
    // Lyrics when Spotify already fills every slot.
    if (updated.count >= 5) {
        [updated removeObjectsInRange:NSMakeRange(4, updated.count - 4)];
    }
    [updated addObject:lyricsButton];

    [nowPlaying updateNowPlayingButtons:updated];
}

static void LyriCarStartCarPlayWatcher(void) {
    LyriCarEnsureLyricsButton();

    [NSTimer scheduledTimerWithTimeInterval:1.0
                                     repeats:YES
                                       block:^(__unused NSTimer *timer) {
        LyriCarEnsureLyricsButton();
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
