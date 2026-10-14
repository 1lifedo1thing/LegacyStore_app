#import <Foundation/Foundation.h>

typedef void (^RSJSONCompletion)(id json, NSError *error);

@interface RSAPI : NSObject
+ (NSInteger)activeRequestCount;
+ (NSURL *)URLWithPath:(NSString *)path query:(NSDictionary *)query;
+ (void)getPath:(NSString *)path query:(NSDictionary *)query completion:(RSJSONCompletion)completion;
+ (void)loadURL:(NSURL *)url process:(id (^)(NSData *data, NSError **error))process completion:(RSJSONCompletion)completion;
@end
