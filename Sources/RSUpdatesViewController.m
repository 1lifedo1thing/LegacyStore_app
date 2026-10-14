#import "RSUpdatesViewController.h"
#import "RSAPI.h"
#import "RSAppCell.h"
#import "RSAppDetailViewController.h"
#import "RSInstaller.h"
#import "RSModel.h"
#import "RSTheme.h"
#import "RSUtil.h"

static UIImage *RSInstalledRowIcon(void) {
    return RSDrawImage(CGSizeMake(31, 31), NO, ^(CGContextRef ctx, CGRect rect) {
        UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(rect, 1, 1)];
        CGContextSaveGState(ctx);
        [circle addClip];
        RSFillGradient(ctx, rect, @[RSColor(0x6fb4f4), RSColor(0x1d64d0)]);
        CGContextRestoreGState(ctx);
        [RSColor(0x1a4f9e) setStroke];
        circle.lineWidth = 1;
        [circle stroke];
        UIBezierPath *arrow = [UIBezierPath bezierPath];
        [arrow moveToPoint:CGPointMake(13, 7)];
        [arrow addLineToPoint:CGPointMake(18, 7)];
        [arrow addLineToPoint:CGPointMake(18, 15)];
        [arrow addLineToPoint:CGPointMake(22, 15)];
        [arrow addLineToPoint:CGPointMake(15.5, 21)];
        [arrow addLineToPoint:CGPointMake(9, 15)];
        [arrow addLineToPoint:CGPointMake(13, 15)];
        [arrow closePath];
        [arrow appendPath:[UIBezierPath bezierPathWithRect:CGRectMake(9, 23, 13, 2)]];
        CGContextSetShadowWithColor(ctx, CGSizeMake(0, -1), 0, [RSColor(0x10408a) CGColor]);
        [[UIColor whiteColor] setFill];
        [arrow fill];
    });
}

static NSString *RSInstalledName(NSDictionary *info) {
    return RSString(info[@"CFBundleDisplayName"]) ?: RSString(info[@"CFBundleName"]) ?: RSString(info[@"CFBundleExecutable"]);
}

static const NSTimeInterval RSUpdateCheckInterval = 24 * 60 * 60;

static NSString *RSUpdateCachePath(void) {
    NSString *caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
    return [caches stringByAppendingPathComponent:@"RSUpdates.json"];
}

static NSDictionary *RSTrimmedApp(NSDictionary *app, RSInstallable *best) {
    NSMutableDictionary *trimmed = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"app_store_id", @"bundle_id", @"name", @"developer", @"genre_id", @"icon_url", @"web_url"])
        if (RSString(app[key])) trimmed[key] = RSString(app[key]);
    for (NSDictionary *version in app[@"versions"]) {
        if (![version isKindOfClass:[NSDictionary class]] || ![RSString(version[@"version"]) isEqualToString:best.version])
            continue;
        NSMutableDictionary *slim = [version mutableCopy];
        NSMutableArray *copies = [NSMutableArray array];
        for (NSDictionary *copy in version[@"copies"])
            if ([copy isKindOfClass:[NSDictionary class]] &&
                [RSString(copy[@"manifest_url"]) isEqualToString:best.manifestURL.absoluteString])
                [copies addObject:copy];
        slim[@"copies"] = copies;
        trimmed[@"versions"] = @[slim];
        break;
    }
    return trimmed;
}

@implementation RSUpdatesViewController {
    NSMutableDictionary *_cache;
    NSMutableArray *_queue;
    NSUInteger _queueTotal;
    NSUInteger _checkGeneration;
    BOOL _checking;
}

- (instancetype)init {
    if ((self = [super initWithTitle:@"Updates" loader:nil])) {
        self.emptyText = @"Al je apps zijn bijgewerkt.";
        NSData *data = [NSData dataWithContentsOfFile:RSUpdateCachePath()];
        id json = data ? [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:NULL] : nil;
        _cache = [json isKindOfClass:[NSMutableDictionary class]] ? json : [NSMutableDictionary dictionary];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(checkForUpdates)
                                                     name:RSInstalledAppsDidChangeNotification object:nil];
        [self rebuildList];
        __weak RSUpdatesViewController *weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [weakSelf checkForUpdates];
        });
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self updateStatus];
}

