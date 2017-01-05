//
//  ViewController.m
//  CoredataTest
//
//  Created by yanghao on 15/12/7.
//  Copyright © 2015年 justlike. All rights reserved.
//

#import "ViewController.h"
#import "ArInfo.h"
#import "AppDelegate.h"
#import "obj.h"

#import "testTime.h"
typedef void(^callback)(id result);

static size_t const iterations = 1;

@interface ViewController (){
	ArInfo *arInfo111;
}

@end




@implementation ViewController
@synthesize context;
- (void)viewDidLoad {
	[super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
	
	
//	AppDelegate *delegate = (AppDelegate *)[[UIApplication sharedApplication]delegate];//这里需要引进自己项目的委托，是让全局managedObjectContext起作用。
	
	
	
	[[obj defaultInstance] updateDB];
	self.context = [obj defaultInstance].dealContext;
	
	
	
	extern uint64_t dispatch_benchmark(size_t count, void (^block)(void));
	
	
//	 uint64_t t_0 = dispatch_benchmark(iterations, ^{
//			NSError *error = nil;
//		 for (int i=0; i<100; i++) {
//			 
//			 ArInfo *arInfo = [NSEntityDescription insertNewObjectForEntityForName:@"ArInfo" inManagedObjectContext:context];
//			 arInfo.myid=@"123";
//			 arInfo.myname=@"object-c";
//			 if (![context save:&error]) {
//				 NSLog(@"%@",[error localizedDescription]);
//			 }
//		 }
//	 });
//
//		NSLog(@"------------------%llu",t_0);


	 uint64_t t_1 = dispatch_benchmark(iterations, ^{
		 [context performBlock:^{
			 
			 NSError *error = nil;
			 for (int i=0; i<10000; i++) {
				 //插入
				 ArInfo *arInfo = [NSEntityDescription insertNewObjectForEntityForName:@"ArInfo" inManagedObjectContext:context];
				 arInfo.myid=@(i);
				 arInfo.myname=@"object-c";
				 if (![context save:&error]) {
					 NSLog(@"%@",[error localizedDescription]);
				 }
			 }
		 }];
	 });
	NSLog(@"------------------   %llu",t_1);

//	NSLog(@"%@",[[obj defaultInstance] name]);
	
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event{
//	[self frc];
//	invokeMethodNoRetForEffctive(self, @selector(insertObj:lala:), @"qwerq",@"111111", nil);
//	invokeMethodHasRetForEffctive(self, @selector(frc:lala:), @"qwerq",@"111111", nil);
	
	callback call= ^(id result){
		NSLog(@"111--callback");
	};
	
//	
//	NSMutableArray *arr = [NSMutableArray array];
//	[arr addObject:call];
	getMethodArgType(self, @selector(frc:lala:), @"qwerq",call, nil);
	
}

//插入
- (void)insertObj:(NSString *)str lala:(int)obj{
	
	NSLog(@"%@ ---- %zd",str,obj);
	
	[context performBlock:^{
		
		NSError *error = nil;
		for (int i=0; i<10000; i++) {
			//插入
			ArInfo *arInfo = [NSEntityDescription insertNewObjectForEntityForName:@"ArInfo" inManagedObjectContext:context];
			arInfo.myid=@(i);
			arInfo.myname=@"object-c";
			if (![context save:&error]) {
				NSLog(@"%@",[error localizedDescription]);
			}
		}
	}];

}

//查
- (id)frc:(NSString *)str lala:(callback)str1{
	
	NSLog(@"%@ ---- %@",str,str1);
	str1(@"111");
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc]init];
	NSEntityDescription *entity = [NSEntityDescription entityForName:@"ArInfo" inManagedObjectContext:context];
	fetchRequest.predicate = [NSPredicate predicateWithFormat:@"(myid <= 2) "];
	[fetchRequest setEntity:entity];
	
	[context performBlock:^{
		NSError *error = nil;
		NSArray *fetchObject = [context executeFetchRequest:fetchRequest error:&error];
//		for (NSManagedObject *info in fetchObject) {
//			NSLog(@"id:%@",[info valueForKey:@"myid"]);
//			NSLog(@"name:%@",[info valueForKey:@"myname"]);
//			
////			NSLog(@"%@",[info objectID]);
//			
//		}
		
		arInfo111 = [fetchObject lastObject];
		arInfo111.myid = @(0);
		
		
		dispatch_async(dispatch_get_main_queue(), ^{
			NSManagedObject *objArInfo = [[[obj defaultInstance] getCurrentContextInThread] objectWithID:[arInfo111 objectID]];

			NSArray *fetchObject = [[[obj defaultInstance] getCurrentContextInThread] executeFetchRequest:fetchRequest error:nil];
//			for (NSManagedObject *info in fetchObject) {
//				NSLog(@"id:%@",[info valueForKey:@"myid"]);
//				NSLog(@"name:%@",[info valueForKey:@"myname"]);
//				
//			}
			
			[[[obj defaultInstance] getCurrentContextInThread] deleteObject:objArInfo];
			[[[obj defaultInstance] getCurrentContextInThread] save:nil];
			
			
	
			
		});
	}];
	
	
//	NSLog(@"touch me !");
	
	return @"";
	
}
- (void)deleteData
{
    NSFetchRequest * fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription * entity = [NSEntityDescription entityForName:@"ArInfo" inManagedObjectContext:context];
    [fetchRequest setEntity:entity];
 
	NSError * requestError = nil;
    NSArray * persons = [context executeFetchRequest:fetchRequest error:&requestError];

    if ([persons count] > 0) {
		
         ArInfo * lastPerson = [persons lastObject];
         // 删除数据
         [context deleteObject:lastPerson];
         if ([lastPerson isDeleted]) {
             NSLog(@"successfully deleted the last person");
             NSError * savingError = nil;
             if ([context save:&savingError]) {
                 NSLog(@"successfully saved the context");
			
             }else {
                 NSLog(@"failed to save the context error = %@", savingError);
				   }
		}else {
				
			NSLog(@"failed to delete the last person");
		}
	}else {
		NSLog(@"could not find any person entity in the context");
	}
 }

- (void)updateData
 {
      NSFetchRequest * fetchRequest = [[NSFetchRequest alloc] init];
      NSEntityDescription * entity = [NSEntityDescription entityForName:@"Person" inManagedObjectContext:context];
      [fetchRequest setEntity:entity];
 
      NSError * requestError = nil;
      NSArray * persons = [context executeFetchRequest:fetchRequest error:&requestError];
 
	     if ([persons count] > 0) {
		
		         ArInfo* lastPerson = [persons lastObject];
		         // 更新数据
		         lastPerson.myname = @"Hour";
		        lastPerson.myid = @21;
		
		         NSError * savingError = nil;
		        if ([context save:&savingError]) {
			             NSLog(@"successfully saved the context");
			
			         }else {
				             NSLog(@"failed to save the context error = %@", savingError);
				         }
		
		
		    }else {
			        NSLog(@"could not find any person entity in the context");
	    }
 }

- (void)todoSomething:(int )first with:(BOOL )second{
	NSLog(@"--------->>> ");
	
	NSLog(@"%zd ---- %zd",first,second);
	
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning];
	// Dispose of any resources that can be recreated.
}

@end
