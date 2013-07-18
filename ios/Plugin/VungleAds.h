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
#include "CoronaLua.h"
#import "vunglepub.h"

// ----------------------------------------------------------------------------

CORONA_EXPORT int luaopen_CoronaProvider_ads_vungle( lua_State *L );

// ----------------------------------------------------------------------------

@class NSString;
@protocol CoronaRuntime;

@class VungleDelegate;

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

	public:
		Vungle( id<CoronaRuntime> runtime );
		virtual ~Vungle();

	public:
        bool Init(lua_State* L, const char* appId, int listenerIndex);
		bool Show(bool animated, bool showClose);
		bool ShowIncentivized(bool animated, bool showClose, const std::string& userTag = "");

	public:
		void DispatchEvent(bool isError, const char* eventName, NSDictionary* opts = nil) const;

	protected:
		id<CoronaRuntime> fRuntime;
		NSString *fAppId;
		CoronaLuaRef fListener;
        UIViewController* _controller;
		VungleDelegate* _delegate;
};

// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------

@interface VungleDelegate : NSObject <VGVunglePubDelegate> {
	Corona::Vungle* vungle;
}
@property Corona::Vungle* vungle;
-(void)vungleMoviePlayed:(VGPlayData*)playData;
-(void)vungleViewDidDisappear:(UIViewController*)viewController;
-(void)vungleViewWillAppear:(UIViewController*)viewController;
@end

#endif // _IOSMyAdsProvider_H__
