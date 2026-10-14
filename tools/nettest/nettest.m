#import <Foundation/Foundation.h>

int main(int argc, char **argv) {
    @autoreleasepool {
        for (int i = 1; i < argc; i++) {
            NSURL *url = [NSURL URLWithString:[NSString stringWithUTF8String:argv[i]]];
            NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                 timeoutInterval:30];
            NSURLResponse *response = nil;
            NSError *error = nil;
            NSDate *start = [NSDate date];
            NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
            printf("%s -> %ld, %lu bytes, %.2fs %s\n", argv[i], (long)[(NSHTTPURLResponse *)response statusCode],
                   (unsigned long)data.length, -[start timeIntervalSinceNow],
                   error ? [[error description] UTF8String] : "");
        }
    }
    return 0;
}
