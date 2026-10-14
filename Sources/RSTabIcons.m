#import "RSTabIcons.h"
#import "RSTheme.h"

@implementation RSTabIcons

+ (UIImage *)iconWithDrawing:(void (^)(CGContextRef ctx))drawing {
    return RSDrawImage(CGSizeMake(30, 30), NO, ^(CGContextRef ctx, CGRect rect) {
        [[UIColor blackColor] set];
        drawing(ctx);
    });
}

+ (UIImage *)featured {
    return [self iconWithDrawing:^(CGContextRef ctx) {
        void (^spotlight)(CGRect, CGPoint) = ^(CGRect ellipse, CGPoint tip) {
            UIBezierPath *beam = [UIBezierPath bezierPath];
            [beam moveToPoint:CGPointMake(CGRectGetMinX(ellipse) + 0.5, CGRectGetMidY(ellipse))];
            [beam addLineToPoint:tip];
            [beam addLineToPoint:CGPointMake(CGRectGetMaxX(ellipse) - 0.5, CGRectGetMidY(ellipse))];
            [beam closePath];
            [[UIColor colorWithWhite:0 alpha:0.62] setFill];
            [beam fill];
            [[UIColor blackColor] setFill];
            [[UIBezierPath bezierPathWithOvalInRect:ellipse] fill];
        };
        spotlight(CGRectMake(19.2, 5.2, 10.4, 4.8), CGPointMake(10.5, 26));
        spotlight(CGRectMake(0.4, 3, 11.8, 5.4), CGPointMake(21, 26));
    }];
}

+ (UIImage *)charts {
    return [self iconWithDrawing:^(CGContextRef ctx) {
        UIBezierPath *star = RSStarPath(CGPointMake(15, 16), 14, 5.8);
        star.lineJoinStyle = kCGLineJoinRound;
        [star fill];
    }];
}

+ (UIImage *)genius {
    return [self iconWithDrawing:^(CGContextRef ctx) {
        for (int i = 0; i < 3; i++) {
            CGContextSaveGState(ctx);
            CGContextTranslateCTM(ctx, 15, 15);
            CGContextRotateCTM(ctx, i * M_PI / 3);
            UIBezierPath *orbit = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(-13.5, -5, 27, 10)];
            orbit.lineWidth = 1.8;
            [orbit stroke];
            CGContextRestoreGState(ctx);
        }
        [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(12, 12, 6, 6)] fill];
    }];
}

+ (UIImage *)search {
    return [self iconWithDrawing:^(CGContextRef ctx) {
        UIBezierPath *lens = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(3.5, 2.5, 17, 17)];
        lens.lineWidth = 3.2;
        [lens stroke];
        UIBezierPath *handle = [UIBezierPath bezierPath];
        [handle moveToPoint:CGPointMake(18.5, 18)];
        [handle addLineToPoint:CGPointMake(26.5, 26.5)];
        handle.lineWidth = 4.8;
        handle.lineCapStyle = kCGLineCapRound;
        [handle stroke];
    }];
}

+ (UIImage *)updates {
    return [self iconWithDrawing:^(CGContextRef ctx) {
        UIBezierPath *ring = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(2, 2, 26, 26)];
        ring.lineWidth = 2.6;
        [ring stroke];
        UIBezierPath *arrow = [UIBezierPath bezierPath];
        [arrow moveToPoint:CGPointMake(12.5, 7)];
        [arrow addLineToPoint:CGPointMake(17.5, 7)];
        [arrow addLineToPoint:CGPointMake(17.5, 15)];
        [arrow addLineToPoint:CGPointMake(22, 15)];
        [arrow addLineToPoint:CGPointMake(15, 23)];
        [arrow addLineToPoint:CGPointMake(8, 15)];
        [arrow addLineToPoint:CGPointMake(12.5, 15)];
        [arrow closePath];
        [arrow fill];
    }];
}

@end
