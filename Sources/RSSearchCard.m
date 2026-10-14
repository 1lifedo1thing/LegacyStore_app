#import "RSSearchCard.h"
#import "RSAPI.h"
#import "RSIconView.h"
#import "RSImageCache.h"
#import "RSInstaller.h"
#import "RSModel.h"
#import "RSTheme.h"
#import "RSUtil.h"
#import <QuartzCore/QuartzCore.h>

@implementation RSSearchCard {
    RSPriceButton *_button;
    UIImageView *_stars;
    UILabel *_ratingCount;
    UIImageView *_screenshot;
    BOOL _loaded;
}

- (instancetype)initWithFrame:(CGRect)frame app:(RSAppSummary *)app {
    if ((self = [super initWithFrame:frame])) {
        _app = app;
        CGFloat width = frame.size.width;
        self.backgroundColor = RSColor(0xf6f6f6);
        self.layer.cornerRadius = 7;
        self.layer.borderColor = RSColor(0xbdbdbd).CGColor;
        self.layer.borderWidth = 1;
        self.layer.shadowColor = [UIColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.18;
        self.layer.shadowRadius = 2;
        self.layer.shadowOffset = CGSizeMake(0, 1);
        self.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:7].CGPath;

        RSIconView *icon = [[RSIconView alloc] initWithSize:72];
        icon.frame = CGRectMake(12, 14, 72, 72);
        icon.iconURL = app.iconURL;
        [self addSubview:icon];

        CGFloat x = 96;
        UILabel *name = RSLabel([UIFont boldSystemFontOfSize:17], [RSTheme textColor]);
        name.frame = CGRectMake(x, 12, width - x - 10, 21);
        name.text = app.name;
        UILabel *developer = RSLabel([UIFont systemFontOfSize:13], RSColor(0x707070));
        developer.frame = CGRectMake(x, 33, width - x - 10, 17);
        developer.text = app.developer;
        UILabel *category = RSLabel([UIFont systemFontOfSize:13], RSColor(0x707070));
        category.frame = CGRectMake(x, 49, width - x - 84, 17);
        category.text = [RSGenres nameForID:app.genreID];
        for (UILabel *label in @[name, developer, category]) {
            label.shadowColor = [UIColor whiteColor];
            label.shadowOffset = CGSizeMake(0, 1);
            [self addSubview:label];
        }

        _stars = [[UIImageView alloc] initWithFrame:CGRectMake(x, 72, 0, 0)];
        _ratingCount = RSLabel([UIFont systemFontOfSize:11], RSColor(0x8a8a8a));
        _ratingCount.frame = CGRectMake(x + 62, 69, 60, 16);
        [self addSubview:_stars];
        [self addSubview:_ratingCount];

        _button = [RSPriceButton buttonWithRightEdge:width - 12 y:58];
        [_button addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_button];
        [self refreshButton];

        _screenshot = [[UIImageView alloc] initWithFrame:CGRectMake(12, 100, width - 24, frame.size.height - 112)];
        _screenshot.contentMode = UIViewContentModeScaleAspectFit;
        _screenshot.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        [self addSubview:_screenshot];
    }
    return self;
}

- (void)refreshButton {
    _button.priceText = _app.priceText;
    _button.priceState = [RSInstaller stateForSummary:_app];
}

- (void)buttonTapped {
    [RSInstaller handleTapOnButton:_button summary:_app];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.backgroundColor = highlighted ? RSColor(0xe4e4e4) : RSColor(0xf6f6f6);
}

- (void)loadDetails {
    if (_loaded) return;
    _loaded = YES;
    __weak RSSearchCard *weakSelf = self;
    NSString *base = [@"/api/v1/apps/" stringByAppendingString:RSEscape(_app.appStoreID)];
    [RSAPI getPath:[base stringByAppendingString:@"/ratings"] query:nil completion:^(id json, NSError *error) {
        [weakSelf showRating:[RSRating ratingFromJSON:json]];
    }];
    [RSAPI getPath:[base stringByAppendingString:@"/screenshots"] query:nil completion:^(id json, NSError *error) {
        NSDictionary *shot = [RSPreferredScreenshotSet(json, nil)[@"shots"] firstObject];
        NSString *url = [shot isKindOfClass:[NSDictionary class]] ? RSString(shot[@"url"]) : nil;
        if (!url) return;
        [[RSImageCache sharedCache] loadImageAtURL:[NSURL URLWithString:url] completion:^(UIImage *image) {
            [weakSelf showScreenshot:image];
        }];
    }];
}

- (void)showRating:(RSRating *)rating {
    if (!rating) return;
    if (!_app.priceText && rating.priceText) {
        _app.priceText = rating.priceText;
        [self refreshButton];
    }
    if (rating.average <= 0) return;
    _stars.image = [RSTheme starsWithRating:rating.average size:11];
    _stars.frame = (CGRect){_stars.frame.origin, _stars.image.size};
    _ratingCount.frame = CGRectMake(CGRectGetMaxX(_stars.frame) + 4, 69, 70, 16);
    _ratingCount.text = [NSString stringWithFormat:@"(%ld)", (long)rating.count];
}

- (void)showScreenshot:(UIImage *)image {
    if (!image) return;
    CGRect area = _screenshot.frame;
    CGFloat scale = MIN(area.size.width / image.size.width, area.size.height / image.size.height);
    CGSize size = CGSizeMake(round(image.size.width * scale), round(image.size.height * scale));
    _screenshot.frame = CGRectMake(round(CGRectGetMidX(area) - size.width / 2), area.origin.y, size.width, size.height);
    _screenshot.image = image;
    _screenshot.layer.borderColor = RSColor(0xb0b0b0).CGColor;
    _screenshot.layer.borderWidth = 1;
    _screenshot.alpha = 0;
    [UIView animateWithDuration:0.25 animations:^{ _screenshot.alpha = 1; }];
}

@end
