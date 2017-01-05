//
//  testTime.m
//  CoredataTest
//
//  Created by yanghao on 16/2/17.
//  Copyright © 2016年 justlike. All rights reserved.
//

#import "testTime.h"
#import <objc/runtime.h>

typedef void(^callback)(id result);

//默认情况下，系统自带的IMP被定义为无参数无返回值的函数
/*重新定义IMP，有参数，带返回值和不带返回值*/
typedef void (*_VIMP) (id, SEL, ...);
typedef id(*_IMP) (id, SEL, ...);

static size_t const iterations = 100;
extern uint64_t dispatch_benchmark(size_t count, void (^block)(void));

@implementation testTime


void invokeMethodNoRetForEffctive(id target, SEL action, ...){
	
	//目标方法
	Method m1 = class_getInstanceMethod([target class], action);
	
	int numberOfArguments = method_getNumberOfArguments(m1);
	
	NSMutableArray *arr = [[NSMutableArray alloc] init];
	va_list params;  //定义一个指向个数可变的参数列表指针；
	id argument;
	//使参数列表指针arg_ptr指向函数参数列表中的第一个可选参数，说明：argN是位于第一个可选参数之前的固定参数，（或者说，最后一个 固定参数；…之前的一个参数），函数参数列表中参数在内存中的顺序与函数声明时的顺序是一致的。如果有一va函数的声明是void va_test(char a, char b, char c, …)，则它的固定参数依次是a,b,c，最后一个固定参数argN为c，因此就是va_start(arg_ptr, c)。
	va_start(params, action);
	while ((argument = va_arg(params, id))) {//返回参数列表中指针arg_ptr所指的参数，返回类型为type，并使指针arg_ptr指向参数列表中下一个参数
		[arr addObject:argument];
	}
	va_end(params);//释放列表指针
	
	//获取目标方法的指针  改方法无返回值
	_VIMP someMethod = (_VIMP)method_getImplementation(m1);
//	extern uint64_t dispatch_benchmark(size_t count, void (^block)(void));
	
	uint64_t t_1 = dispatch_benchmark(iterations, ^{
		
		switch (numberOfArguments) {
			case 2:
				someMethod(target,action);
				break;
			case 3:
				someMethod(target,action,arr[0]);
				break;
			case 4:
				someMethod(target,action,arr[0],arr[1]);
				break;
			case 5:
				someMethod(target,action,arr[0],arr[1],arr[2]);
				break;
			case 6:
				someMethod(target,action,arr[0],arr[1],arr[2],arr[3]);
				break;
			case 7:
				someMethod(target,action,arr[0],arr[1],arr[2],arr[3],arr[4]);
				break;
			default:
				break;
		}
		
	});
	NSLog(@"该方法总共耗时：--》 %llu ns",t_1);
	
//	invokeMethodHasRetForEffctive(yh_self, name, 'q', 111, nil);
	
}

void invokeMethodHasRetForEffctive(id target, SEL action, ...){
	
	//目标方法
	Method m1 = class_getInstanceMethod([target class], action);
	
	int numberOfArguments = method_getNumberOfArguments(m1);
	
	NSMutableArray *arr = [[NSMutableArray alloc] init];
	va_list params;  //定义一个指向个数可变的参数列表指针；
	id argument;
	va_start(params, action);
	//返回参数列表中指针arg_ptr所指的参数，返回类型为type(type有很多是不支持的，比如char，bool)，并使指针arg_ptr指向参数列表中下一个参数
	while ((argument = va_arg(params, id))) {
		[arr addObject:argument];
	}
	va_end(params);//释放列表指针
	
	//获取目标方法的指针  改方法无返回值
	_IMP someMethod = (_IMP)method_getImplementation(m1);
	
	
	uint64_t t_1 = dispatch_benchmark(iterations, ^{
		
		switch (numberOfArguments) {
			case 2:
				someMethod(target,action);
				break;
			case 3:
				someMethod(target,action,arr[0]);
				break;
			case 4:
				someMethod(target,action,arr[0],arr[1]);
				break;
			case 5:
				someMethod(target,action,arr[0],arr[1],arr[2]);
				break;
			case 6:
				someMethod(target,action,arr[0],arr[1],arr[2],arr[3]);
				break;
			case 7:
				someMethod(target,action,arr[0],arr[1],arr[2],arr[3],arr[4]);
				break;
			default:
				break;
		}
		
	});
	NSLog(@"该方法总共耗时：--》 %llu ns",t_1);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
	getMethodArgType(target, @selector(todoSomething:with:), 111, YES);
#pragma clang diagnostic pop
	
}

