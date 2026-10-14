#import "RSAPI.h"
#import "RSUtil.h"
#import <UIKit/UIKit.h>

static NSString *const RSBaseURL = @"https://legacystore.app";

static NSInteger RSActiveRequests;

static void RSNetworkActivity(NSInteger delta) {
    NSInteger active = RSActiveRequests += delta;
    [UIApplication sharedApplication].networkActivityIndicatorVisible = active > 0;
}

@implementation RSAPI

+ (NSInteger)activeRequestCount {
    return RSActiveRequests;
}

+ (NSOperationQueue *)queue {
    static NSOperationQueue *queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = [NSOperationQueue new];
        queue.maxConcurrentOperationCount = 4;
    });
    return queue;
}

+ (NSURL *)URLWithPath:(NSString *)path query:(NSDictionary *)query {
    NSMutableString *s = [NSMutableString stringWithFormat:@"%@%@", RSBaseURL, path];
    if (query.count) {
        NSMutableArray *parts = [NSMutableArray array];
        for (NSString *key in [query.allKeys sortedArrayUsingSelector:@selector(compare:)])
            [parts addObject:[NSString stringWithFormat:@"%@=%@", RSEscape(key), RSEscape(RSString(query[key]))]];
        [s appendFormat:@"?%@", [parts componentsJoinedByString:@"&"]];
    }
    return [NSURL URLWithString:s];
}

+ (void)getPath:(NSString *)path query:(NSDictionary *)query completion:(RSJSONCompletion)completion {
    [self loadURL:[self URLWithPath:path query:query] process:^id(NSData *data, NSError **error) {
        return [NSJSONSerialization JSONObjectWithData:data options:0 error:error];
    } completion:completion];
}

+ (void)loadURL:(NSURL *)url process:(id (^)(NSData *, NSError **))process completion:(RSJSONCompletion)completion {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url
        cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];
    [request setValue:[NSString stringWithFormat:@"RetroStore/0.1 (%@; iOS %@)", RSDeviceModel(), RSSystemVersion()]
        forHTTPHeaderField:@"User-Agent"];

    RSNetworkActivity(+1);
    [NSURLConnection sendAsynchronousRequest:request queue:[self queue]
        completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]] ? [(NSHTTPURLResponse *)response statusCode] : 0;
        if (!error && status >= 400) {
            id body = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
            NSString *message = [body isKindOfClass:[NSDictionary class]] ? RSString(body[@"error"][@"message"]) : nil;
            error = [NSError errorWithDomain:@"RSAPI" code:status userInfo:@{NSLocalizedDescriptionKey:
                message ?: [NSString stringWithFormat:@"De server gaf foutcode %ld.", (long)status]}];
        }
        id result = nil;
        if (!error) result = process(data, &error);
        if (error) NSLog(@"[RetroStore] %@ mislukt: %@", url, error);
        dispatch_async(dispatch_get_main_queue(), ^{
            RSNetworkActivity(-1);
            completion(error ? nil : result, error);
        });
    }];
}

@end
