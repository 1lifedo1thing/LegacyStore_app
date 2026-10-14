#import <UIKit/UIKit.h>

@class RSAppSummary;

@interface RSAppCell : UITableViewCell
+ (CGFloat)height;
- (void)configureWithSummary:(RSAppSummary *)summary showRank:(BOOL)showRank dark:(BOOL)dark;
@end
