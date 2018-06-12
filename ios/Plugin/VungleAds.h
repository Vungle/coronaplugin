//
//  IOSMyAdsProvider.h
//  AdsProvider Plugin
//
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#ifndef _IOSMyAdsProvider_H__
#define _IOSMyAdsProvider_H__

#include <string>
#import <UIKit/UIKit.h>
#import "VungleSDK.h"
#import "VungleSDKCreativeTracking.h"
#import "VungleSDKHeaderBidding.h"
#include "CoronaLua.h"

// ----------------------------------------------------------------------------

CORONA_EXPORT int luaopen_plugin_vungle( lua_State *L );

// ----------------------------------------------------------------------------

@class NSString;
@protocol CoronaRuntime;

@class VungleDelegate;
@class VungleCoronaLogger;
@class VungleCreativeTracking;
@class VungleHeaderBidding;

namespace Corona
{

// ----------------------------------------------------------------------------

class Vungle
{
	public:
		static const char kName[];

	public:
		static int Open( lua_State *L );

	protected:
		static int Finalizer( lua_State *L );

	protected:
        static int versionString(lua_State* L);
        static int Init(lua_State* L);
		static int Show(lua_State* L);
        static int Load(lua_State* L);
        static int updateConsentStatus(lua_State* L);
        static int getConsentStatus(lua_State* L);
        static int getConsentVersion(lua_State* L);
        static int closeAd(lua_State* L);
		static int adIsAvailable(lua_State* L);
        static int clearCache(lua_State* L);
        static int clearSleep(lua_State* L);
        static int setSoundEnabled(lua_State* L);
        static int enableLogging(lua_State* L);
        static int subscribeHB(lua_State* L);

	public:
		Vungle( id<CoronaRuntime> runtime );
		virtual ~Vungle();

	public:
        bool Init(lua_State* L, NSString* appId, NSMutableArray* placements, int listenerIndex);
        bool Show(NSDictionary* options, NSString* placementID);
        void subscribeHB();

	public:
		void DispatchEvent(bool isError, const char* eventName, NSDictionary* opts = nil) const;

	protected:
		id<CoronaRuntime> fRuntime;
		NSString *fAppId;
		CoronaLuaRef fListener;
        UIViewController* _controller;
		VungleDelegate* _delegate;
        VungleCreativeTracking* _creativeTracking;
        VungleHeaderBidding* _headerBidding;
        VungleCoronaLogger* _logger;
};

// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

@interface VungleDelegate : NSObject <VungleSDKDelegate> {
	Corona::Vungle* vungle;
}
@property Corona::Vungle* vungle;
- (void)vungleWillShowAdForPlacementID:(nullable NSString *)placementID;
- (void)vungleDidCloseAdWithViewInfo:(nonnull VungleViewInfo *)info placementID:(nonnull NSString *)placementID;
- (void)vungleAdPlayabilityUpdate:(BOOL)isAdPlayable placementID:(nullable NSString *)placementID;
- (void)vungleSDKDidInitialize;
@end

@interface VungleCoronaLogger : NSObject <VungleSDKLogger> {
    Corona::Vungle* vungle;
}
@property Corona::Vungle* vungle;
- (void)vungleSDKLog:(NSString *)message;
@end

@interface VungleCreativeTracking : NSObject <VungleSDKCreativeTracking> {
    Corona::Vungle* vungle;
}
@property Corona::Vungle* vungle;
- (void)vungleCreative:(nullable NSString *)creativeID readyForPlacement:(nullable NSString *)placementID;
@end

@interface VungleHeaderBidding : NSObject <VungleSDKHeaderBidding> {
    Corona::Vungle* vungle;
}
@property Corona::Vungle* vungle;
- (void)placementPrepared:(NSString *)placement withBidToken:(NSString *)bidToken;
 @end

#endif // _IOSMyAdsProvider_H__
