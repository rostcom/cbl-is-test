//
//  Note.h
//  cbl-is-test
//
//  Created by Rostyslav on 7/9/14.
//  Copyright (c) 2014 Rozdoum. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Contact;

@interface Note : NSManagedObject

@property (nonatomic, retain) NSDate * date;
@property (nonatomic, retain) NSString * text;
@property (nonatomic, retain) Contact *contact;

@end
