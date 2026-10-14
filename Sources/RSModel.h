#import <UIKit/UIKit.h>

@interface RSAppSummary : NSObject
@property (nonatomic, copy) NSString *appStoreID;
@property (nonatomic, copy) NSString *bundleID;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *developer;
@property (nonatomic, copy) NSString *genreID;
@property (nonatomic, copy) NSString *subtitle;
@property (nonatomic, copy) NSString *priceText;
@property (nonatomic, strong) NSURL *iconURL;
@property (nonatomic) NSInteger rank;
@property (nonatomic, copy) NSString *updateVersion;
@property (nonatomic, strong) UIImage *localIcon;
+ (instancetype)summaryWithApp:(NSDictionary *)app;
+ (instancetype)summaryWithChartPosition:(NSDictionary *)position;
- (NSString *)category;
@end

@interface RSInstallable : NSObject
@property (nonatomic, copy) NSString *version;
@property (nonatomic, copy) NSString *minimumOS;
@property (nonatomic, copy) NSString *releaseDate;
@property (nonatomic, strong) NSURL *manifestURL;
@property (nonatomic) long long size;
+ (NSArray *)installablesForApp:(NSDictionary *)app;
- (NSURL *)installURL;
@end

NSString *RSPriceText(id amount, NSString *currency);

@interface RSRating : NSObject
@property (nonatomic) double average;
@property (nonatomic) NSInteger count;
@property (nonatomic, copy) NSString *priceText;
+ (instancetype)ratingFromJSON:(id)json;
@end

NSDictionary *RSPreferredScreenshotSet(id json, NSString *version);

extern NSString *const RSGenresDidLoadNotification;

@interface RSGenres : NSObject
+ (void)loadGenres;
+ (NSArray *)all;
+ (NSString *)nameForID:(NSString *)genreID;
+ (NSString *)dutchName:(NSString *)englishName genreID:(NSString *)genreID;
@end
