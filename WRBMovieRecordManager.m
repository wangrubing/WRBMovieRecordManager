//
//  SMBVideoRecordManager.m
//  CollectFaces
//
//  Created by 王茹冰 on 16/4/29.
//  Copyright © 2016年 王茹冰. All rights reserved.
//

#import "WRBMovieRecordManager.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
@interface WRBMovieRecordManager ()<AVCaptureFileOutputRecordingDelegate>

@property (nonatomic, strong) AVCaptureSession *captureSession;//负责输入和输出设备之间的数据传递
@property (nonatomic, strong) AVCaptureDeviceInput *captureDeviceInput;//负责从AVCaptureDevice获得输入数据
@property (nonatomic, strong) AVCaptureMovieFileOutput *movieFileOutput;//照片输出流
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *capturePreviewLayer;//相机拍摄预览图层
@property (nonatomic, strong) UIImageView *lineView;
@property (nonatomic, strong) UIImageView *rectView;
@property(nonatomic, copy) NSString *recordPath;//文件存储路径

@end

@implementation WRBMovieRecordManager
@synthesize lineView, rectView;

+(instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    static WRBMovieRecordManager *manager;
    dispatch_once(&onceToken, ^{
        manager = [[WRBMovieRecordManager alloc] init];
    });
    return manager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.captureSession = [[AVCaptureSession alloc] init];
        if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset640x480]) {//设置分辨率
            self.captureSession.sessionPreset = AVCaptureSessionPreset640x480;
        }
        self.captureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:[self getFrontCamera] error:nil];
        //添加一个音频输入设备
        AVCaptureDevice *audioCaptureDevice=[[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
        AVCaptureDeviceInput *audioCaptureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:audioCaptureDevice error:nil];
        
        self.movieFileOutput = [[AVCaptureMovieFileOutput alloc]init];
        
        if ([self.captureSession canAddInput:self.captureDeviceInput]) {
            [self.captureSession addInput:self.captureDeviceInput];
            [self.captureSession addInput:audioCaptureDeviceInput];
            AVCaptureConnection *captureConnection=[self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
            if ([captureConnection isVideoStabilizationSupported ]) {
                captureConnection.preferredVideoStabilizationMode=AVCaptureVideoStabilizationModeAuto;
            }
        }
        
        if ([self.captureSession canAddOutput:self.movieFileOutput]) {
            [self.captureSession addOutput:self.movieFileOutput];
        }
    }
    return self;
}

#pragma mark - 获取前置摄像头
- (AVCaptureDevice *)getFrontCamera
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *device = [devices lastObject];
    NSError *err = nil;
    BOOL lockAcquired = [device lockForConfiguration:&err];
    if (lockAcquired) {
        if ([device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
            [device setFocusMode:AVCaptureFocusModeAutoFocus];
            [device setFocusPointOfInterest:CGPointMake(100, 100)];
        }
        [device unlockForConfiguration];
    }
    return device;
}

#pragma mark - 设置预览图层,来显示照相机拍摄到的画面
- (void)setCameraInView:(UIView *)view
{
    if (self.capturePreviewLayer == nil) {
        self.capturePreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    }
    CALayer *viewLayer = [view layer];
    [viewLayer setMasksToBounds:YES];
    CGRect bounds = [view bounds];
    [self.capturePreviewLayer setFrame:bounds];
    [self.capturePreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [viewLayer insertSublayer:self.capturePreviewLayer below:[[viewLayer sublayers] objectAtIndex:0]];
}

- (void)removeCameraInView:(UIView *)view
{
    [self.capturePreviewLayer removeFromSuperlayer];
}

- (void)startScanAnimationInView:(UIView *)view
{
    rectView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 300, 400)];
    rectView.image = [UIImage imageNamed:@"扫描框"];
    CGPoint center = view.center;
    center.y -= 100;
    rectView.center = center;
    [view addSubview:rectView];
    
    CGRect rect = rectView.bounds;
    CGRect lineFrame = rect;
    lineFrame.size.height = 2;
    lineView = [[UIImageView alloc] initWithFrame:lineFrame];
    lineView.image = [UIImage imageNamed:@"扫描线"];
    [rectView addSubview:lineView];
    lineFrame.origin.y += rect.size.height-2;
    [UIView animateWithDuration:2 delay:0 options:UIViewAnimationOptionRepeat animations:^{
        lineView.frame = lineFrame;
    } completion:nil];
}

#pragma mark - 摄像头
/**
 *  摄像头开启
 */
- (void)startCamera
{
    [self.captureSession startRunning];
}

/**
 *  摄像头关闭
 */
- (void)stopCamera
{
    [self.captureSession stopRunning];
}

- (void)recordMovieWithTimeInterval:(NSTimeInterval)ti completion:(void (^)(NSData *movieData))completion
{
    AVCaptureConnection *captureConnection=[self.movieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    if (![self.movieFileOutput isRecording]) {
        captureConnection.videoOrientation=[self.capturePreviewLayer connection].videoOrientation;
        NSURL *fileUrl = [self getRecordUrl];
        [self.movieFileOutput startRecordingToOutputFileURL:fileUrl recordingDelegate:self];
    }
    [self performSelector:@selector(stopRecord:) withObject:completion afterDelay:ti];
}

- (void)stopRecord:(void (^)(NSData *movieData))completion
{
    [self.movieFileOutput stopRecording];
    if (completion) {
        NSData *data = [NSData dataWithContentsOfFile:self.recordPath];
        completion(data);
    }
}

-(NSURL *)getRecordUrl
{
    NSDate *now = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd_hh-mm-ss";
    NSString *fileName = [NSString stringWithFormat:@"%@.mov", [dateFormatter stringFromDate:now]];
    NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* documentsDirectory = [paths objectAtIndex: 0];
    NSString* recorderPath = [documentsDirectory stringByAppendingPathComponent: fileName];
    self.recordPath = recorderPath;
    return [NSURL fileURLWithPath:recorderPath];
}

#pragma mark - 视频输出代理
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{
//    NSLog(@"开始录制");
}
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error{
    //视频录入完成之后在后台将视频存储到相簿
    ALAssetsLibrary *assetsLibrary=[[ALAssetsLibrary alloc]init];
    [assetsLibrary writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error) {
            NSLog(@"保存视频到相簿过程中发生错误，错误信息：%@",error.localizedDescription);
        }
    }];
}

@end
