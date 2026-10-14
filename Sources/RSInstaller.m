#import "RSInstaller.h"
#import "RSAPI.h"
#import "RSModel.h"
#import "RSUtil.h"

NSString *const RSInstallerDidChangeNotification = @"RSInstallerDidChange";

static NSMutableDictionary *RSPending;
static NSTimer *RSPollTimer;
static NSDate *RSPollUntil;

@implementation RSInstaller

+ (RSPriceState)stateForSummary:(RSAppSummary *)summary {
    if ([self isInstalling:summary.appStoreID]) return RSPriceStateInstalling;
    NSString *installed = RSInstalledVersion(summary.bundleID);
    if (installed && summary.updateVersion && !RSVersionLessOrEqual(summary.updateVersion, installed))
        return RSPriceStateUpdate;
    if (summary.bundleID && RSInstalledApps()[summary.bundleID]) return RSPriceStateOpen;
    return RSPriceStatePrice;
}

+ (BOOL)isInstalling:(NSString *)appStoreID {
    return appStoreID && RSPending[appStoreID];
}

+ (void)alert:(NSString *)title message:(NSString *)message {
    [[[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK"
        otherButtonTitles:nil] show];
}

+ (void)handleTapOnButton:(RSPriceButton *)button summary:(RSAppSummary *)summary {
    switch (button.priceState) {
        case RSPriceStateOpen:
            [self open:summary.bundleID];
            return;
        case RSPriceStatePrice:
        case RSPriceStateUpdate:
        case RSPriceStateInstall:
            [button setPriceState:RSPriceStateConfirm animated:YES];
            return;
        case RSPriceStateInstalling:
            return;
        case RSPriceStateConfirm:
            break;
    }
    [button setPriceState:RSPriceStateInstalling animated:YES];
    __weak RSPriceButton *weakButton = button;
    NSString *path = [@"/api/v1/apps/" stringByAppendingString:RSEscape(summary.appStoreID)];
    [RSAPI getPath:path query:nil completion:^(NSDictionary *app, NSError *error) {
        RSInstallable *best = [app isKindOfClass:[NSDictionary class]] ? [RSInstallable installablesForApp:app].firstObject : nil;
        if (best && [self install:best ofApp:app]) return;
        [weakButton setPriceState:RSPriceStatePrice animated:YES];
        if (error)
            [self alert:@"Kan app niet laden" message:error.localizedDescription];
        else if (!best)
            [self alert:summary.name message:[NSString stringWithFormat:
                @"Het archief heeft geen versie van deze app die werkt op iOS %@.", RSSystemVersion()]];
    }];
}

+ (BOOL)install:(RSInstallable *)installable ofApp:(NSDictionary *)app {
    NSLog(@"[RetroStore] installeren: %@", installable.installURL);
    if (![[UIApplication sharedApplication] openURL:installable.installURL]) {
        [self alert:@"Installeren mislukt" message:@"iOS kon de installatielink niet openen."];
        return NO;
    }
    NSString *appStoreID = RSString(app[@"app_store_id"]);
    if (appStoreID) {
        if (!RSPending) RSPending = [NSMutableDictionary dictionary];
        RSPending[appStoreID] = @[RSString(app[@"bundle_id"]) ?: @"", installable.version ?: @""];
        [self startPolling];
        [[NSNotificationCenter defaultCenter] postNotificationName:RSInstallerDidChangeNotification object:nil];
    }
    return YES;
}

+ (void)startPolling {
    RSPollUntil = [NSDate dateWithTimeIntervalSinceNow:240];
    if (RSPollTimer) return;
    RSPollTimer = [NSTimer scheduledTimerWithTimeInterval:3 target:self selector:@selector(poll) userInfo:nil repeats:YES];
}

+ (void)poll {
    RSInvalidateInstalledApps();
    BOOL timedOut = [RSPollUntil timeIntervalSinceNow] < 0;
    NSUInteger before = RSPending.count;
    for (NSString *appStoreID in RSPending.allKeys) {
        NSArray *pending = RSPending[appStoreID];
        NSString *installed = RSInstalledVersion(pending[0]);
        if (timedOut || (installed && (![pending[1] length] || [installed isEqualToString:pending[1]])))
            [RSPending removeObjectForKey:appStoreID];
    }
    if (RSPending.count == 0) {
        [RSPollTimer invalidate];
        RSPollTimer = nil;
    }
    if (RSPending.count != before)
        [[NSNotificationCenter defaultCenter] postNotificationName:RSInstallerDidChangeNotification object:nil];
}

+ (void)open:(NSString *)bundleID {
    if (!RSLaunchApp(bundleID)) [self alert:@"Kan app niet openen" message:@"Open de app via het beginscherm."];
}

@end
