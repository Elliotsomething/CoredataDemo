//
//  MOALocationManager.m
//  MOA
//
//  Created by luqizhou on 15/6/4.
//  Copyright (c) 2015年 moa. All rights reserved.
//

#import "MOALocationManager.h"
#import "MOALocationInstance.h"
#import "MOALocation.h"
#import <CoreLocation/CoreLocation.h>
#import <AMapSearchKit/AMapSearchAPI.h>

#define MAX_CACHE_TIME  60
#define MAX_CACHE_COUNT MAX_CACHE_TIME

@interface MOALocationManager () <CLLocationManagerDelegate, AMapSearchDelegate> {
    NSHashTable *instanceArray;
    BOOL updatingLocation;
    
    MOALocation *lastLocation;
    NSDate *beginLocationDate;
    NSInteger accuracyInvalidCount;
    NSInteger cacheDeterminedCount;
}
@end

static Method originalDidUpdateLocationsMethod = NULL;
static Method newDidUpdateLocationsMethod = NULL;
static CLLocation *lastHookLocation = nil;
static CLLocation *testLocation = nil;
static BOOL testLocationFlag = NO;
static BOOL isJailbroken = NO;

@interface MOALocationInstance ()

- (instancetype)initWithDelegate:(id<MOALocationDelegate>)delegate;

@end


@implementation MOALocationManager

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        isJailbroken = [MobClick isJailbroken];
        testLocation = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(22.22, 33.33) altitude:10.0 horizontalAccuracy:10.0 verticalAccuracy:10.0 course:10.0 speed:10.0 timestamp:[NSDate date]];
    });
    
    return;
    
//    NSString *name = @"GPSTravellerTweak.dylib";
//    NSString *path = @"/Library/MobileSubstrate/DynamicLibraries/";
//    BOOL isExisted = [[NSFileManager defaultManager] fileExistsAtPath:[path stringByAppendingPathComponent:name]];
//    NSLog(@"%@ isExisted=%d", name, isExisted);
    
    //    NSData *data = [NSData dataWithContentsOfFile:@"/Users/ctinus/Desktop/111"];
    //    NSString *s = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    //    NSArray *a = [s componentsSeparatedByString:@" "];
    //    for(NSString *s in a) {
    //        printf("%s\r\n", s.UTF8String);
    //    }
    
        //FakeGPS
//    NSArray *allClass = @[@"FixedLocationData",
//                          @"LocationParser",
//                          @"LocationManager_Delegate",
//                          @"MyLocationManagerDelegate",
//                          ];
    
    //OTRLocation.dylib
    NSArray *allClass = @[@"OTRAppObject",
                          @"OTRAppService",
                          @"OTRHook",
                          ];
    
    for(NSString *className in allClass) {
        Class cls = NSClassFromString(className);
        if(cls) {
            unsigned int propertyCount = 0, ivarCount = 0, methodCount = 0;
            objc_property_t *properties = class_copyPropertyList(cls, &propertyCount);
            Ivar *ivars = class_copyIvarList(cls, &ivarCount);
            Method *methods = class_copyMethodList(cls, &methodCount);
            printf("%s property(%d) ivar(%d) method(%d)\n", className.UTF8String, propertyCount, ivarCount, methodCount);
            
            if(propertyCount > 0) {
                for(int i = 0; i < propertyCount; i++) {
                    printf("\t%d、property %s\n", i, property_getName(properties[i]));
                }
            }
            
            if(ivarCount > 0) {
                for(int i = 0; i < ivarCount; i++) {
                    printf("\t%d、ivar %s\n", i, ivar_getName(ivars[i]));
                }
            }
            
            if(methodCount > 0) {
                for(int i = 0; i < methodCount; i++) {
                    printf("\t%d、method %s\n", i, [NSStringFromSelector(method_getName(methods[i])) UTF8String]);
                }
            }
        }else {
            printf("%s not existed\n", className.UTF8String);
        }
    }
    
    NSLog(@"%s", __func__);
}

