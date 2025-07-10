//
//  PiPController.h
//  StikDebug
//
//  Created by Stossy11 on 10/07/2025.
//


#import <Foundation/Foundation.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PiPController : NSObject <AVPictureInPictureControllerDelegate>

@property (nonatomic, assign) BOOL isPiPActive;
@property (nonatomic, strong, nullable) UIView *customUIView;
@property (class, nonatomic, readonly) PiPController *shared;

- (void)setupPiPWithPlayerLayer:(AVPlayerLayer *)playerLayer;
- (void)startPiP;
- (void)stopPiP;
- (void)togglePiP;

@end

NS_ASSUME_NONNULL_END
