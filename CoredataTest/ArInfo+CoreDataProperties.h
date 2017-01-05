//
//  ArInfo+CoreDataProperties.h
//  CoredataTest
//
//  Created by yanghao on 15/12/30.
//  Copyright © 2015年 justlike. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "ArInfo.h"

NS_ASSUME_NONNULL_BEGIN

@interface ArInfo (CoreDataProperties)

@property (nullable, nonatomic, retain) NSNumber *myid;
@property (nullable, nonatomic, retain) NSString *myname;

@end

NS_ASSUME_NONNULL_END
