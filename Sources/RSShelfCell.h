#import <UIKit/UIKit.h>

@class RSAppSummary;

@interface RSShelfCell : UITableViewCell
+ (CGFloat)height;
@property (nonatomic, copy) void (^onSelectApp)(RSAppSummary *app);
@property (nonatomic, copy) void (^onSeeAll)(void);
- (void)configureWithTitle:(NSString *)title apps:(NSArray *)apps;
@end
