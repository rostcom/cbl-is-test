//
//  Contact.h
//  cbl-is-test
//
//  Created by Rostyslav on 7/9/14.
//  Copyright (c) 2014 Rozdoum. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Info;

@interface Contact : NSManagedObject

@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * phone;
@property (nonatomic, retain) NSData * photo;
@property (nonatomic, retain) NSNumber * published;
@property (nonatomic, retain) Info *info;

@end
