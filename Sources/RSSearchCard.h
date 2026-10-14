#import <UIKit/UIKit.h>

@class RSAppSummary;

@interface RSSearchCard : UIControl
@property (nonatomic, readonly) RSAppSummary *app;
- (instancetype)initWithFrame:(CGRect)frame app:(RSAppSummary *)app;
- (void)loadDetails;
- (void)refreshButton;
@end
