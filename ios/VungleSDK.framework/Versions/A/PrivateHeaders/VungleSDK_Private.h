//
//  VungleSDK_Private.h
//  Vungle iOS SDK
//
//  Created by Rolando Abarca on 11/19/13.
//  Copyright (c) 2013 Vungle Inc. All rights reserved.
//

#import "VungleSDK.h"
#import "VungleNetworkQueue.h"
#import "VungleCacheManager.h"

// redefine some class names in order to avoid conflicts
#define FMDatabase VungleFMDatabase
#define FMStatement VungleFMStatement
#define FMDatabase VungleFMDatabase
#define FMDatabasePool VungleFMDatabasePool
#define FMDatabasePoolDelegate VungleFMDatabasePoolDelegate
#define FMDatabaseQueue VungleFMDatabaseQueue
#define FMResultSet VungleFMResultSet

@class FMDatabaseQueue;
@class VungleAdViewController;

@interface VungleSDK ()
@property (readonly) VungleCacheManager* cacheManager;
@property (readonly) NSString* apiEndpoint;
@property (readonly) FMDatabaseQueue* databaseQueue;
@property (assign)   VungleAdViewController* currentAdViewController;
@property (assign)   NSUInteger supportedOrientations;

/**
 * queues a new network request, according to the request's priority.
 */
- (void)sendRequest:(VungleNetworkRequest*)request;

/**
 * sends the "new" request (when the app is installed for the first time)
 */
- (void)sendNewRequest;

/**
 * sends the "end session" request, to track session length. This is sent when the app is sent to the background.
 */
- (void)sendSessionEndRequest;

/**
 * this request should be sent after finishing viewing an ad.
 * The dictionary should contain the following keys:
 *
 * . user [string] (if incentivized)
 * . incentivized [bool]
 * . campaign [string]
 * . app_id [string]
 * . url [string]
 * . adStartTime [int, utc]
 * . adDuration [int]
 * . plays [array]
 *   . object {startTime: double, videoLength: double, videoViewed: double}]
 * . ttDownload [int, utc]
 * . clickedThrough [array]
 *   . string (button action from js)
 * . id [string]
 */
- (void)sendReportAdRequest:(NSDictionary*)viewInfo delayPlay:(int)seconds;

/**
 * valid image names:
 *
 * . `muteButton-muted`
 * . `muteButton-normal`
 * . `closeButton`
 */
- (UIImage*)getInternalImageNamed:(NSString*)name;

/**
 * set a preference
 */
- (void)setPreferenceValue:(NSString*)value forKey:(NSString*)key;

/**
 * returns the value of a preference, or nil if it doesn't exist.
 */
- (NSString*)getPreferenceValueForKey:(NSString*)key;

/**
 * returns a bundle with a specific id. If there's one already in the cache, it will return
 * that, otherwise, it will fetch and recreate it from the db.
 * The bundle is returned autoreleased.
 */
- (VungleAdBundle*)getBundleWithId:(int64_t)dbId;

/**
 * returns a bundle with this campaign id. If there's one already in the cache, it will return
 * that, otherwise, it will fetch and recreate it from the db.
 * The bundle is returned autoreleased.
 */
- (VungleAdBundle*)getBundleWithCampaignId:(NSString*)campaign;


@end
