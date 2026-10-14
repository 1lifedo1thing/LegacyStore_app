#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, RSPriceState) {
    RSPriceStatePrice,
    RSPriceStateConfirm,
    RSPriceStateInstalling,
    RSPriceStateOpen,
    RSPriceStateUpdate,
    RSPriceStateInstall,
};

@interface RSPriceButton : UIButton
+ (instancetype)buttonWithRightEdge:(CGFloat)rightEdge y:(CGFloat)y;
@property (nonatomic) RSPriceState priceState;
@property (nonatomic, copy) NSString *priceText;
- (void)setPriceState:(RSPriceState)state animated:(BOOL)animated;
@end
