#import <UIKit/UIKit.h>

UIImage *RSDrawImage(CGSize size, BOOL opaque, void (^draw)(CGContextRef ctx, CGRect rect));
void RSFillGradient(CGContextRef ctx, CGRect rect, NSArray *colors);
UIBezierPath *RSStarPath(CGPoint center, CGFloat outerRadius, CGFloat innerRadius);
UIImage *RSButtonImage(CGFloat height, CGFloat radius, UIColor *border, NSArray *fill, UIColor *bottomHighlight);
UILabel *RSLabel(UIFont *font, UIColor *color);

@interface RSTheme : NSObject
+ (void)apply;
+ (UIColor *)backgroundColor;
+ (UIColor *)textColor;
+ (UIColor *)secondaryTextColor;
+ (UIImage *)tabImageWithMask:(UIImage *)mask selected:(BOOL)selected;
+ (UIImage *)starsWithRating:(double)rating size:(CGFloat)starSize;
+ (UIView *)rowBackgroundDark:(BOOL)dark selected:(BOOL)selected;
+ (UIView *)segmentBarWithControl:(UISegmentedControl *)control width:(CGFloat)width;
+ (UIView *)engravedLineWithWidth:(CGFloat)width;
@end