+ (MOALocationManager *)defaulManager
{
    static MOALocationManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[MOALocationManager alloc] init];
    });
    
    return manager;
}

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        _locationManager.distanceFilter = kCLDistanceFilterNone;
        
        _cacheLocations = [NSMutableArray arrayWithCapacity:MAX_CACHE_COUNT];
        instanceArray = [[NSHashTable alloc] initWithOptions:NSPointerFunctionsWeakMemory capacity:100];
        updatingLocation = NO;
        _fakeDetected = NO;
    
        _maxAccuracyInvalid = 3;
        _timeout = 3.0;
        
        //fake gps detect
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
        if(isJailbroken && [_locationManager.delegate isKindOfClass:[self class]] == NO) {
            [self initHookDidUpdateLocations];
        }
        [self testLocation];
        
#if(TARGET_IPHONE_SIMULATOR)
        _maxCacheDetermined = 0;    //模拟器无需检查缓存值
#endif
    }
    return self;
}

- (AMapSearchAPI *)amapSearch
{
    if(_amapSearch == nil)
    {
        _amapSearch = [[AMapSearchAPI alloc] initWithSearchKey:[MAMapServices sharedServices].apiKey Delegate:self];
    }
    
    return _amapSearch;
}

- (MOALocationInstance *)getInstanceWithDelegate:(id<MOALocationDelegate>)delegate
{
    NSAssert(delegate, nil);
    MOALocationInstance *instance = [[MOALocationInstance alloc] initWithDelegate:delegate];
    instance.locationManager = self;
    [instanceArray addObject:instance];
    [instance addObserver:self forKeyPath:@"updatingLocation" options:NSKeyValueObservingOptionNew context:nil];
    return instance;
}

- (void)revokeInstance:(MOALocationInstance *)instance
{
    NSAssert(instance.locationManager == self, nil);
    if(instance.locationManager)
    {
        instance.updatingLocation = NO;
        instance.locationManager = nil;
        [instance removeObserver:self forKeyPath:@"updatingLocation" context:nil];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if([keyPath isEqualToString:@"updatingLocation"])
    {
        NSNumber *newValue = change[@"new"];
        
        for(MOALocationInstance *instance in instanceArray)
        {
            if(instance.updatingLocation)
            {
                if([newValue boolValue])
                {
                    [self requestUpdatingLocation:instance];
                }
                return;
            }
        }
        
        if(updatingLocation)
        {
            [self stopUpdatingLocation];
        }
    }
    
}
#pragma - mark fake gps detect

+ (BOOL)isCoordinateEqual:(CLLocationCoordinate2D)val1 andOther:(CLLocationCoordinate2D)val2
{
    if(fabs(val1.latitude-val2.latitude) > 0.00001
       || fabs(val1.longitude-val2.longitude) > 0.00001) {
        return NO;
    }
    return YES;
}

- (void)testLocation
{
    if(isJailbroken) {
        testLocationFlag = YES;
        if([_locationManager.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
            [_locationManager.delegate locationManager:_locationManager didUpdateLocations:@[testLocation]];
        }else if([_locationManager.delegate respondsToSelector:@selector(locationManager:didUpdateToLocation:fromLocation:)]) {
            [_locationManager.delegate locationManager:_locationManager didUpdateToLocation:testLocation fromLocation:testLocation];
        }else {
            testLocationFlag = NO;
            _fakeDetected = YES;
            NSLogToFile(@"Warn: fake GPS, detected by test location no response to didUpdateLocations");
        }
    }
}

- (void)hookLocationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    if(originalDidUpdateLocationsMethod && newDidUpdateLocationsMethod) {
        lastHookLocation = locations.firstObject;
        method_exchangeImplementations(newDidUpdateLocationsMethod, originalDidUpdateLocationsMethod);
        [self locationManager:manager didUpdateLocations:locations];
        method_exchangeImplementations(originalDidUpdateLocationsMethod, newDidUpdateLocationsMethod);
    }else {
        lastHookLocation = nil;
    }
}

- (void)initHookDidUpdateLocations
{
    if(isJailbroken) {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            originalDidUpdateLocationsMethod = class_getInstanceMethod([_locationManager.delegate class], @selector(locationManager:didUpdateLocations:));
            newDidUpdateLocationsMethod = class_getInstanceMethod([self class], @selector(hookLocationManager:didUpdateLocations:));
            if(originalDidUpdateLocationsMethod && newDidUpdateLocationsMethod) {
                method_exchangeImplementations(originalDidUpdateLocationsMethod, newDidUpdateLocationsMethod);
            }
        });
    }
}

