#import "RSPriceButton.h"
#import "RSTheme.h"
#import "RSUtil.h"

static const CGFloat RSPriceButtonHeight = 26;

@implementation RSPriceButton

+ (instancetype)buttonWithRightEdge:(CGFloat)rightEdge y:(CGFloat)y {
    RSPriceButton *button = [self buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(rightEdge - 60, y, 60, RSPriceButtonHeight);
    button.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    button.titleLabel.font = [UIFont boldSystemFontOfSize:13];
    button.titleLabel.shadowOffset = CGSizeMake(0, 1);
    button.contentEdgeInsets = UIEdgeInsetsMake(1, 0, 0, 0);
    [button setPriceState:RSPriceStatePrice animated:NO];
    return button;
}

+ (UIImage *)greyImage {
    static UIImage *image;
    if (!image) image = RSButtonImage(RSPriceButtonHeight, 3, RSColor(0xa6a6a6),
        @[RSColor(0xfefefe), RSColor(0xf0f0f0), RSColor(0xdedede)], [UIColor colorWithWhite:1 alpha:0.8]);
    return image;
}

+ (UIImage *)greyPressedImage {
    static UIImage *image;
    if (!image) image = RSButtonImage(RSPriceButtonHeight, 3, RSColor(0x8e8e8e),
        @[RSColor(0xcfcfcf), RSColor(0xdcdcdc), RSColor(0xe6e6e6)], [UIColor colorWithWhite:1 alpha:0.8]);
    return image;
}

+ (UIImage *)greenImage {
    static UIImage *image;
    if (!image) image = RSButtonImage(RSPriceButtonHeight, 3, RSColor(0x3b7f1c),
        @[RSColor(0x9be06a), RSColor(0x6dbd3e), RSColor(0x4c9b25)], [UIColor colorWithWhite:1 alpha:0.8]);
    return image;
}

- (void)setPriceText:(NSString *)priceText {
    _priceText = [priceText copy];
    if (_priceState == RSPriceStatePrice) [self setPriceState:RSPriceStatePrice animated:NO];
}

- (void)setPriceState:(RSPriceState)state {
    [self setPriceState:state animated:NO];
}

- (void)setPriceState:(RSPriceState)state animated:(BOOL)animated {
    _priceState = state;
    NSString *title;
    switch (state) {
        case RSPriceStatePrice: title = _priceText ?: @"GRATIS"; break;
        case RSPriceStateConfirm: title = @"INSTALLEER APP"; break;
        case RSPriceStateInstalling: title = @"INSTALLEREN"; break;
        case RSPriceStateOpen: title = @"OPEN"; break;
        case RSPriceStateUpdate: title = @"WERK BIJ"; break;
        case RSPriceStateInstall: title = @"INSTALLEER"; break;
    }
    BOOL green = state == RSPriceStateConfirm;
    [self setTitle:title forState:UIControlStateNormal];
    [self setBackgroundImage:green ? [[self class] greenImage] : [[self class] greyImage] forState:UIControlStateNormal];
    [self setBackgroundImage:green ? [[self class] greenImage] : [[self class] greyPressedImage] forState:UIControlStateHighlighted];
    [self setTitleColor:green ? [UIColor whiteColor] : RSColor(0x6c6c6c) forState:UIControlStateNormal];
    [self setTitleShadowColor:green ? [UIColor colorWithWhite:0 alpha:0.35] : [UIColor whiteColor] forState:UIControlStateNormal];
    self.titleLabel.shadowOffset = green ? CGSizeMake(0, -1) : CGSizeMake(0, 1);
    self.enabled = state != RSPriceStateInstalling;
    self.alpha = state == RSPriceStateInstalling ? 0.55 : 1;

    CGFloat width = MAX(58, ceil([title sizeWithFont:self.titleLabel.font].width) + 22);
    CGRect frame = self.frame;
    frame.origin.x = CGRectGetMaxX(frame) - width;
    frame.size.width = width;
    if (animated) {
        [UIView animateWithDuration:0.2 animations:^{ self.frame = frame; }];
    } else {
        self.frame = frame;
    }
}

@end
