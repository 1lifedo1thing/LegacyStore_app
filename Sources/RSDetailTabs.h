#import <UIKit/UIKit.h>

@interface RSDetailTabs : UIControl
- (instancetype)initWithFrame:(CGRect)frame titles:(NSArray *)titles;
@property (nonatomic) NSInteger selectedIndex;
@end
