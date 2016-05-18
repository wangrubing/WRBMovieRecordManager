//
//  SMBVideoRecordManager.h
//  CollectFaces
//
//  Created by 王茹冰 on 16/4/29.
//  Copyright © 2016年 王茹冰. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface WRBMovieRecordManager : NSObject

+(instancetype)sharedInstance;

- (void)setCameraInView:(UIView *)view;

- (void)removeCameraInView:(UIView *)view;

- (void)startCamera;

- (void)stopCamera;

- (void)recordMovieWithTimeInterval:(NSTimeInterval)ti completion:(void (^)(NSData *movieData))completion;

- (void)startScanAnimationInView:(UIView *)view;

@end
