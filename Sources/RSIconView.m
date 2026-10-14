#import "RSIconView.h"
#import "RSImageCache.h"
#import <QuartzCore/QuartzCore.h>

@implementation RSIconView

- (instancetype)initWithSize:(CGFloat)size {
    if ((self = [super initWithFrame:CGRectMake(0, 0, size, size)])) {
        _size = size;
        self.image = [RSImageCache placeholderIconOfSize:size];
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.45;
        self.layer.shadowRadius = size > 60 ? 2 : 1.5;
        self.layer.shadowOffset = CGSizeMake(0, 1);
        self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:size * 0.175].CGPath;
    }
    return self;
}

- (void)setIconURL:(NSURL *)url {
    if (url == _iconURL || [url isEqual:_iconURL]) return;
    _iconURL = url;
    RSImageCache *cache = [RSImageCache sharedCache];
    self.image = [cache cachedIconAtURL:url size:_size] ?: [RSImageCache placeholderIconOfSize:_size];
    if (!url) return;
    __weak RSIconView *weakSelf = self;
    [cache loadIconAtURL:url size:_size completion:^(UIImage *image) {
        RSIconView *view = weakSelf;
        if ([view.iconURL isEqual:url]) view.image = image;
    }];
}

- (void)setLocalImage:(UIImage *)image {
    _iconURL = nil;
    self.image = image ? [RSImageCache iconFromImage:image size:_size] : [RSImageCache placeholderIconOfSize:_size];
}

@end
