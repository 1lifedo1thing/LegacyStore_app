#import "RSDetailTabs.h"
#import "RSTheme.h"
#import "RSUtil.h"

static const CGFloat RSNotchHeight = 7;

@implementation RSDetailTabs {
    NSArray *_titles;
    NSArray *_centers;
}

- (instancetype)initWithFrame:(CGRect)frame titles:(NSArray *)titles {
    if ((self = [super initWithFrame:frame])) {
        _titles = [titles copy];
        self.backgroundColor = [UIColor clearColor];
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}

- (UIFont *)font {
    return [UIFont boldSystemFontOfSize:16];
}

- (NSArray *)centers {
    CGFloat gap = 30, total = 0;
    NSMutableArray *widths = [NSMutableArray array];
    for (NSString *title in _titles) {
        CGFloat w = [title sizeWithFont:[self font]].width;
        [widths addObject:@(w)];
        total += w;
    }
    total += gap * (_titles.count - 1);
    CGFloat x = round((self.bounds.size.width - total) / 2);
    NSMutableArray *centers = [NSMutableArray array];
    for (NSNumber *w in widths) {
        [centers addObject:@(x + w.doubleValue / 2)];
        x += w.doubleValue + gap;
    }
    return centers;
}

- (void)setSelectedIndex:(NSInteger)index {
    _selectedIndex = index;
    [self setNeedsDisplay];
}

- (void)endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    [super endTrackingWithTouch:touch withEvent:event];
    CGFloat x = [touch locationInView:self].x;
    NSArray *centers = [self centers];
    NSInteger best = 0;
    for (NSUInteger i = 1; i < centers.count; i++)
        if (fabs([centers[i] doubleValue] - x) < fabs([centers[best] doubleValue] - x)) best = i;
    if (best != _selectedIndex) {
        self.selectedIndex = best;
        [self sendActionsForControlEvents:UIControlEventValueChanged];
    }
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect bounds = self.bounds;
    CGFloat lineY = bounds.size.height - 1.5;
    NSArray *centers = [self centers];
    CGFloat notchX = round([centers[_selectedIndex] doubleValue]);
    UIFont *font = [self font];

    UIBezierPath *below = [UIBezierPath bezierPath];
    [below moveToPoint:CGPointMake(0, lineY)];
    [below addLineToPoint:CGPointMake(notchX - RSNotchHeight, lineY)];
    [below addLineToPoint:CGPointMake(notchX, lineY - RSNotchHeight)];
    [below addLineToPoint:CGPointMake(notchX + RSNotchHeight, lineY)];
    [below addLineToPoint:CGPointMake(bounds.size.width, lineY)];
    [[RSTheme backgroundColor] setFill];
    UIBezierPath *fill = [below copy];
    [fill addLineToPoint:CGPointMake(bounds.size.width, bounds.size.height)];
    [fill addLineToPoint:CGPointMake(0, bounds.size.height)];
    [fill closePath];
    [fill fill];
    [[UIColor whiteColor] setStroke];
    CGContextSaveGState(ctx);
    CGContextTranslateCTM(ctx, 0, 1);
    below.lineWidth = 1;
    [below stroke];
    CGContextRestoreGState(ctx);
    [RSColor(0xa9a9a9) setStroke];
    [below stroke];

    CGFloat pillY = round((bounds.size.height - RSNotchHeight - 28) / 2);
    for (NSUInteger i = 0; i < _titles.count; i++) {
        NSString *title = _titles[i];
        CGSize size = [title sizeWithFont:font];
        CGFloat cx = [centers[i] doubleValue];
        BOOL selected = (NSInteger)i == _selectedIndex;
        if (selected) {
            CGRect pill = CGRectMake(round(cx - size.width / 2 - 13), pillY, round(size.width + 26), 28);
            [[UIColor colorWithWhite:1 alpha:0.9] setFill];
            [[UIBezierPath bezierPathWithRoundedRect:CGRectOffset(pill, 0, 1) cornerRadius:14] fill];
            [RSColor(0x9b9b9b) setFill];
            [[UIBezierPath bezierPathWithRoundedRect:pill cornerRadius:14] fill];
            CGContextSaveGState(ctx);
            [[UIBezierPath bezierPathWithRoundedRect:CGRectInset(pill, 1, 1) cornerRadius:13] addClip];
            RSFillGradient(ctx, CGRectInset(pill, 1, 1), @[RSColor(0xbdbdbd), RSColor(0xcfcfcf), RSColor(0xd8d8d8)]);
            CGContextRestoreGState(ctx);
        }
        CGPoint origin = CGPointMake(round(cx - size.width / 2), pillY + round((28 - size.height) / 2));
        CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 0, [UIColor colorWithWhite:1 alpha:selected ? 0.6 : 1].CGColor);
        [(selected ? RSColor(0x404040) : RSColor(0x7a7a7a)) setFill];
        [title drawAtPoint:origin withFont:font];
        CGContextSetShadowWithColor(ctx, CGSizeZero, 0, NULL);
    }
}

@end
