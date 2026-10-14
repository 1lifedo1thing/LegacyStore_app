#import <UIKit/UIKit.h>

@class RSAppListViewController;

typedef void (^RSAppListDone)(NSArray *apps, NSError *error);
typedef void (^RSAppListLoader)(RSAppListViewController *controller, RSAppListDone done);

@interface RSAppListViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, readonly) UITableView *tableView;
@property (nonatomic, copy) NSArray *apps;
@property (nonatomic) BOOL showsRank;
@property (nonatomic, copy) RSAppListLoader loader;
@property (nonatomic, copy) NSString *emptyText;
@property (nonatomic, copy) NSString *headerText;
@property (nonatomic, strong) UIView *topBar;
- (instancetype)initWithTitle:(NSString *)title loader:(RSAppListLoader)loader;
- (void)reload;
- (void)showStatus:(NSString *)text loading:(BOOL)loading;
@end

UIView *RSStatusView(CGFloat width, NSString *text, BOOL loading);