#pragma mark - apis

- (void)checkLocationAuthorization
{
    if(ISIOS8)
    {
        if([CLLocationManager authorizationStatus] == kCLAuthorizationStatusNotDetermined)
        {
            if([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)])
            {
                [self.locationManager performSelector:@selector(requestWhenInUseAuthorization)];
            }
        }
    }
}

- (void)requestUpdatingLocation:(MOALocationInstance *)instance
{
    LocationLog(@"Info: requestUpdatingLocation (%s)", object_getClassName(instance.delegate));
    
    BOOL directCallback = updatingLocation;
    MOALocation *lastValidLocation = self.cacheLocations.lastObject;
    
    if(updatingLocation == NO)
    {
        [self startUpdatingLocation];
    }
    
    NSTimeInterval t = [NSDate date].timeIntervalSinceReferenceDate - lastValidLocation.location.timestamp.timeIntervalSinceReferenceDate;
    
    if(lastValidLocation
       && (directCallback || (t >= 0 && t <= MAX_CACHE_TIME)))
    {
        weak(instance);
        weak(self);
        MOALocation *location = lastValidLocation;
        dispatch_async(dispatch_get_main_queue(), ^{
            if(weakinstance.updatingLocation && location == weakself.cacheLocations.lastObject)
            {
                if([((NSObject *)weakinstance) respondsToSelector:@selector(locationInstance:didUpdateLocation:)])
                {
                    LocationLog(@"Info: cache didUpdateLocation (%s)", object_getClassName(weakinstance.delegate));
                    [(id<MOALocationDelegate>)weakinstance locationInstance:weakinstance didUpdateLocation:location];
                }
            }
        });
    }
}

- (void)startUpdatingLocation
{
    LocationLog(@"Info: startUpdatingLocation");
    
    [self resetInfo];
    
    updatingLocation = YES;
    [self checkLocationAuthorization];
    
    if([CLLocationManager authorizationStatus] != kCLAuthorizationStatusDenied)
    {
        [_locationManager startUpdatingLocation];
        
        weak(self);
        MOALocation *lastValidLocation = self.cacheLocations.lastObject;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((self.timeout+0.1) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if(updatingLocation && lastValidLocation == weakself.cacheLocations.lastObject)
            {
                LocationLog(@"Info: reset updating location");
                [weakself.locationManager stopUpdatingLocation];
                [weakself.locationManager startUpdatingLocation];
            }
        });
    }
    else
    {
        LocationLog(@"Info: kCLAuthorizationStatusDenied");
    }
}

- (void)stopUpdatingLocation
{
    LocationLog(@"Info: stopUpdatingLocation");
    
    [self resetInfo];
    
    updatingLocation = NO;
    [_locationManager stopUpdatingLocation];
}

- (void)resetInfo
{
    if(lastLocation && ([NSDate date].timeIntervalSinceReferenceDate - lastLocation.location.timestamp.timeIntervalSinceReferenceDate) < MAX_CACHE_TIME)
    {
    }
    else
    {
        lastLocation = nil;
    }
    
    beginLocationDate = [NSDate date];
    accuracyInvalidCount = 0;
    cacheDeterminedCount = 0;
}

