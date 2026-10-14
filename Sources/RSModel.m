#import "RSModel.h"
#import "RSAPI.h"
#import "RSUtil.h"

@implementation RSAppSummary

+ (instancetype)summaryWithApp:(NSDictionary *)app {
    if (![app isKindOfClass:[NSDictionary class]]) return nil;
    RSAppSummary *s = [self new];
    s.appStoreID = RSString(app[@"app_store_id"]);
    if (!s.appStoreID) s.appStoreID = [RSString(app[@"app_url"]) lastPathComponent];
    s.bundleID = RSString(app[@"bundle_id"]);
    s.name = RSString(app[@"name"]) ?: @"Naamloos";
    s.developer = RSString(app[@"developer"]);
    s.genreID = RSString(app[@"genre_id"]);
    NSString *icon = RSString(app[@"icon_url"]);
    if (icon) s.iconURL = [NSURL URLWithString:icon];
    return s.appStoreID ? s : nil;
}

+ (instancetype)summaryWithChartPosition:(NSDictionary *)position {
    if (![position isKindOfClass:[NSDictionary class]]) return nil;
    NSMutableDictionary *app = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"app_store_id", @"name", @"developer"]) if (position[key]) app[key] = position[key];
    if ([position[@"app"] isKindOfClass:[NSDictionary class]])
        for (NSString *key in position[@"app"]) if (RSString(position[@"app"][key])) app[key] = position[@"app"][key];
    RSAppSummary *s = [self summaryWithApp:app];
    s.rank = [position[@"position"] integerValue];
    s.priceText = RSPriceText(position[@"price_amount"], RSString(position[@"price_currency"]));
    return s;
}

- (NSString *)category {
    return self.subtitle ?: [RSGenres nameForID:self.genreID] ?: self.developer;
}

@end

@implementation RSInstallable

static NSString *RSMaxVersion(NSString *a, NSString *b) {
    if (!a) return b;
    if (!b) return a;
    return RSVersionLessOrEqual(a, b) ? b : a;
}

+ (NSArray *)installablesForApp:(NSDictionary *)app {
    NSString *system = RSSystemVersion();
    NSSet *archs = [NSSet setWithArray:RSDeviceArchitectures()];
    NSMutableArray *result = [NSMutableArray array];

    for (NSDictionary *version in app[@"versions"]) {
        if (![version isKindOfClass:[NSDictionary class]]) continue;
        NSArray *family = version[@"device_family"];
        if ([family isKindOfClass:[NSArray class]] && family.count && ![[family valueForKey:@"integerValue"] containsObject:@1])
            continue;

        RSInstallable *best = nil;
        BOOL bestHasArmv7 = NO;
        for (NSDictionary *copy in version[@"copies"]) {
            if (![copy isKindOfClass:[NSDictionary class]]) continue;
            if (![RSString(copy[@"install_status"]) isEqualToString:@"installable"]) continue;
            NSString *manifest = RSString(copy[@"manifest_url"]);
            NSArray *copyArchs = copy[@"architectures"];
            if (!manifest || ![copyArchs isKindOfClass:[NSArray class]]) continue;
            if (![archs intersectsSet:[NSSet setWithArray:copyArchs]]) continue;
            NSString *minOS = RSMaxVersion(RSString(version[@"minimum_os_version"]), RSString(copy[@"macho_min_os"]));
            if (minOS && !RSVersionLessOrEqual(minOS, system)) continue;

            BOOL hasArmv7 = [copyArchs containsObject:@"armv7"];
            if (best && (bestHasArmv7 || !hasArmv7)) continue;
            best = [RSInstallable new];
            best.version = RSString(version[@"version"]) ?: @"?";
            best.minimumOS = minOS;
            best.releaseDate = RSString(version[@"release_date"]) ?: RSString(version[@"estimated_release_date"]);
            best.manifestURL = [NSURL URLWithString:manifest];
            best.size = [copy[@"size"] respondsToSelector:@selector(longLongValue)] ? [copy[@"size"] longLongValue] : 0;
            bestHasArmv7 = hasArmv7;
        }
        if (best) [result addObject:best];
    }
    return result;
}

- (NSURL *)installURL {
    return [NSURL URLWithString:[@"itms-services://?action=download-manifest&url="
        stringByAppendingString:RSEscape(self.manifestURL.absoluteString)]];
}

@end

NSString *RSPriceText(id amount, NSString *currency) {
    double price = [amount respondsToSelector:@selector(doubleValue)] ? [amount doubleValue] : 0;
    if (price <= 0) return nil;
    NSString *symbol = [@{@"USD": @"$", @"EUR": @"€", @"GBP": @"£"} objectForKey:currency ?: @"USD"];
    return symbol ? [NSString stringWithFormat:@"%@%.2f", symbol, price]
                  : [NSString stringWithFormat:@"%.0f %@", price, currency];
}

@implementation RSRating

