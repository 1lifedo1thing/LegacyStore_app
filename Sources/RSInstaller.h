#import <Foundation/Foundation.h>
#import "RSPriceButton.h"

@class RSAppSummary, RSInstallable;

extern NSString *const RSInstallerDidChangeNotification;

@interface RSInstaller : NSObject
+ (RSPriceState)stateForSummary:(RSAppSummary *)summary;
+ (BOOL)isInstalling:(NSString *)appStoreID;
+ (void)handleTapOnButton:(RSPriceButton *)button summary:(RSAppSummary *)summary;
+ (BOOL)install:(RSInstallable *)installable ofApp:(NSDictionary *)app;
+ (void)open:(NSString *)bundleID;
@end
