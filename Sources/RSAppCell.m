#import "RSAppCell.h"
#import "RSIconView.h"
#import "RSInstaller.h"
#import "RSModel.h"
#import "RSTheme.h"
#import "RSUtil.h"

static const CGFloat RSIconSize = 57;

@implementation RSAppCell {
    RSAppSummary *_summary;
    BOOL _showRank;
    UILabel *_rankLabel, *_nameLabel, *_categoryLabel;
    RSIconView *_iconView;
    RSPriceButton *_button;
}

+ (CGFloat)height {
    return 75;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)identifier {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier])) {
        _rankLabel = RSLabel([UIFont boldSystemFontOfSize:15], RSColor(0x8a8a8a));
        _rankLabel.textAlignment = NSTextAlignmentCenter;
        _rankLabel.adjustsFontSizeToFitWidth = YES;
        _rankLabel.shadowColor = [UIColor whiteColor];
        _rankLabel.shadowOffset = CGSizeMake(0, 1);
        _iconView = [[RSIconView alloc] initWithSize:RSIconSize];
        _nameLabel = RSLabel([UIFont boldSystemFontOfSize:15], [RSTheme textColor]);
        _nameLabel.numberOfLines = 2;
        _nameLabel.shadowColor = [UIColor whiteColor];
        _nameLabel.shadowOffset = CGSizeMake(0, 1);
        _categoryLabel = RSLabel([UIFont systemFontOfSize:12], [RSTheme secondaryTextColor]);
        _button = [RSPriceButton buttonWithRightEdge:self.contentView.bounds.size.width - 10 y:24];
        [_button addTarget:self action:@selector(buttonTapped) forControlEvents:UIControlEventTouchUpInside];
        for (UIView *view in @[_rankLabel, _iconView, _nameLabel, _categoryLabel, _button])
            [self.contentView addSubview:view];
        self.selectedBackgroundView = [RSTheme rowBackgroundDark:NO selected:YES];
    }
    return self;
}

- (void)configureWithSummary:(RSAppSummary *)summary showRank:(BOOL)showRank dark:(BOOL)dark {
    _summary = summary;
    _showRank = showRank;
    self.backgroundView = [RSTheme rowBackgroundDark:dark selected:NO];
    _rankLabel.hidden = !showRank;
    _rankLabel.text = [NSString stringWithFormat:@"%ld", (long)summary.rank];
    _iconView.iconURL = summary.iconURL;
    if (!summary.iconURL && summary.localIcon) [_iconView setLocalImage:summary.localIcon];
    _nameLabel.text = summary.name;
    _categoryLabel.text = summary.category;
    _button.priceText = summary.priceText;
    _button.priceState = [RSInstaller stateForSummary:summary];
    [self setNeedsLayout];
}

- (void)buttonTapped {
    [RSInstaller handleTapOnButton:_button summary:_summary];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat height = self.contentView.bounds.size.height;
    CGFloat x = 9;
    if (_showRank) {
        _rankLabel.frame = CGRectMake(2, 0, 28, height);
        x = 31;
    }
    _iconView.frame = CGRectMake(x, round((height - RSIconSize) / 2) - 1, RSIconSize, RSIconSize);
    CGFloat textX = x + RSIconSize + 10;
    CGFloat textWidth = CGRectGetMinX(_button.frame) - 8 - textX;
    CGSize nameSize = [_nameLabel.text sizeWithFont:_nameLabel.font constrainedToSize:CGSizeMake(textWidth, 38)
                                      lineBreakMode:NSLineBreakByTruncatingTail];
    CGFloat blockHeight = nameSize.height + 16;
    CGFloat y = round((height - blockHeight) / 2) - 1;
    _nameLabel.frame = CGRectMake(textX, y, textWidth, nameSize.height);
    _categoryLabel.frame = CGRectMake(textX, y + nameSize.height + 1, textWidth, 15);
}

@end