- (void)updateStatus {
    if (!self.isViewLoaded) return;
    if (_checking && !self.apps.count)
        [self showStatus:[NSString stringWithFormat:@"Zoeken naar updates… (%lu van %lu)",
            (unsigned long)(_queueTotal - _queue.count), (unsigned long)_queueTotal] loading:YES];
    else
        [self showStatus:self.apps.count ? nil : self.emptyText loading:NO];
    self.navigationItem.rightBarButtonItem = self.apps.count ?
        [[UIBarButtonItem alloc] initWithTitle:@"Werk alles bij" style:UIBarButtonItemStyleBordered
                                        target:self action:@selector(updateAll)] : nil;
}

- (void)setBadge {
    UITabBarItem *item = self.navigationController.tabBarItem ?: self.tabBarItem;
    item.badgeValue = self.apps.count ? [NSString stringWithFormat:@"%lu", (unsigned long)self.apps.count] : nil;
}

- (NSArray *)installedBundleIDs {
    NSString *ownID = [NSBundle mainBundle].bundleIdentifier;
    NSMutableArray *bundleIDs = [NSMutableArray array];
    for (NSString *bundleID in RSInstalledApps())
        if (![bundleID isEqualToString:ownID]) [bundleIDs addObject:bundleID];
    return bundleIDs;
}

- (void)checkForUpdates {
    NSTimeInterval now = [NSDate date].timeIntervalSince1970;
    _queue = [NSMutableArray array];
    for (NSString *bundleID in [self installedBundleIDs]) {
        NSDictionary *entry = _cache[bundleID];
        BOOL fresh = [entry isKindOfClass:[NSDictionary class]] &&
            [RSString(entry[@"installed"]) isEqualToString:RSInstalledVersion(bundleID) ?: @""] &&
            now - [entry[@"checked"] doubleValue] < RSUpdateCheckInterval;
        if (!fresh) [_queue addObject:bundleID];
    }
    _queueTotal = _queue.count;
    _checking = _queue.count > 0;
    [self rebuildList];
    [self checkNext:++_checkGeneration];
}

- (void)checkNext:(NSUInteger)generation {
    if (generation != _checkGeneration) return;
    if (!_queue.count) {
        _checking = NO;
        [self saveCache];
        [self rebuildList];
        return;
    }
    __weak RSUpdatesViewController *weakSelf = self;
    if ([RSAPI activeRequestCount] > 0 || [UIApplication sharedApplication].applicationState != UIApplicationStateActive) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [weakSelf checkNext:generation];
        });
        return;
    }
    NSString *bundleID = _queue.firstObject;
    [_queue removeObjectAtIndex:0];
    NSString *path = [@"/api/v1/apps/" stringByAppendingString:RSEscape(bundleID)];
    [RSAPI getPath:path query:nil completion:^(NSDictionary *app, NSError *error) {
        RSUpdatesViewController *controller = weakSelf;
        if (!controller) return;
        NSString *installed = RSInstalledVersion(bundleID) ?: @"";
        BOOL known = [app isKindOfClass:[NSDictionary class]];
        if (known || error.code == 404) {
            RSInstallable *best = known ? [RSInstallable installablesForApp:app].firstObject : nil;
            BOOL newer = best && !RSVersionLessOrEqual(best.version, installed);
            controller->_cache[bundleID] = @{@"installed": installed, @"checked": @([NSDate date].timeIntervalSince1970),
                                             @"app": newer ? RSTrimmedApp(app, best) : [NSNull null]};
            if (newer) [controller rebuildList];
        }
        if (controller->_queue.count % 10 == 0) [controller saveCache];
        [controller updateStatus];
        [controller checkNext:generation];
    }];
}

- (void)saveCache {
    NSData *data = [NSJSONSerialization dataWithJSONObject:_cache options:0 error:NULL];
    [data writeToFile:RSUpdateCachePath() atomically:YES];
}

- (NSDictionary *)updatableApps {
    NSMutableDictionary *apps = [NSMutableDictionary dictionary];
    for (NSString *bundleID in [self installedBundleIDs]) {
        NSDictionary *app = _cache[bundleID][@"app"];
        if (![app isKindOfClass:[NSDictionary class]]) continue;
        RSInstallable *best = [RSInstallable installablesForApp:app].firstObject;
        NSString *installed = RSInstalledVersion(bundleID);
        if (best && installed && !RSVersionLessOrEqual(best.version, installed)) apps[bundleID] = app;
    }
    return apps;
}

