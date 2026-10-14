#import "RSFeeds.h"
#import "RSAPI.h"
#import "RSModel.h"
#import "RSUtil.h"

RSAppListLoader RSCompatibleAppsLoader(void) {
    return ^(RSAppListViewController *controller, RSAppListDone done) {
        NSDictionary *query = @{@"device": RSDeviceModel(), @"os": RSSystemVersion()};
        [RSAPI getPath:@"/api/emulator/apps" query:query completion:^(NSDictionary *json, NSError *error) {
            NSMutableArray *apps = [NSMutableArray array];
            for (NSDictionary *app in json[@"apps"]) {
                RSAppSummary *summary = [RSAppSummary summaryWithApp:app];
                if (summary) [apps addObject:summary];
            }
            done(apps, error);
        }];
    };
}

RSAppListLoader RSCollectionLoader(NSString *slug) {
    return ^(RSAppListViewController *controller, RSAppListDone done) {
        NSString *path = [@"/api/v1/collections/" stringByAppendingString:RSEscape(slug)];
        [RSAPI getPath:path query:nil completion:^(NSDictionary *json, NSError *error) {
            NSMutableArray *apps = [NSMutableArray array];
            for (NSDictionary *member in json[@"members"]) {
                if (![member isKindOfClass:[NSDictionary class]]) continue;
                RSAppSummary *summary = [RSAppSummary summaryWithApp:member[@"app"]];
                if (summary) [apps addObject:summary];
            }
            done(apps, error);
        }];
    };
}

RSAppListLoader RSGenreLoader(NSString *genreID) {
    return ^(RSAppListViewController *controller, RSAppListDone done) {
        NSDictionary *query = @{@"genre": genreID, @"sort": @"versions", @"limit": @100};
        [RSAPI getPath:@"/api/v1/apps" query:query completion:^(NSDictionary *json, NSError *error) {
            NSMutableArray *apps = [NSMutableArray array];
            for (NSDictionary *app in json[@"data"]) {
                RSAppSummary *summary = [RSAppSummary summaryWithApp:app];
                if (summary) [apps addObject:summary];
            }
            done(apps, error);
        }];
    };
}

RSAppListLoader RSChartLoader(NSString *type, NSString *date, NSUInteger limit) {
    return ^(RSAppListViewController *controller, RSAppListDone done) {
        NSDictionary *query = @{@"type": type, @"date": date, @"device": @"iphone"};
        [RSAPI getPath:@"/api/v1/charts" query:query completion:^(NSDictionary *json, NSError *error) {
            NSMutableArray *apps = [NSMutableArray array];
            for (NSDictionary *position in json[@"positions"]) {
                RSAppSummary *summary = [RSAppSummary summaryWithChartPosition:position];
                if (summary && apps.count < limit) [apps addObject:summary];
            }
            done(apps, error);
        }];
    };
}
