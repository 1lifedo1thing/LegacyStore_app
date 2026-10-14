#import "RSTheme.h"
#import "RSUtil.h"

UIImage *RSDrawImage(CGSize size, BOOL opaque, void (^draw)(CGContextRef ctx, CGRect rect)) {
    UIGraphicsBeginImageContextWithOptions(size, opaque, 0);
    draw(UIGraphicsGetCurrentContext(), (CGRect){CGPointZero, size});
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

void RSFillGradient(CGContextRef ctx, CGRect rect, NSArray *colors) {
    NSMutableArray *cgColors = [NSMutableArray array];
    for (UIColor *color in colors) [cgColors addObject:(__bridge id)color.CGColor];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGGradientRef gradient = CGGradientCreateWithColors(space, (__bridge CFArrayRef)cgColors, NULL);
    CGContextSaveGState(ctx);
    CGContextClipToRect(ctx, rect);
    CGContextDrawLinearGradient(ctx, gradient, CGPointMake(0, CGRectGetMinY(rect)), CGPointMake(0, CGRectGetMaxY(rect)), 0);
    CGContextRestoreGState(ctx);
    CGGradientRelease(gradient);
    CGColorSpaceRelease(space);
}

UIBezierPath *RSStarPath(CGPoint center, CGFloat outerRadius, CGFloat innerRadius) {
    UIBezierPath *star = [UIBezierPath bezierPath];
    for (int i = 0; i < 10; i++) {
        CGFloat r = (i % 2) ? innerRadius : outerRadius;
        CGFloat a = -M_PI_2 + i * M_PI / 5;
        CGPoint p = CGPointMake(center.x + r * cos(a), center.y + r * sin(a));
        i ? [star addLineToPoint:p] : [star moveToPoint:p];
    }
    [star closePath];
    return star;
}

UIImage *RSButtonImage(CGFloat height, CGFloat radius, UIColor *border, NSArray *fill, UIColor *bottomHighlight) {
    CGFloat below = bottomHighlight ? 1 : 0;
    UIImage *image = RSDrawImage(CGSizeMake(radius * 2 + 4, height), NO, ^(CGContextRef ctx, CGRect rect) {
        CGRect body = CGRectMake(0, 0, rect.size.width, rect.size.height - below);
        if (bottomHighlight) {
            [bottomHighlight setFill];
            [[UIBezierPath bezierPathWithRoundedRect:CGRectOffset(body, 0, 1) cornerRadius:radius] fill];
        }
        [border setFill];
        [[UIBezierPath bezierPathWithRoundedRect:body cornerRadius:radius] fill];
        CGContextSaveGState(ctx);
        [[UIBezierPath bezierPathWithRoundedRect:CGRectInset(body, 1, 1) cornerRadius:MAX(radius - 1, 0)] addClip];
        RSFillGradient(ctx, CGRectInset(body, 1, 1), fill);
        CGContextRestoreGState(ctx);
    });
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(0, radius + 1, 0, radius + 1)
                                 resizingMode:UIImageResizingModeStretch];
}

UILabel *RSLabel(UIFont *font, UIColor *color) {
    UILabel *label = [UILabel new];
    label.font = font;
    label.textColor = color;
    label.backgroundColor = [UIColor clearColor];
    return label;
}

static UIBezierPath *RSBackArrowPath(CGRect r, CGFloat radius) {
    CGFloat arrow = 11;
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(CGRectGetMinX(r), CGRectGetMidY(r))];
    [path addLineToPoint:CGPointMake(CGRectGetMinX(r) + arrow, CGRectGetMinY(r))];
    [path addLineToPoint:CGPointMake(CGRectGetMaxX(r) - radius, CGRectGetMinY(r))];
    [path addArcWithCenter:CGPointMake(CGRectGetMaxX(r) - radius, CGRectGetMinY(r) + radius) radius:radius
                startAngle:-M_PI_2 endAngle:0 clockwise:YES];
    [path addLineToPoint:CGPointMake(CGRectGetMaxX(r), CGRectGetMaxY(r) - radius)];
    [path addArcWithCenter:CGPointMake(CGRectGetMaxX(r) - radius, CGRectGetMaxY(r) - radius) radius:radius
                startAngle:0 endAngle:M_PI_2 clockwise:YES];
    [path addLineToPoint:CGPointMake(CGRectGetMinX(r) + arrow, CGRectGetMaxY(r))];
    [path closePath];
    return path;
}

