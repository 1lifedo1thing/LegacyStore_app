#import <UIKit/UIKit.h>

@interface RSIconView : UIImageView
- (instancetype)initWithSize:(CGFloat)size;
@property (nonatomic, readonly) CGFloat size;
@property (nonatomic, strong) NSURL *iconURL;
- (void)setLocalImage:(UIImage *)image;
@end
