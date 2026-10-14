#import "RSAppDelegate.h"
#import "RSAPI.h"
#import "RSAppListViewController.h"
#import "RSChartsViewController.h"
#import "RSFeaturedViewController.h"
#import "RSFeeds.h"
#import "RSModel.h"
#import "RSSearchViewController.h"
#import "RSTabIcons.h"
#import "RSTheme.h"
#import "RSUpdatesViewController.h"
#import "RSUtil.h"

@implementation RSAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    [NSURLCache setSharedURLCache:[[NSURLCache alloc] initWithMemoryCapacity:4 * 1024 * 1024
                                                                diskCapacity:80 * 1024 * 1024 diskPath:@"RetroStore"]];
    [RSTheme apply];
    [RSGenres loadGenres];

    RSAppListViewController *genius = [[RSAppListViewController alloc] initWithTitle:@"Genius" loader:RSCompatibleAppsLoader()];
    genius.headerText = [NSString stringWithFormat:@"Apps die getest zijn op een %@ met iOS %@.",
                         RSDeviceModel(), RSSystemVersion()];
    genius.emptyText = @"Er zijn nog geen apps getest op deze iPhone.";

    UITabBarController *tabs = [UITabBarController new];
    tabs.viewControllers = @[
        [self navigationWithRoot:[RSFeaturedViewController new] title:@"Uitgelicht" icon:[RSTabIcons featured]],
        [self navigationWithRoot:[RSChartsViewController new] title:@"Toplijsten" icon:[RSTabIcons charts]],
        [self navigationWithRoot:genius title:@"Genius" icon:[RSTabIcons genius]],
        [self navigationWithRoot:[RSSearchViewController new] title:@"Zoek" icon:[RSTabIcons search]],
        [self navigationWithRoot:[RSUpdatesViewController new] title:@"Updates" icon:[RSTabIcons updates]],
    ];

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor blackColor];
    self.window.rootViewController = tabs;
    [self.window makeKeyAndVisible];
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    __block UIBackgroundTaskIdentifier task = [application beginBackgroundTaskWithExpirationHandler:^{
        [application endBackgroundTask:task];
        task = UIBackgroundTaskInvalid;
    }];
    [self finishBackgroundTask:task attempts:20];
}

- (void)finishBackgroundTask:(UIBackgroundTaskIdentifier)task attempts:(NSInteger)attempts {
    UIApplication *application = [UIApplication sharedApplication];
    if (application.applicationState != UIApplicationStateBackground) {
        [application endBackgroundTask:task];
        return;
    }
    if ([RSAPI activeRequestCount] == 0 || attempts <= 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [application endBackgroundTask:task];
        });
        return;
    }
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 2), dispatch_get_main_queue(), ^{
        [self finishBackgroundTask:task attempts:attempts - 1];
    });
}

- (UINavigationController *)navigationWithRoot:(UIViewController *)root title:(NSString *)title icon:(UIImage *)icon {
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:root];
    UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:title image:nil tag:0];
    [item setFinishedSelectedImage:[RSTheme tabImageWithMask:icon selected:YES]
       withFinishedUnselectedImage:[RSTheme tabImageWithMask:icon selected:NO]];
    item.badgeValue = root.tabBarItem.badgeValue;
    navigation.tabBarItem = item;
    return navigation;
}

@end
