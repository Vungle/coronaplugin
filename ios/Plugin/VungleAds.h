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
#include "CoronaLua.h"

// ----------------------------------------------------------------------------

CORONA_EXPORT int luaopen_CoronaProvider_ads_vungle( lua_State *L );

// ----------------------------------------------------------------------------

@class NSString;
@protocol CoronaRuntime;

@class VungleDelegate;
@class VungleLogger;

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
        static int Init(lua_State* L);
		static int Show(lua_State* L);
		static int setBackButtonEnabled(lua_State* L);
		static int versionString(lua_State* L);
		static int Hide(lua_State* L);
		static int showCacheFiles(lua_State* L);
		static int adIsAvailable(lua_State* L);
        static int clearCache(lua_State* L);
        static int clearSleep(lua_State* L);
        static int setSoundEnabled(lua_State* L);
        static int enableLogging(lua_State* L);
        static int showEx(lua_State* L);

	public:
		Vungle( id<CoronaRuntime> runtime );
		virtual ~Vungle();

	public:
        bool Init(lua_State* L, const char* appId, int listenerIndex);
		bool Show(bool showClose, NSUInteger orientations);
        bool ShowEx(NSDictionary* options);
		bool ShowIncentivized(bool showClose, NSUInteger orientations, const std::string& userTag="");

	public:
		void DispatchEvent(bool isError, const char* eventName, NSDictionary* opts = nil) const;

	protected:
		id<CoronaRuntime> fRuntime;
		NSString *fAppId;
		CoronaLuaRef fListener;
        UIViewController* _controller;
		VungleDelegate* _delegate;
        VungleLogger* _logger;
};

// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

@interface VungleDelegate : NSObject <VungleSDKDelegate> {
	Corona::Vungle* vungle;
}
@property Corona::Vungle* vungle;
-(void)vungleSDKwillCloseAdWithViewInfo:(NSDictionary *)viewInfo willPresentProductSheet:(BOOL)willPresentProductSheet;
-(void)vungleSDKwillCloseProductSheet:(id)productSheet;
-(void)vungleSDKwillShowAd;
-(void)vungleSDKhasCachedAdAvailable;
-(void)vungleSDKAdPlayableChanged:(BOOL)isAdPlayable;
@end

@interface VungleLogger : NSObject <VungleSDKLogger> {
    Corona::Vungle* vungle;
}
@property Corona::Vungle* vungle;
- (void)vungleSDKLog:(NSString *)message;
@end


#endif // _IOSMyAdsProvider_H__
