//
//  testTime.h
//  CoredataTest
//
//  Created by yanghao on 16/2/17.
//  Copyright © 2016年 justlike. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface testTime : NSObject
/*SEL 函数无返回值*/
void invokeMethodNoRetForEffctive(id target, SEL action, ...);
/*SEL 函数有返回值*/
void invokeMethodHasRetForEffctive(id target, SEL action, ...);


void getMethodArgType(id target, SEL action, ...);


@end
