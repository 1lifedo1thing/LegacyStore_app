#import <UIKit/UIKit.h>

NSString *RSString(id value);
NSString *RSEscape(NSString *string);
NSString *RSFormatBytes(long long bytes);
NSString *RSFormatDate(NSString *iso);
UIColor *RSColor(unsigned rgb);

NSString *RSDeviceModel(void);
NSString *RSSystemVersion(void);
NSArray *RSDeviceArchitectures(void);
BOOL RSVersionLessOrEqual(NSString *a, NSString *b);

NSDictionary *RSInstalledApps(void);
NSSet *RSInstalledBundleIDs(void);
NSString *RSInstalledVersion(NSString *bundleID);
UIImage *RSInstalledAppIcon(NSString *bundleID);
void RSInvalidateInstalledApps(void);
extern NSString *const RSInstalledAppsDidChangeNotification;
BOOL RSLaunchApp(NSString *bundleID);
