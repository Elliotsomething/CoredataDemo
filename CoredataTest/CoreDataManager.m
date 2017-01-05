//
//  CoreDataManager.m
//  CoredataTest
//
//  Created by Elliot on 15/12/8.
//  Copyright © 2017年 justlike. All rights reserved.
//

#import "CoreDataManager.h"


__weak static CoreDataManager *coreDataManager = nil;
@implementation CoreDataManager
@synthesize mainContext =_mainContext;
@synthesize dbContext = _dbContext;
@synthesize dealContext = _dealContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;


+ (void)setDefaultInstance:(CoreDataManager *)obj{
    coreDataManager = obj;
}
+ (instancetype)defaultInstance{
    return coreDataManager;
}

-(instancetype)init{
    self = [super init];
    if (self) {
        _name = @"YH";
        //		o = self;
        [CoreDataManager setDefaultInstance:self];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(contextDidChangeSave:) name:NSManagedObjectContextDidSaveNotification object:nil];
    }
    return self;
}


- (NSError *)updateDB
{
    //todo: #warning todo  添加数据库自定义升级
    NSManagedObjectContext *mainContext = self.mainContext;
    if (mainContext == nil) {
        return nil;
    }
    return nil;
}


#pragma mark - Core Data stack

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to thepersistent store coordinator for the application.
- (NSManagedObjectContext *)dealContext
{
    if (_dealContext !=nil) {
        return _dealContext;
    }
    if (_mainContext !=nil) {
        _dealContext = [[NSManagedObjectContext alloc]initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [_dealContext setParentContext:_mainContext];
    }
    return _dealContext;
}



- (NSManagedObjectContext *)mainContext
{
    if (_mainContext !=nil) {
        return _mainContext;
    }
    if (self.dbContext !=nil) {
        _mainContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_mainContext setParentContext:_dbContext];
    }
    return _mainContext;
}


- (NSManagedObjectContext *)dbContext
{
    if (_dbContext !=nil) {
        return _dbContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator !=nil) {
        _dbContext = [[NSManagedObjectContext alloc]initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [_dbContext setPersistentStoreCoordinator:coordinator];
    }
    return _dbContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application'smodel.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel !=nil) {
        return _managedObjectModel;
    }
    //这里一定要注意，这里的Model就是你刚才建立的数据模型的名字，一定要一致。否则会报错。
    NSURL *modelURL = [[NSBundle mainBundle]URLForResource:@"Model"withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc]initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and theapplication's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator !=nil) {
        return _persistentStoreCoordinator;
    }
    //这里的Model.sqlite，也应该与数据模型的名字保持一致。
    NSURL *storeURL = [[self applicationDocumentsDirectory]URLByAppendingPathComponent:@"Model.sqlite"];
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc]initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        NSLog(@"Unresolvederror %@, %@", error, [error userInfo]);
        abort();
    }
    
    return _persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL*)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask]lastObject];
}

#pragma mark - coredata op
- (NSManagedObjectContext *)getCurrentContextInThread{
    NSManagedObjectContext *context = nil;
    if ([NSThread isMainThread]) {
        context = self.mainContext;
    }else{
        context = self.dealContext;
    }
    return context;
}

//typedef void(^PerformBlock)(void);
+ (void)performBlock:(dispatch_block_t)block
           onContext:(NSManagedObjectContext *)context
               async:(BOOL)async
{
    if (async) {
        [context performBlock:block];
    }else{
        [context performBlockAndWait:block];
    }
}

//相当于保存数据的方法
+ (void)saveContextOnSelfThread:(NSManagedObjectContext *)context
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext =context;
    if (managedObjectContext !=nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            NSLog(@"Unresolvederror %@, %@", error, [error userInfo]);
            abort();
        }else{
            
        }
    }else{
        
    }
}
- (void)saveContext:(NSManagedObjectContext *)context async:(BOOL)async
{
    NSAssert(context, nil);
    //You need the performBlock to execute the save on the Context Queue
    //__weak typeof(self) weakSelf = self;
    [CoreDataManager performBlock:^{
        [CoreDataManager saveContextOnSelfThread:context];
    }
            onContext:context
                async:async];
}


- (void)contextDidChangeSave:(NSNotification *)notification{
    NSManagedObjectContext *saveContext = notification.object;
    NSManagedObjectContext *writeContext = self.dbContext;
    //dbContext 不需save
    if ([saveContext isEqual:writeContext]) {
        return;
    }
    //other db
    if (saveContext.persistentStoreCoordinator && ![writeContext.persistentStoreCoordinator isEqual:self.persistentStoreCoordinator]) {
        return;
    }
    //	if ([saveContext isEqual:self.mainContext]) {
    //		[self saveContext:saveContext.parentContext async:YES];
    //	}else{
    //		[self saveContext:saveContext.parentContext async:YES];
    //	}
    //	[self saveContext:saveContext async:YES];
    
    
    [saveContext performBlock:^{
        [CoreDataManager saveContextOnSelfThread:saveContext];
    }];
    
    
}




@end