static UIImage *RSBackButtonImage(NSArray *fill) {
    UIImage *image = RSDrawImage(CGSizeMake(24, 30), NO, ^(CGContextRef ctx, CGRect rect) {
        CGRect body = CGRectMake(0, 0, rect.size.width, 29);
        [[UIColor colorWithWhite:1 alpha:0.12] setFill];
        [RSBackArrowPath(CGRectOffset(body, 0, 1), 5) fill];
        [RSColor(0x0b0b0b) setFill];
        [RSBackArrowPath(body, 5) fill];
        CGContextSaveGState(ctx);
        [RSBackArrowPath(CGRectMake(1.4, 1, body.size.width - 2.4, body.size.height - 2), 4) addClip];
        RSFillGradient(ctx, body, fill);
        CGContextRestoreGState(ctx);
    });
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(0, 14, 0, 6) resizingMode:UIImageResizingModeStretch];
}

static UIImage *RSNavigationBarImage(void) {
    UIImage *image = RSDrawImage(CGSizeMake(1, 44), YES, ^(CGContextRef ctx, CGRect rect) {
        RSFillGradient(ctx, rect, @[RSColor(0x434343), RSColor(0x2a2a2a), RSColor(0x1b1b1b)]);
        [RSColor(0x5e5e5e) setFill];
        UIRectFill(CGRectMake(0, 0, 1, 0.5));
        [RSColor(0x050505) setFill];
        UIRectFill(CGRectMake(0, 43, 1, 1));
    });
    return [image resizableImageWithCapInsets:UIEdgeInsetsZero resizingMode:UIImageResizingModeStretch];
}

static UIImage *RSTabBarImage(void) {
    return RSDrawImage(CGSizeMake(320, 49), YES, ^(CGContextRef ctx, CGRect rect) {
        RSFillGradient(ctx, rect, @[RSColor(0x353535), RSColor(0x222222), RSColor(0x141414)]);
        [RSColor(0x060606) setFill];
        UIRectFill(CGRectMake(0, 0, 320, 1));
        [RSColor(0x464646) setFill];
        UIRectFill(CGRectMake(0, 1, 320, 0.5));
        for (int i = 1; i < 5; i++) {
            [RSColor(0x0c0c0c) setFill];
            UIRectFill(CGRectMake(i * 64 - 1, 1, 1, 48));
            [RSColor(0x383838) setFill];
            UIRectFill(CGRectMake(i * 64, 1, 0.5, 48));
        }
    });
}

static UIImage *RSTabSelectionImage(void) {
    return RSDrawImage(CGSizeMake(64, 49), NO, ^(CGContextRef ctx, CGRect rect) {
        RSFillGradient(ctx, CGRectMake(0, 1, 64, 48), @[RSColor(0x464646), RSColor(0x333333), RSColor(0x2a2a2a)]);
        [RSColor(0x5a5a5a) setFill];
        UIRectFill(CGRectMake(0, 1.5, 64, 0.5));
    });
}

@implementation RSTheme

