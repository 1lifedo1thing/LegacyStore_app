#import <UIKit/UIKit.h>

@interface RSImageCache : NSObject
+ (instancetype)sharedCache;
+ (UIImage *)placeholderIconOfSize:(CGFloat)size;
+ (UIImage *)iconFromImage:(UIImage *)image size:(CGFloat)size;
- (UIImage *)cachedIconAtURL:(NSURL *)url size:(CGFloat)size;
- (void)loadIconAtURL:(NSURL *)url size:(CGFloat)size completion:(void (^)(UIImage *image))completion;
- (void)loadImageAtURL:(NSURL *)url completion:(void (^)(UIImage *image))completion;
@end
