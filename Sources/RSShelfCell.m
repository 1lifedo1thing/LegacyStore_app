#import "RSShelfCell.h"
#import "RSScrollView.h"
#import "RSIconView.h"
#import "RSInstaller.h"
#import "RSModel.h"
#import "RSTheme.h"
#import "RSUtil.h"

static const CGFloat RSShelfIconSize = 67;
static const CGFloat RSShelfPitch = 95;

@interface RSShelfItem : UIControl
@property (nonatomic, strong) RSAppSummary *app;
@end

@implementation RSShelfItem

- (instancetype)initWithApp:(RSAppSummary *)app x:(CGFloat)x {
    if ((self = [super initWithFrame:CGRectMake(x, 0, RSShelfPitch - 8, 132)])) {
        _app = app;
        RSIconView *icon = [[RSIconView alloc] initWithSize:RSShelfIconSize];
        icon.frame = CGRectMake(0, 2, RSShelfIconSize, RSShelfIconSize);
        icon.iconURL = app.iconURL;
        icon.userInteractionEnabled = NO;
        [self addSubview:icon];

        RSPriceState state = [RSInstaller stateForSummary:app];
        NSString *price = state == RSPriceStateOpen ? @"GEÏNSTALLEERD"
                        : state == RSPriceStateInstalling ? @"INSTALLEREN" : (app.priceText ?: @"GRATIS");
        NSArray *lines = @[
            @[app.name ?: @"", [UIFont boldSystemFontOfSize:12], [RSTheme textColor]],
            @[app.category ?: @"", [UIFont systemFontOfSize:11], RSColor(0x707070)],
            @[price, [UIFont boldSystemFontOfSize:11], RSColor(0x9a9a9a)],
        ];
        CGFloat y = RSShelfIconSize + 10;
        for (NSArray *line in lines) {
            UILabel *label = RSLabel(line[1], line[2]);
            label.frame = CGRectMake(0, y, self.bounds.size.width, 15);
            label.text = line[0];
            label.shadowColor = [UIColor whiteColor];
            label.shadowOffset = CGSizeMake(0, 1);
            [self addSubview:label];
            y += 16;
        }
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.alpha = highlighted ? 0.6 : 1;
}

@end

@implementation RSShelfCell {
    UILabel *_titleLabel;
    UIButton *_seeAll;
    UIScrollView *_scroll;
    UIActivityIndicatorView *_spinner;
}

+ (CGFloat)height {
    return 200;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        CGFloat width = self.contentView.bounds.size.width;

        [self.contentView addSubview:[RSTheme engravedLineWithWidth:width]];
        _titleLabel = RSLabel([UIFont boldSystemFontOfSize:20], RSColor(0x585858));
        _titleLabel.frame = CGRectMake(10, 14, width - 110, 26);
        _titleLabel.shadowColor = [UIColor whiteColor];
        _titleLabel.shadowOffset = CGSizeMake(0, 1);
        [self.contentView addSubview:_titleLabel];

        _seeAll = [UIButton buttonWithType:UIButtonTypeCustom];
        _seeAll.frame = CGRectMake(width - 90, 12, 84, 30);
        _seeAll.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _seeAll.titleLabel.font = [UIFont boldSystemFontOfSize:15];
        _seeAll.titleLabel.shadowOffset = CGSizeMake(0, 1);
        _seeAll.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        [_seeAll setTitle:@"Alles ›" forState:UIControlStateNormal];
        [_seeAll setTitleColor:RSColor(0x9a9a9a) forState:UIControlStateNormal];
        [_seeAll setTitleColor:RSColor(0x5a5a5a) forState:UIControlStateHighlighted];
        [_seeAll setTitleShadowColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [_seeAll addTarget:self action:@selector(seeAllTapped) forControlEvents:UIControlEventTouchUpInside];
        [self.contentView addSubview:_seeAll];

        _scroll = [[RSScrollView alloc] initWithFrame:CGRectMake(0, 50, width, 140)];
        _scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _scroll.showsHorizontalScrollIndicator = NO;
        _scroll.scrollsToTop = NO;
        _scroll.delaysContentTouches = NO;
        [self.contentView addSubview:_scroll];

        _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        _spinner.center = CGPointMake(width / 2, 110);
        [self.contentView addSubview:_spinner];
    }
    return self;
}

- (void)configureWithTitle:(NSString *)title apps:(NSArray *)apps {
    _titleLabel.text = title;
    _seeAll.hidden = apps.count == 0;
    [_scroll.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    apps ? [_spinner stopAnimating] : [_spinner startAnimating];
    CGFloat x = 10;
    for (RSAppSummary *app in apps) {
        RSShelfItem *item = [[RSShelfItem alloc] initWithApp:app x:x];
        [item addTarget:self action:@selector(itemTapped:) forControlEvents:UIControlEventTouchUpInside];
        [_scroll addSubview:item];
        x += RSShelfPitch;
    }
    _scroll.contentSize = CGSizeMake(x + 2, _scroll.bounds.size.height);
    _scroll.contentOffset = CGPointZero;
}

- (void)itemTapped:(RSShelfItem *)item {
    if (self.onSelectApp) self.onSelectApp(item.app);
}

- (void)seeAllTapped {
    if (self.onSeeAll) self.onSeeAll();
}

@end
