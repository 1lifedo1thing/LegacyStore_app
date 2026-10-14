#import "RSImageCache.h"
#import "RSAPI.h"

static CGFloat RSScreenScale;

static UIImage *RSRenderIcon(UIImage *source, CGFloat size) {
    CGRect rect = CGRectMake(0, 0, size, size);
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, RSScreenScale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    [[UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:size * 0.175] addClip];

    if (source) {
        [source drawInRect:rect];
    } else {
        [[UIColor colorWithWhite:0.82 alpha:1] setFill];
        UIRectFill(rect);
    }

    CGContextSaveGState(ctx);
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(-size * 0.5, -size * 0.95, size * 2, size * 1.45)] addClip];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGFloat components[] = {1, 1, 1, 0.30, 1, 1, 1, 0.04};
    CGFloat locations[] = {0, 1};
    CGGradientRef gloss = CGGradientCreateWithColorComponents(space, components, locations, 2);
    CGContextDrawLinearGradient(ctx, gloss, CGPointZero, CGPointMake(0, size * 0.5), 0);
    CGGradientRelease(gloss);
    CGColorSpaceRelease(space);
    CGContextRestoreGState(ctx);

    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

static UIImage *RSDecodeImage(UIImage *source) {
    if (!source) return nil;
    UIGraphicsBeginImageContextWithOptions(source.size, YES, source.scale);
    [source drawAtPoint:CGPointZero];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

@implementation RSImageCache {
    NSCache *_cache;
}

+ (instancetype)sharedCache {
    static RSImageCache *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        RSScreenScale = [UIScreen mainScreen].scale;
        shared = [self new];
    });
    return shared;
}

+ (UIImage *)placeholderIconOfSize:(CGFloat)size {
    static NSMutableDictionary *placeholders;
    if (!placeholders) placeholders = [NSMutableDictionary dictionary];
    [self sharedCache];
    NSNumber *key = @(size);
    if (!placeholders[key]) placeholders[key] = RSRenderIcon(nil, size);
    return placeholders[key];
}

+ (UIImage *)iconFromImage:(UIImage *)image size:(CGFloat)size {
    [self sharedCache];
    return RSRenderIcon(image, size);
}

- (instancetype)init {
    if ((self = [super init])) {
        _cache = [NSCache new];
        _cache.countLimit = 300;
    }
    return self;
}

- (NSString *)keyForURL:(NSURL *)url size:(CGFloat)size {
    return [NSString stringWithFormat:@"%g|%@", size, url.absoluteString];
}

- (UIImage *)cachedIconAtURL:(NSURL *)url size:(CGFloat)size {
    return url ? [_cache objectForKey:[self keyForURL:url size:size]] : nil;
}

- (void)loadIconAtURL:(NSURL *)url size:(CGFloat)size completion:(void (^)(UIImage *))completion {
    [self loadURL:url key:[self keyForURL:url size:size] transform:^UIImage *(UIImage *image) {
        return RSRenderIcon(image, size);
    } completion:completion];
}

- (void)loadImageAtURL:(NSURL *)url completion:(void (^)(UIImage *))completion {
    [self loadURL:url key:url.absoluteString transform:^UIImage *(UIImage *image) {
        return RSDecodeImage(image);
    } completion:completion];
}

- (void)loadURL:(NSURL *)url key:(NSString *)key transform:(UIImage * (^)(UIImage *))transform
     completion:(void (^)(UIImage *))completion {
    if (!url) return;
    UIImage *cached = [_cache objectForKey:key];
    if (cached) {
        completion(cached);
        return;
    }
    NSCache *cache = _cache;
    [RSAPI loadURL:url process:^id(NSData *data, NSError **error) {
        UIImage *image = [UIImage imageWithData:data];
        return image ? transform(image) : nil;
    } completion:^(UIImage *image, NSError *error) {
        if (!image) return;
        [cache setObject:image forKey:key];
        completion(image);
    }];
}

@end