- (void)rebuildList {
    NSMutableArray *apps = [NSMutableArray array];
    NSDictionary *updatable = [self updatableApps];
    for (NSString *bundleID in updatable) {
        NSDictionary *app = updatable[bundleID];
        RSAppSummary *summary = [RSAppSummary summaryWithApp:app];
        if (!summary) continue;
        summary.updateVersion = ((RSInstallable *)[RSInstallable installablesForApp:app].firstObject).version;
        summary.subtitle = [NSString stringWithFormat:@"Versie %@ → %@", RSInstalledVersion(bundleID), summary.updateVersion];
        summary.localIcon = RSInstalledAppIcon(bundleID);
        [apps addObject:summary];
    }
    [apps sortUsingComparator:^NSComparisonResult(RSAppSummary *a, RSAppSummary *b) {
        return [a.name localizedCaseInsensitiveCompare:b.name];
    }];
    self.apps = apps;
    [self setBadge];
    [self updateStatus];
}

- (void)updateAll {
    NSTimeInterval delay = 0;
    for (NSDictionary *app in [self updatableApps].allValues) {
        if ([RSInstaller isInstalling:RSString(app[@"app_store_id"])]) continue;
        RSInstallable *best = [RSInstallable installablesForApp:app].firstObject;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [RSInstaller install:best ofApp:app];
        });
        delay += 2;
    }
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return section == 0 ? 1 : self.apps.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 0 ? 52 : [RSAppCell height];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        RSAppCell *cell = [tableView dequeueReusableCellWithIdentifier:@"app"];
        if (!cell) cell = [[RSAppCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"app"];
        [cell configureWithSummary:self.apps[indexPath.row] showRank:NO dark:indexPath.row % 2 == 0];
        return cell;
    }
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"installed"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"installed"];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
        cell.textLabel.textColor = [RSTheme textColor];
        cell.textLabel.shadowColor = [UIColor whiteColor];
        cell.textLabel.shadowOffset = CGSizeMake(0, 1);
        cell.textLabel.backgroundColor = [UIColor clearColor];
        cell.textLabel.text = @"Geïnstalleerd";
        cell.imageView.image = RSInstalledRowIcon();
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.backgroundView = [RSTheme rowBackgroundDark:NO selected:NO];
        cell.selectedBackgroundView = [RSTheme rowBackgroundDark:NO selected:YES];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1) {
        RSAppDetailViewController *detail = [[RSAppDetailViewController alloc] initWithSummary:self.apps[indexPath.row]];
        [self.navigationController pushViewController:detail animated:YES];
        return;
    }
    [self.navigationController pushViewController:[self installedListController] animated:YES];
}

- (RSAppListViewController *)installedListController {
    NSDictionary *installed = RSInstalledApps();
    NSString *ownID = [NSBundle mainBundle].bundleIdentifier;
    NSMutableArray *apps = [NSMutableArray array];
    for (NSString *bundleID in installed) {
        if ([bundleID isEqualToString:ownID]) continue;
        NSDictionary *info = installed[bundleID];
        NSDictionary *known = _cache[bundleID][@"app"];
        RSAppSummary *summary = [known isKindOfClass:[NSDictionary class]] ? [RSAppSummary summaryWithApp:known] : [RSAppSummary new];
        summary.appStoreID = summary.appStoreID ?: bundleID;
        summary.bundleID = bundleID;
        summary.name = RSInstalledName(info) ?: bundleID;
        summary.iconURL = nil;
        summary.localIcon = RSInstalledAppIcon(bundleID);
        NSString *version = RSInstalledVersion(bundleID);
        summary.subtitle = version ? [@"Versie " stringByAppendingString:version] : nil;
        [apps addObject:summary];
    }
    [apps sortUsingComparator:^NSComparisonResult(RSAppSummary *a, RSAppSummary *b) {
        return [a.name localizedCaseInsensitiveCompare:b.name];
    }];
    RSAppListViewController *list = [[RSAppListViewController alloc] initWithTitle:@"Geïnstalleerd" loader:nil];
    list.emptyText = @"Er zijn geen apps geïnstalleerd.";
    list.apps = apps;
    return list;
}

@end
