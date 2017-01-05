//
//  MOALocationManager.h
//  MOA
//
//  Created by luqizhou on 15/6/4.
//  Copyright (c) 2015年 moa. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MOALocationInstance.h"
#import <CoreLocation/CoreLocation.h>
#import <AMapSearchKit/AMapSearchAPI.h>

#define LocationLog NSLogToFile

@interface MOALocationManager : NSObject

@property(nonatomic, retain) CLLocationManager *locationManager;
@property(nonatomic, retain) AMapSearchAPI *amapSearch;
@property(nonatomic, retain) NSMutableArray *cacheLocations;

@property (nonatomic, assign) NSInteger maxAccuracyInvalid; //精度无效次数达到这个最大值后，则不在判断精度，直接回调
@property (nonatomic, assign) NSInteger maxCacheDetermined; //缓存值判断的最大次数，超出后，不在判断是否缓存，直接回调
@property (nonatomic, assign) NSTimeInterval timeout;       //定位超时时间，超出该时间后，不在做任何精度或者缓存值的判断

@property (nonatomic, readonly) BOOL fakeDetected;

+ (BOOL)isCoordinateEqual:(CLLocationCoordinate2D)val1 andOther:(CLLocationCoordinate2D)val2;

+ (MOALocationManager *)defaulManager;
- (MOALocationInstance *)getInstanceWithDelegate:(id<MOALocationDelegate>)delegate;
- (void)revokeInstance:(MOALocationInstance *)instance;  //内部使用

- (void)checkLocationAuthorization;

@end