#pragma mark - CLLocationManager delegate

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    BOOL isFakeLocation = NO;
    CLLocation *location = locations.firstObject;
    
    if(isJailbroken && testLocationFlag) {
        testLocationFlag = NO;
        if([MOALocationManager isCoordinateEqual:location.coordinate andOther:testLocation.coordinate] == NO) {
            NSLogToFile(@"Warn: fake GPS, detected by test location from(%0.6f,%0.6f) to(%0.6f,%0.6f)", location.coordinate.latitude, location.coordinate.longitude, testLocation.coordinate.latitude, testLocation.coordinate.longitude);
            _fakeDetected = YES;
        }else {
            if(_fakeDetected) {
                _fakeDetected = NO;
                NSLogToFile(@"Warn: fake GPS, detect has been remove");
            }
        }
        return;
    }
    
    if(lastHookLocation) {
        //第三库可能会稍微处理过经纬度可能会导致一些精度损失，为了避免误判不能使用直接等于
        if([MOALocationManager isCoordinateEqual:location.coordinate andOther:lastHookLocation.coordinate] == NO) {
            NSLogToFile(@"Warn: fake GPS, detected by hook didUpdateLocations(%@) from(%0.6f,%0.6f) to(%0.6f,%0.6f)", NSStringFromClass([manager.delegate class]), location.coordinate.latitude, location.coordinate.longitude, lastHookLocation.coordinate.latitude, lastHookLocation.coordinate.longitude);
            isFakeLocation = YES;
        }
    }
    
    if(isJailbroken && !(_fakeDetected == YES || isFakeLocation == YES)) {
        NSString *desc = location.description;
        if(desc) {
            NSRange flagRange1 = [desc rangeOfString:@"<"];
            NSRange flagRange2 = [desc rangeOfString:@">"];
            if(flagRange1.location != NSNotFound && flagRange2.location != NSNotFound
               && flagRange2.location > (flagRange1.location+flagRange1.length)) {
                NSRange valueRange = NSMakeRange(flagRange1.location+1, flagRange2.location-(flagRange1.location+1));
                if(valueRange.location+valueRange.length < desc.length) {
                    NSString *subStr = [desc substringWithRange:valueRange];
                    NSArray *components = [subStr componentsSeparatedByString:@","];
                    if(components.count == 2) {
                        CLLocationCoordinate2D coor1 = CLLocationCoordinate2DMake([components.firstObject doubleValue], [components.lastObject doubleValue]);
                        if([MOALocationManager isCoordinateEqual:coor1 andOther:location.coordinate] == NO) {
                            
                            NSLogToFile(@"Warn: fake GPS, detected by coordinate not match from(%0.6f,%0.6f) to(%@)", location.coordinate.latitude, location.coordinate.longitude, location.description);
                            isFakeLocation = YES;
                        }
                    }
                }
            }
        }
    }
    
    MOALocation *moaLocation = [[MOALocation alloc] initWithCLLocation:location];
    if(isJailbroken) {
        moaLocation.isFakeLocation = _fakeDetected? _fakeDetected: isFakeLocation;
    }else {
        moaLocation.isFakeLocation = NO;
    }
    
    LocationLog(@"Info: didUpdateLocations(wifi=%@ reachable=%zd time=%d fake=%d) (%@)", [EntrysOperateHelper getWifiBSSID], [CoredataManager net].netState, (int)[[NSDate date] timeIntervalSinceDate:moaLocation.location.timestamp], moaLocation.isFakeLocation, moaLocation);
    
    if([self validLocation:moaLocation] == NO)
    {
        return;
    }
    
    if(_cacheLocations.count >= MAX_CACHE_COUNT)
    {
        [_cacheLocations removeObjectAtIndex:0];
    }
    [_cacheLocations addObject:moaLocation];
    
    for(MOALocationInstance *instance in instanceArray)
    {
        if(instance.updatingLocation || instance.acceptLocationUpdate)
        {
            if([((NSObject *)instance) respondsToSelector:@selector(locationInstance:didUpdateLocation:)])
            {
                [(id<MOALocationDelegate>)instance locationInstance:instance didUpdateLocation:moaLocation];
            }
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    LocationLog(@"Warn: didFailWithError (%@)", error);
    
    updatingLocation = NO;
    
    for(MOALocationInstance *instance in instanceArray)
    {
        if(instance.updatingLocation)
        {
            instance.updatingLocation = NO;
            if([((NSObject *)instance) respondsToSelector:@selector(locationInstance:didFailWithError:)])
            {
                [(id<MOALocationDelegate>)instance locationInstance:instance didFailWithError:error];
            }
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    LocationLog(@"Info: didChangeAuthorizationStatus (%d)", status);
    if(status != kCLAuthorizationStatusDenied)
    {
        for(MOALocationInstance *instance in instanceArray)
        {
            if(instance.updatingLocation)
            {
                [_locationManager startUpdatingLocation];
                return;
            }
        }
    }
}

#pragma mark - reverse geo

- (void)onReGeocodeSearchDone:(AMapReGeocodeSearchRequest *)request response:(AMapReGeocodeSearchResponse *)response
{
    NSAssert([NSThread isMainThread], nil);
    MOALocation *location = objc_getAssociatedObject(request, kReGeoRequestLocation);
    MOACallback callback = objc_getAssociatedObject(request, kReGeoRequestCallback);
    
    LocationLog(@"Info: onReGeocodeSearchDone (%@)", location);
    
    id result = MOAErrorMakeOther(@"kReverseGeocodeAddressFail", nil, 0);
    if(response.regeocode.formattedAddress.length > 0
       && ![response.regeocode.formattedAddress isEqualToString:@"null"])
    {
        result = @{@"address":response.regeocode.formattedAddress,
                   @"component":response.regeocode.addressComponent};
    }
    
    if(location && response.regeocode.formattedAddress)
    {
        location.address = response.regeocode.formattedAddress;
        location.addressComponent = response.regeocode.addressComponent;
    }
    
    if(callback)
    {
        callback(result);
    }
    
    objc_setAssociatedObject(request, kReGeoRequestLocation, nil, OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(request, kReGeoRequestCallback, nil, OBJC_ASSOCIATION_RETAIN);
}

- (void)search:(id)searchRequest error:(NSString*)errInfo
{
    NSAssert([NSThread isMainThread], nil);
    id result = MOAErrorMakeOther(@"kReverseGeocodeAddressFail", errInfo, 0);
    
    LocationLog(@"Warn: onReGeocodeSearchFaild");
    
    MOACallback callback = objc_getAssociatedObject(searchRequest, kReGeoRequestCallback);
    if(callback)
    {
        callback(result);
    }
    
    objc_setAssociatedObject(searchRequest, kReGeoRequestLocation, nil, OBJC_ASSOCIATION_RETAIN);
    objc_setAssociatedObject(searchRequest, kReGeoRequestCallback, nil, OBJC_ASSOCIATION_RETAIN);
}

#pragma - mark check location valid

- (BOOL)validLocation:(MOALocation *)location
{
    NSAssert(location, nil);
    
    if([[NSDate date] timeIntervalSinceDate:beginLocationDate] >= self.timeout)
    {
        if(lastLocation == nil)
        {
            lastLocation = location;
        }
        return YES;
    }
    
    if(lastLocation == nil)
    {
        lastLocation = location;
        LocationLog(@"Info: discard first value");
        return NO;
    }
    
    BOOL ret = YES;
    
    if(location.timeStampValid == NO)
    {
        LocationLog(@"Info: time stamp invalid");
        ret = NO;
    }
    
    if(location.accuracyValid == NO && accuracyInvalidCount++ < self.maxAccuracyInvalid)
    {
        LocationLog(@"Info: accuracy invalid(%ld)", (long)accuracyInvalidCount);
        ret = NO;
    }
    
    if([lastLocation isEqual:location] == YES && cacheDeterminedCount++ < self.maxCacheDetermined)
    {
        LocationLog(@"Info: cache invalid(%ld)", (long)cacheDeterminedCount);
        ret = NO;
    }
    
    return ret;
}

#pragma - mark UIApplicationDelegate

- (void)appWillEnterForeground
{
    [self testLocation];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self testLocation];
    });
}

@end