+ (void)apply {
    NSDictionary *barTitle = @{
        UITextAttributeTextColor: RSColor(0xe6e6e6),
        UITextAttributeTextShadowColor: [UIColor blackColor],
        UITextAttributeTextShadowOffset: [NSValue valueWithUIOffset:UIOffsetMake(0, -1)],
        UITextAttributeFont: [UIFont boldSystemFontOfSize:20],
    };
    UINavigationBar *bar = [UINavigationBar appearance];
    [bar setBackgroundImage:RSNavigationBarImage() forBarMetrics:UIBarMetricsDefault];
    [bar setTitleTextAttributes:barTitle];

    UIBarButtonItem *item = [UIBarButtonItem appearanceWhenContainedIn:[UINavigationBar class], nil];
    NSArray *normal = @[RSColor(0x4c4c4c), RSColor(0x323232), RSColor(0x252525)];
    NSArray *pressed = @[RSColor(0x1c1c1c), RSColor(0x262626), RSColor(0x2e2e2e)];
    UIColor *glow = [UIColor colorWithWhite:1 alpha:0.12];
    [item setBackgroundImage:RSButtonImage(30, 5, RSColor(0x0b0b0b), normal, glow)
                    forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [item setBackgroundImage:RSButtonImage(30, 5, RSColor(0x0b0b0b), pressed, glow)
                    forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
    [item setBackButtonBackgroundImage:RSBackButtonImage(normal) forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [item setBackButtonBackgroundImage:RSBackButtonImage(pressed) forState:UIControlStateHighlighted barMetrics:UIBarMetricsDefault];
    [item setTitleTextAttributes:@{
        UITextAttributeTextColor: RSColor(0xe8e8e8),
        UITextAttributeTextShadowColor: [UIColor blackColor],
        UITextAttributeTextShadowOffset: [NSValue valueWithUIOffset:UIOffsetMake(0, -1)],
        UITextAttributeFont: [UIFont boldSystemFontOfSize:12],
    } forState:UIControlStateNormal];

    UITabBar *tabBar = [UITabBar appearance];
    [tabBar setBackgroundImage:RSTabBarImage()];
    [tabBar setSelectionIndicatorImage:RSTabSelectionImage()];
    UITabBarItem *tabItem = [UITabBarItem appearance];
    [tabItem setTitleTextAttributes:@{
        UITextAttributeTextColor: RSColor(0xa0a0a0),
        UITextAttributeTextShadowColor: [UIColor blackColor],
        UITextAttributeTextShadowOffset: [NSValue valueWithUIOffset:UIOffsetMake(0, -1)],
        UITextAttributeFont: [UIFont boldSystemFontOfSize:10],
    } forState:UIControlStateNormal];
    [tabItem setTitleTextAttributes:@{UITextAttributeTextColor: [UIColor whiteColor]} forState:UIControlStateSelected];

    UISearchBar *search = [UISearchBar appearance];
    [search setBackgroundImage:RSNavigationBarImage()];
    [search setTintColor:RSColor(0x2c2c2c)];
}

+ (UIColor *)backgroundColor {
    return RSColor(0xebebeb);
}

+ (UIColor *)textColor {
    return RSColor(0x2b2b2b);
}

+ (UIColor *)secondaryTextColor {
    return RSColor(0x7b7b7b);
}

+ (UIImage *)tabImageWithMask:(UIImage *)mask selected:(BOOL)selected {
    NSArray *colors = selected ? @[RSColor(0xb3ecff), RSColor(0x38aaf8), RSColor(0x0b62d6)]
                               : @[RSColor(0xc4c4c4), RSColor(0x8c8c8c), RSColor(0x6a6a6a)];
    UIImage *shape = RSDrawImage(mask.size, NO, ^(CGContextRef ctx, CGRect rect) {
        RSFillGradient(ctx, rect, colors);
        [mask drawInRect:rect blendMode:kCGBlendModeDestinationIn alpha:1];
    });
    return RSDrawImage(mask.size, NO, ^(CGContextRef ctx, CGRect rect) {
        if (selected)
            CGContextSetShadowWithColor(ctx, CGSizeZero, 4, [RSColor(0x39a7ff) colorWithAlphaComponent:0.8].CGColor);
        else
            CGContextSetShadowWithColor(ctx, CGSizeMake(0, -1), 0, [UIColor blackColor].CGColor);
        [shape drawInRect:rect];
    });
}

+ (UIImage *)starsWithRating:(double)rating size:(CGFloat)s {
    CGFloat gap = s * 0.15;
    return RSDrawImage(CGSizeMake(5 * s + 4 * gap, s), NO, ^(CGContextRef ctx, CGRect rect) {
        for (int i = 0; i < 5; i++) {
            CGFloat x = i * (s + gap);
            UIBezierPath *star = RSStarPath(CGPointMake(x + s / 2, s * 0.54), s / 2, s * 0.21);
            double fill = MAX(0, MIN(1, rating - i));
            if (fill > 0) {
                CGContextSaveGState(ctx);
                [star addClip];
                RSFillGradient(ctx, CGRectMake(x, 0, s * fill, s), @[RSColor(0xffc23d), RSColor(0xf0820e)]);
                CGContextRestoreGState(ctx);
            }
            [RSColor(0xd87510) setStroke];
            star.lineWidth = 0.6;
            [star stroke];
        }
    });
}

+ (UIView *)rowBackgroundDark:(BOOL)dark selected:(BOOL)selected {
    static UIImage *images[3];
    int i = selected ? 2 : dark ? 1 : 0;
    if (!images[i]) {
        unsigned fill = i == 2 ? 0xd3d3d3 : i == 1 ? 0xebebeb : 0xf7f7f7;
        images[i] = [RSDrawImage(CGSizeMake(1, 4), YES, ^(CGContextRef ctx, CGRect rect) {
            [RSColor(fill) setFill];
            UIRectFill(rect);
            [[UIColor colorWithWhite:1 alpha:selected ? 0.25 : 0.9] setFill];
            UIRectFill(CGRectMake(0, 0, 1, 1));
            [RSColor(0xcbcbcb) setFill];
            UIRectFill(CGRectMake(0, 3, 1, 1));
        }) resizableImageWithCapInsets:UIEdgeInsetsMake(1, 0, 1, 0) resizingMode:UIImageResizingModeStretch];
    }
    return [[UIImageView alloc] initWithImage:images[i]];
}

+ (UIView *)segmentBarWithControl:(UISegmentedControl *)control width:(CGFloat)width {
    UIImage *background = [RSDrawImage(CGSizeMake(1, 44), YES, ^(CGContextRef ctx, CGRect rect) {
        RSFillGradient(ctx, rect, @[RSColor(0xf2f2f2), RSColor(0xdcdcdc)]);
        [RSColor(0x9e9e9e) setFill];
        UIRectFill(CGRectMake(0, 43, 1, 1));
    }) resizableImageWithCapInsets:UIEdgeInsetsZero resizingMode:UIImageResizingModeStretch];
    UIImageView *bar = [[UIImageView alloc] initWithImage:background];
    bar.frame = CGRectMake(0, 0, width, 44);
    bar.userInteractionEnabled = YES;
    bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    NSArray *normal = @[RSColor(0xfdfdfd), RSColor(0xe9e9e9), RSColor(0xdadada)];
    NSArray *selected = @[RSColor(0xa3a3a3), RSColor(0xb9b9b9), RSColor(0xc6c6c6)];
    UIColor *border = RSColor(0x8f8f8f), *glow = [UIColor colorWithWhite:1 alpha:0.7];
    [control setBackgroundImage:RSButtonImage(31, 5, border, normal, glow) forState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    [control setBackgroundImage:RSButtonImage(31, 5, border, selected, glow) forState:UIControlStateSelected barMetrics:UIBarMetricsDefault];
    UIImage *divider = RSDrawImage(CGSizeMake(1, 31), NO, ^(CGContextRef ctx, CGRect rect) {
        [border setFill];
        UIRectFill(CGRectMake(0, 0, 1, 30));
    });
    for (NSNumber *left in @[@(UIControlStateNormal), @(UIControlStateSelected)])
        for (NSNumber *right in @[@(UIControlStateNormal), @(UIControlStateSelected)])
            [control setDividerImage:divider forLeftSegmentState:left.integerValue rightSegmentState:right.integerValue
                          barMetrics:UIBarMetricsDefault];
    NSValue *down = [NSValue valueWithUIOffset:UIOffsetMake(0, 1)];
    [control setTitleTextAttributes:@{
        UITextAttributeTextColor: RSColor(0x5e5e5e), UITextAttributeTextShadowColor: [UIColor whiteColor],
        UITextAttributeTextShadowOffset: down, UITextAttributeFont: [UIFont boldSystemFontOfSize:13],
    } forState:UIControlStateNormal];
    [control setTitleTextAttributes:@{
        UITextAttributeTextColor: RSColor(0x2e2e2e), UITextAttributeTextShadowColor: [UIColor colorWithWhite:1 alpha:0.4],
        UITextAttributeTextShadowOffset: down, UITextAttributeFont: [UIFont boldSystemFontOfSize:13],
    } forState:UIControlStateSelected];
    control.frame = CGRectMake(8, 6, width - 16, 31);
    control.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [bar addSubview:control];
    return bar;
}

+ (UIView *)engravedLineWithWidth:(CGFloat)width {
    UIView *line = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 2)];
    line.backgroundColor = [UIColor whiteColor];
    line.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UIView *dark = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, 1)];
    dark.backgroundColor = RSColor(0xc8c8c8);
    dark.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [line addSubview:dark];
    return line;
}

@end
