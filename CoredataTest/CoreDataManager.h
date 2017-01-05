//
//  CoreDataManager.h
//  CoredataTest
//
//  Created by Elliot on 2015/12/8.
//  Copyright © 2017年 justlike. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CoreDataManager : NSObject
@property (nonatomic, retain) NSString *name;
@property (readonly, strong, nonatomic) NSManagedObjectContext *dbContext;//root
//root context 的 子context, 其运行在 main queue, 主要供UI查询和部分数据修改写入
@property (readonly, strong, nonatomic) NSManagedObjectContext *mainContext;//root's child
@property (readonly, strong, nonatomic) NSManagedObjectContext *dealContext;//main's child

@property (readonly,strong,nonatomic)NSManagedObjectModel *managedObjectModel;
@property (readonly,strong,nonatomic)NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (NSError *)updateDB;
- (NSURL *)applicationDocumentsDirectory;
- (NSManagedObjectContext *)getCurrentContextInThread;

+ (instancetype)defaultInstance;
@end
