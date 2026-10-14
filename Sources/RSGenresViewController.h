#import <UIKit/UIKit.h>

typedef void (^RSGenreSelection)(NSString *genreID, NSString *name);

@interface RSGenresViewController : UITableViewController
- (instancetype)initWithAllTitle:(NSString *)allTitle selection:(RSGenreSelection)selection;
@property (nonatomic, copy) NSString *selectedGenreID;
@end
