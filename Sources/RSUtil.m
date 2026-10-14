#import "RSUtil.h"
#include <sys/sysctl.h>
#include <mach/machine.h>
#include <dlfcn.h>
#import <objc/message.h>

NSString *RSString(id value) {
    if ([value isKindOfClass:[NSString class]]) return [value length] ? value : nil;
    if ([value isKindOfClass:[NSNumber class]]) return [value stringValue];
    return nil;
}

NSString *RSEscape(NSString *string) {
    return CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(NULL, (__bridge CFStringRef)string, NULL,
        CFSTR("!*'();:@&=+$,/?%#[]"), kCFStringEncodingUTF8));
}

NSString *RSFormatBytes(long long bytes) {
    if (bytes <= 0) return nil;
    double mb = bytes / (1024.0 * 1024.0);
    if (mb < 1) return [NSString stringWithFormat:@"%.0f kB", bytes / 1024.0];
    return [[NSString stringWithFormat:@"%.1f MB", mb] stringByReplacingOccurrencesOfString:@"." withString:@","];
}

NSString *RSFormatDate(NSString *iso) {
    if (iso.length < 10) return nil;
    static NSDateFormatter *in, *out;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        in = [NSDateFormatter new];
        in.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US_POSIX"];
        in.timeZone = [NSTimeZone timeZoneWithName:@"UTC"];
        in.dateFormat = @"yyyy-MM-dd";
        out = [NSDateFormatter new];
        out.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"nl_NL"];
        out.timeZone = in.timeZone;
        out.dateStyle = NSDateFormatterMediumStyle;
    });
    NSDate *date = [in dateFromString:[iso substringToIndex:10]];
    return date ? [out stringFromDate:date] : nil;
}

UIColor *RSColor(unsigned rgb) {
    return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0 green:((rgb >> 8) & 0xff) / 255.0 blue:(rgb & 0xff) / 255.0 alpha:1];
}

NSString *RSDeviceModel(void) {
    char buf[64] = {0};
    size_t len = sizeof(buf) - 1;
    if (sysctlbyname("hw.machine", buf, &len, NULL, 0) != 0) return @"iPhone3,1";
    return [NSString stringWithUTF8String:buf];
}

NSString *RSSystemVersion(void) {
    return [UIDevice currentDevice].systemVersion;
}

NSArray *RSDeviceArchitectures(void) {
    cpu_subtype_t subtype = 0;
    size_t len = sizeof(subtype);
    sysctlbyname("hw.cpusubtype", &subtype, &len, NULL, 0);
    if (subtype == CPU_SUBTYPE_ARM_V7S) return @[@"armv6", @"armv7", @"armv7s"];
    return @[@"armv6", @"armv7"];
}

BOOL RSVersionLessOrEqual(NSString *a, NSString *b) {
    return [a compare:b options:NSNumericSearch] != NSOrderedDescending;
}

NSString *const RSInstalledAppsDidChangeNotification = @"RSInstalledAppsDidChange";
static NSDictionary *RSInstalledAppsCache;

NSDictionary *RSInstalledApps(void) {
    if (!RSInstalledAppsCache) {
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil
                queue:nil usingBlock:^(NSNotification *note) { RSInvalidateInstalledApps(); }];
        });
        NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:
            @"/var/mobile/Library/Caches/com.apple.mobile.installation.plist"];
        NSDictionary *user = plist[@"User"];
        RSInstalledAppsCache = [user isKindOfClass:[NSDictionary class]] ? user : @{};
    }
    return RSInstalledAppsCache;
}

void RSInvalidateInstalledApps(void) {
    NSDictionary *old = RSInstalledAppsCache;
    RSInstalledAppsCache = nil;
    if (old && ![old isEqualToDictionary:RSInstalledApps()])
        [[NSNotificationCenter defaultCenter] postNotificationName:RSInstalledAppsDidChangeNotification object:nil];
}

NSSet *RSInstalledBundleIDs(void) {
    return [NSSet setWithArray:RSInstalledApps().allKeys];
}

NSString *RSInstalledVersion(NSString *bundleID) {
    NSDictionary *info = bundleID ? RSInstalledApps()[bundleID] : nil;
    return RSString(info[@"CFBundleShortVersionString"]) ?: RSString(info[@"CFBundleVersion"]);
}

UIImage *RSInstalledAppIcon(NSString *bundleID) {
    NSDictionary *info = bundleID ? RSInstalledApps()[bundleID] : nil;
    NSString *bundlePath = RSString(info[@"Path"]);
    if (!bundlePath) return nil;
    NSMutableArray *names = [NSMutableArray array];
    id files = info[@"CFBundleIconFiles"];
    if ([files isKindOfClass:[NSArray class]]) [names addObjectsFromArray:files];
    files = info[@"CFBundleIcons"][@"CFBundlePrimaryIcon"][@"CFBundleIconFiles"];
    if ([files isKindOfClass:[NSArray class]]) [names addObjectsFromArray:files];
    if (RSString(info[@"CFBundleIconFile"])) [names addObject:info[@"CFBundleIconFile"]];
    [names addObjectsFromArray:@[@"Icon.png", @"Icon@2x.png", @"icon.png", @"icon@2x.png"]];

    UIImage *best = nil;
    for (NSString *name in names) {
        if (![name isKindOfClass:[NSString class]]) continue;
        NSString *base = name.pathExtension.length ? name.stringByDeletingPathExtension : name;
        for (NSString *suffix in @[@"@2x.png", @".png"]) {
            UIImage *image = [UIImage imageWithContentsOfFile:
                [bundlePath stringByAppendingPathComponent:[base stringByAppendingString:suffix]]];
            if (image.size.width * image.scale > best.size.width * best.scale) best = image;
        }
    }
    return best;
}

BOOL RSLaunchApp(NSString *bundleID) {
    if (!bundleID) return NO;
    static int (*launch)(CFStringRef, Boolean);
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *sbs = dlopen("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", RTLD_LAZY);
        if (sbs) launch = (int (*)(CFStringRef, Boolean))dlsym(sbs, "SBSLaunchApplicationWithIdentifier");
    });
    if (launch && launch((__bridge CFStringRef)bundleID, false) == 0) return YES;
    UIApplication *app = [UIApplication sharedApplication];
    SEL fallback = NSSelectorFromString(@"launchApplicationWithIdentifier:suspended:");
    if ([app respondsToSelector:fallback]) {
        ((BOOL (*)(id, SEL, NSString *, BOOL))objc_msgSend)(app, fallback, bundleID, NO);
        return YES;
    }
    return NO;
}