void getMethodArgType(id target, SEL action, ...){
	
	NSMutableArray *argList = [[NSMutableArray alloc] init];
	/*如果用va_arg(ap, type)这个宏作可变参数获取的话，有很多类型是不支持的，比如char，bool等*/
	/*用NSNSInvocation做参数获取，支持所有参数类型*/
	
	NSMethodSignature * methodSignature  = [[target class] instanceMethodSignatureForSelector:action];
	//通过签名初始化
//	NSInvocation * invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
	va_list params;  //定义一个指向个数可变的参数列表指针；
	va_start(params, action);
	for (int i=2; i<[methodSignature numberOfArguments]; i++) {
		
//		const char *argumentType = method_copyArgumentType(m1, i);
		const char *argumentType = [methodSignature getArgumentTypeAtIndex:i];
		switch(argumentType[0] == 'r' ? argumentType[1] : argumentType[0]) {
				
				#define JP_FWD_ARG_CASE(_typeChar, _type) \
				case _typeChar: {   \
				_type arg;  \
				arg = va_arg(params, _type);    \
				[argList addObject:@(arg)]; \
				break;  \
				}
				JP_FWD_ARG_CASE('c', int)
				JP_FWD_ARG_CASE('C', unsigned int)
				JP_FWD_ARG_CASE('s', int)
				JP_FWD_ARG_CASE('S', unsigned int)
				JP_FWD_ARG_CASE('i', int)
				JP_FWD_ARG_CASE('I', unsigned int)
				JP_FWD_ARG_CASE('l', long)
				JP_FWD_ARG_CASE('L', unsigned long)
				JP_FWD_ARG_CASE('q', long long)
				JP_FWD_ARG_CASE('Q', unsigned long long)
				JP_FWD_ARG_CASE('f', double)
				JP_FWD_ARG_CASE('d', double)
				JP_FWD_ARG_CASE('B', int)
			default: {
				
				id argument;
				(argument = va_arg(params, id));
				[argList addObject:argument];

				break;
			}
		}
		
	}
	va_end(params);//释放列表指针
	
	//通过签名初始化
	NSInvocation * invocation = [NSInvocation invocationWithMethodSignature:methodSignature];
	[invocation setTarget:target];
	[invocation setSelector:action];
	for (int i=2; i<[methodSignature numberOfArguments]; i++) {
		const char *argumentType = [methodSignature getArgumentTypeAtIndex:i];
		switch(argumentType[0] == 'r' ? argumentType[1] : argumentType[0]) {
				
				#define YH_SET_ARG_CASE(_typeChar, _type, _typeValue) \
				case _typeChar: {   \
				_type argg = [argList[i-2] _typeValue];  \
				[invocation setArgument:&argg atIndex:i]; \
				break;  \
				}
				YH_SET_ARG_CASE('c', char, charValue)
				YH_SET_ARG_CASE('C', unsigned char, unsignedCharValue)
				YH_SET_ARG_CASE('s', short, shortValue)
				YH_SET_ARG_CASE('S', unsigned short, unsignedShortValue)
				YH_SET_ARG_CASE('i', int, intValue)
				YH_SET_ARG_CASE('I', unsigned int, unsignedIntValue)
				YH_SET_ARG_CASE('l', long, longValue)
				YH_SET_ARG_CASE('L', unsigned long, unsignedLongValue)
				YH_SET_ARG_CASE('q', long long, longLongValue)
				YH_SET_ARG_CASE('Q', unsigned long long, unsignedLongLongValue)
				YH_SET_ARG_CASE('f', float, floatValue)
				YH_SET_ARG_CASE('d', double, doubleValue)
				YH_SET_ARG_CASE('B', BOOL, boolValue)

			default: {
				
				id argument =argList[i-2];
				[invocation setArgument:&argument atIndex:i];
				break;
			}
		}

	}
	
	uint64_t t_1 = dispatch_benchmark(iterations, ^{
		[invocation invoke];
	});
	NSLog(@"该方法总共耗时：--》 %llu ns",t_1);
}



@end
