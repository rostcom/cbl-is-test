//
//  CITAppDelegate.m
//  cbl-is-test
//
//  Created by Rostyslav on 7/3/14.
//  Copyright (c) 2014 Rozdoum. All rights reserved.
//

#import "CITAppDelegate.h"
#import "CBLIncrementalStore.h"
#import <CouchbaseLite/CouchbaseLite.h>

#define kSyncGateway @"http://10.10.7.118:4984/cbl-is-test"
// The changes from the original sample app are inside #if USE_COUCHBASE blocks
#define USE_COUCHBASE 1

@implementation CITAppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(mergeChanges:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:nil];
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}

- (void)mergeChanges:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSManagedObjectContext *savedContext = [notification object];
        NSManagedObjectContext *mainContext = self.managedObjectContext;
        BOOL isSelfSave = (savedContext == mainContext);
        BOOL isSamePersistentStore = (savedContext.persistentStoreCoordinator == mainContext.persistentStoreCoordinator);
        
        if (isSelfSave || !isSamePersistentStore) {
            return;
        }
        
        [mainContext mergeChangesFromContextDidSaveNotification:notification];
        
        //BUG FIX: When the notification is merged it only updates objects which are already registered in the context.
        //If the predicate for a NSFetchedResultsController matches an updated object but the object is not registered
        //in the FRC's context then the FRC will fail to include the updated object. The fix is to force all updated
        //objects to be refreshed in the context thus making them available to the FRC.
        //Note that we have to be very careful about which methods we call on the managed objects in the notifications userInfo.
        for (NSManagedObject *unsafeManagedObject in notification.userInfo[NSUpdatedObjectsKey]) {
            //Force the refresh of updated objects which may not have been registered in this context.
            NSManagedObject *manangedObject = [mainContext existingObjectWithID:unsafeManagedObject.objectID error:NULL];
            if (manangedObject != nil) {
                [mainContext refreshObject:manangedObject mergeChanges:YES];
            }
        }
    });
}

- (void)saveContext
{
    NSError *error = nil;

    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
             // Replace this implementation with code to handle the error appropriately.
             // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        } 
    }
}

#pragma mark - Core Data stack

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext {
	
    if (managedObjectContext != nil) {
        return managedObjectContext;
    }
	
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        managedObjectContext = [NSManagedObjectContext new];
        [managedObjectContext setPersistentStoreCoordinator: coordinator];
    }
    
#if USE_COUCHBASE
    CBLIncrementalStore *store = (CBLIncrementalStore*)[coordinator persistentStores][0];
    [store addObservingManagedObjectContext:managedObjectContext];
#endif

    
    return managedObjectContext;
}


/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created by merging all of the models found in the application bundle.
 */
- (NSManagedObjectModel *)managedObjectModel {
	
    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
    
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"cbl_is_test" withExtension:@"momd"];
    managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];

#if USE_COUCHBASE
    NSManagedObjectModel *model = [managedObjectModel mutableCopy];
    [CBLIncrementalStore updateManagedObjectModel:model];
    managedObjectModel = model;
#endif
    return managedObjectModel;
}


/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
	
    if (persistentStoreCoordinator != nil) {
        return persistentStoreCoordinator;
    }
    
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    
#if USE_COUCHBASE
    NSError *error = nil;
    NSString *databaseName = @"cbl-is-test";
	NSURL *storeUrl = [NSURL URLWithString:databaseName];
	
    CBLIncrementalStore *store;
    store = (CBLIncrementalStore*)[persistentStoreCoordinator addPersistentStoreWithType:[CBLIncrementalStore type]
                                                                           configuration:nil
                                                                                     URL:storeUrl options:nil error:&error];
    if (!store) {
		/*
		 Replace this implementation with code to handle the error appropriately.
		 
		 abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
		 
		 Typical reasons for an error here include:
		 * The persistent store is not accessible
		 * The schema for the persistent store is incompatible with current managed object model
		 Check the error message to determine what the actual problem was.
		 */
		NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
		abort();
    }
    

    NSURL *remoteDbURL = [NSURL URLWithString:kSyncGateway];
    [self startReplication:[store.database createPullReplication:remoteDbURL]];
    [self startReplication:[store.database createPushReplication:remoteDbURL]];
#else
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"cbl_is_test.sqlite"];
    
    NSError *error = nil;
    if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
#endif
    
    return persistentStoreCoordinator;
}

- (void)startReplication:(CBLReplication *)repl {
    repl.continuous = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(replicationProgress:)
                                                 name:kCBLReplicationChangeNotification object:repl];
    [repl start];
}

static BOOL sReplicationAlertShowing;

/**
 Observer method called when the push or pull replication's progress or status changes.
 */
- (void)replicationProgress:(NSNotification *)notification {
    CBLReplication *repl = notification.object;
    NSError* error = repl.lastError;
    NSLog(@"%@ replication: status = %d, progress = %u / %u, err = %@",
          (repl.pull ? @"Pull" : @"Push"), repl.status, repl.changesCount, repl.completedChangesCount,
          error.localizedDescription);
    
    if (error && !sReplicationAlertShowing) {
        NSString* msg = [NSString stringWithFormat: @"Sync failed with an error: %@", error.localizedDescription];
        UIAlertView* alert = [[UIAlertView alloc] initWithTitle: @"Sync Error"
                                                        message: msg
                                                       delegate: self
                                              cancelButtonTitle: @"Sorry"
                                              otherButtonTitles: nil];
        sReplicationAlertShowing = YES;
        [alert show];
    }
}

- (void)alertView:(UIAlertView *)alertView willDismissWithButtonIndex:(NSInteger)buttonIndex {
    sReplicationAlertShowing = NO;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

@end