+ (instancetype)ratingFromJSON:(id)json {
    NSArray *data = [json isKindOfClass:[NSDictionary class]] ? json[@"data"] : nil;
    if (![data isKindOfClass:[NSArray class]]) return nil;
    NSDictionary *best = nil, *bestAny = nil;
    for (NSDictionary *entry in data) {
        if (![entry isKindOfClass:[NSDictionary class]] || ![entry[@"rating_avg"] isKindOfClass:[NSNumber class]]) continue;
        bestAny = entry;
        NSString *currency = RSString(entry[@"price_currency"]);
        if (!currency || [currency isEqualToString:@"USD"]) best = entry;
    }
    best = best ?: bestAny ?: [data.lastObject isKindOfClass:[NSDictionary class]] ? data.lastObject : nil;
    if (!best) return nil;
    RSRating *rating = [self new];
    rating.average = [best[@"rating_avg"] isKindOfClass:[NSNumber class]] ? [best[@"rating_avg"] doubleValue] : 0;
    rating.count = [best[@"rating_count"] respondsToSelector:@selector(integerValue)] ? [best[@"rating_count"] integerValue] : 0;
    rating.priceText = RSPriceText(best[@"price_amount"], RSString(best[@"price_currency"]));
    return rating;
}

@end

NSDictionary *RSPreferredScreenshotSet(id json, NSString *version) {
    NSArray *sets = [json isKindOfClass:[NSDictionary class]] ? json[@"data"] : nil;
    if (![sets isKindOfClass:[NSArray class]] || !sets.count) return nil;
    NSDictionary *iOS6Era = nil;
    for (NSDictionary *set in sets) {
        if (![set isKindOfClass:[NSDictionary class]] || ![set[@"shots"] isKindOfClass:[NSArray class]] || ![set[@"shots"] count])
            continue;
        if (version && [RSString(set[@"version"]) isEqualToString:version]) return set;
        NSString *captured = RSString(set[@"captured_at"]);
        if (!iOS6Era || (captured && [captured compare:@"2013-09-18"] == NSOrderedAscending)) iOS6Era = set;
    }
    return iOS6Era;
}

NSString *const RSGenresDidLoadNotification = @"RSGenresDidLoad";
static NSArray *RSGenreList;
static NSDictionary *RSGenreNames;

@implementation RSGenres

+ (void)loadGenres {
    if (RSGenreList) return;
    [RSAPI getPath:@"/api/v1/genres" query:nil completion:^(NSDictionary *json, NSError *error) {
        NSArray *data = [json isKindOfClass:[NSDictionary class]] ? json[@"data"] : nil;
        if (![data isKindOfClass:[NSArray class]]) return;
        NSMutableArray *list = [NSMutableArray array];
        NSMutableDictionary *names = [NSMutableDictionary dictionary];
        for (NSDictionary *genre in data) {
            NSString *genreID = RSString(genre[@"genre_id"]), *name = RSString(genre[@"name"]);
            if (!genreID || !name) continue;
            name = [self dutchName:name genreID:genreID];
            names[genreID] = name;
            [list addObject:@{@"genre_id": genreID, @"name": name, @"app_count": genre[@"app_count"] ?: @0}];
        }
        [list sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            return [a[@"name"] localizedCaseInsensitiveCompare:b[@"name"]];
        }];
        RSGenreList = list;
        RSGenreNames = names;
        [[NSNotificationCenter defaultCenter] postNotificationName:RSGenresDidLoadNotification object:nil];
    }];
}

+ (NSArray *)all {
    return RSGenreList ?: @[];
}

+ (NSString *)nameForID:(NSString *)genreID {
    return genreID ? RSGenreNames[genreID] : nil;
}

+ (NSString *)dutchName:(NSString *)name genreID:(NSString *)genreID {
    static NSDictionary *dutch;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        dutch = @{
            @"Action": @"Actie", @"Adventure": @"Avontuur", @"Board": @"Bordspellen", @"Books": @"Boeken",
            @"Business": @"Zakelijk", @"Card": @"Kaartspellen", @"Catalogs": @"Catalogi",
            @"Developer Tools": @"Ontwikkelaarstools", @"Dice": @"Dobbelspellen", @"Education": @"Onderwijs",
            @"Educational": @"Educatief", @"Entertainment": @"Amusement", @"Family": @"Familie",
            @"Finance": @"Financiën", @"Food & Drink": @"Eten en drinken", @"Graphics & Design": @"Grafisch en ontwerp",
            @"Health & Fitness": @"Gezondheid en fitness", @"Kids": @"Kinderen", @"Lifestyle": @"Levensstijl",
            @"Magazines & Newspapers": @"Tijdschriften en kranten", @"Medical": @"Medisch", @"Music": @"Muziek",
            @"Navigation": @"Navigatie", @"News": @"Nieuws", @"Photo & Video": @"Foto en video",
            @"Productivity": @"Productiviteit", @"Puzzle": @"Puzzel", @"Racing": @"Racen",
            @"Reference": @"Naslagwerken", @"Role Playing": @"Rollenspel", @"Shopping": @"Winkelen",
            @"Simulation": @"Simulatie", @"Social Networking": @"Sociale netwerken", @"Sports": @"Sport",
            @"Strategy": @"Strategie", @"Travel": @"Reizen", @"Trivia": @"Quiz", @"Utilities": @"Hulpprogramma's",
            @"Weather": @"Weer", @"Word": @"Woordspellen",
        };
    });
    NSString *result = dutch[name] ?: name;
    return [genreID hasPrefix:@"70"] ? [@"Games: " stringByAppendingString:result] : result;
}

@end
