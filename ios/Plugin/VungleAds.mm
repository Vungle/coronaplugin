//
//  VungleAds.mm
//  AdsProvider Plugin
//
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#include "VungleAds.h"

#include "CoronaAssert.h"
#include "CoronaEvent.h"
#include "CoronaLibrary.h"
#include <string>

#import <Foundation/Foundation.h>
#import "CoronaRuntime.h"
#import "vunglepub.h"
#import "VGBytesAssetLoader.h"

static const char* kINCENTIVIZED_AD_TYPE = "incentivized";

// show() ad properties and defaults
static const char* kIS_ANIMATED_KEY = "isAnimated";
static const bool  kIS_ANIMATED_DEFAULT = true;
static const char* kIS_AUTO_ROTATION_KEY = "isAutoRotation";
static const bool  kIS_AUTO_ROTATION_DEFAULT = true;
static const bool  kIS_BACK_BUTTON_ENABLED_DEFAULT = false;
static const char* kIS_SOUND_ENABLED_KEY = "isSoundEnabled";
static const bool  kIS_SOUND_ENABLED_DEFAULT = true;
static const char* kIS_CLOSE_SHOWN_KEY = "isCloseShown";
static const bool  kIS_CLOSE_SHOWN_DEFAULT = true;
static const char* kUSERNAME_KEY = "username";

// events
static const NSString* kEVENT_TYPE_KEY = @"type";
static const NSString* kAD_START_EVENT_TYPE = @"adStart";
static const NSString* kAD_VIEW_EVENT_TYPE = @"adView";
static const NSString* kAD_END_EVENT_TYPE = @"adEnd";
static const NSString* kVERSION = @"1.1.1";

// ----------------------------------------------------------------------------

CORONA_EXPORT
int luaopen_CoronaProvider_ads_vungle( lua_State *L )
{
	return Corona::Vungle::Open( L );
}

@implementation VungleDelegate
@synthesize vungle;

- (void)vungleMoviePlayed:(VGPlayData*)playData {
	vungle->DispatchEvent(false, [kAD_VIEW_EVENT_TYPE UTF8String], @{
						  @"secondsWatched": [NSNumber numberWithFloat:playData.movieViewed],
						  @"totalAdSeconds": [NSNumber numberWithFloat:playData.movieTotal]});
}

- (void)vungleViewDidDisappear:(UIViewController*)viewController {
	vungle->DispatchEvent(false, [kAD_END_EVENT_TYPE UTF8String]);
}

- (void)vungleViewWillAppear:(UIViewController*)viewController {
	vungle->DispatchEvent(false, [kAD_START_EVENT_TYPE UTF8String]);
}
@end

// ----------------------------------------------------------------------------

namespace Corona
{

// ----------------------------------------------------------------------------

const char Vungle::kName[] = "CoronaProvider.ads.vungle";
static const char kProviderName[] = "vungle";
static const char kPublisherId[] = "com.vungle";


Vungle* vungleProvider = NULL;

int
Vungle::Open( lua_State *L )
{
	void *platformContext = CoronaLuaGetContext( L ); // lua_touserdata( L, lua_upvalueindex( 1 ) );
	id<CoronaRuntime> runtime = (id<CoronaRuntime>)platformContext;

	const char *name = lua_tostring( L, 1 ); CORONA_ASSERT( 0 == strcmp( name, kName ) );
	int result = CoronaLibraryProviderNew( L, "ads", name, kPublisherId );

	if ( result )
	{
		const luaL_Reg kFunctions[] =
		{
			{ "init", Vungle::Init },
			{ "hide", Vungle::Hide },
			{ "show", Vungle::Show },
			{ "getVersionString", Vungle::versionString },
			{ "isAdAvailable", Vungle::adIsAvailable },
			{ "showCacheFiles", Vungle::showCacheFiles },
			{ NULL, NULL }
		};
        
		CoronaLuaInitializeGCMetatable( L, kName, Finalizer );
        
		// Use 'provider' in closure for kFunctions
		if (!vungleProvider) {
			vungleProvider = new Vungle( runtime );
		}
		CoronaLuaPushUserdata( L, vungleProvider, kName );
		luaL_openlib( L, NULL, kFunctions, 1 );
        
		const char kTestAppId[] = "someDefaultAppId";
		lua_pushstring( L, kTestAppId );
		lua_setfield( L, -2, "testAppId" );
	}

	return result;
}

int
Vungle::Finalizer( lua_State *L )
{
	delete vungleProvider;
	vungleProvider = NULL;
	return 0;
}

// ads.init( providerName, appId [, listener] )
int Vungle::Init( lua_State *L )
{
    const char *appId = lua_tostring( L, 2 );
    
    bool success = vungleProvider->Init(L, appId, 3);
    lua_pushboolean( L, success );
    
    return 1;
}

int Vungle::Show(lua_State *L) {
	static int kADTYPE_IDX = 1;
	static int kPARAM_TABLE_INDEX = 2;
	int numArgs = lua_gettop(L);
	std::string adType("");
	if (numArgs >= kADTYPE_IDX) {
		adType = lua_tostring(L, kADTYPE_IDX);
	}
	bool isAnimated = kIS_ANIMATED_DEFAULT;
	bool isSoundEnabled = kIS_SOUND_ENABLED_DEFAULT;
	bool isAutoRotationEnabled = kIS_AUTO_ROTATION_DEFAULT;
	bool isCloseShown = kIS_CLOSE_SHOWN_DEFAULT;
	bool success = false;
	if ([VGVunglePub adIsAvailable]) {
		if (numArgs >= kPARAM_TABLE_INDEX && lua_istable(L, kPARAM_TABLE_INDEX)) {
			lua_getfield(L, kPARAM_TABLE_INDEX, kIS_ANIMATED_KEY);
			if (!lua_isnil(L, -1)) {
				isAnimated = lua_toboolean(L, -1);
				NSLog(@"isAnimated: %d", isAnimated);
			} else {
				NSLog(@"isAnimated: %d (default)", isAnimated);
			}
			lua_pop(L, 1);
			
			lua_getfield(L, kPARAM_TABLE_INDEX, kIS_AUTO_ROTATION_KEY);
			if (!lua_isnil(L, -1)) {
				isAutoRotationEnabled = lua_toboolean(L, -1);
				NSLog(@"isAutoRotationEnabled: %d", isAutoRotationEnabled);
			} else {
				NSLog(@"isAutoRotationEnabled: %d (default)", isAutoRotationEnabled);
			}
			lua_pop(L, 1);
			
			lua_getfield(L, kPARAM_TABLE_INDEX, kIS_SOUND_ENABLED_KEY);
			if (!lua_isnil(L, -1)) {
				isSoundEnabled = lua_toboolean(L, -1);
				NSLog(@"isSoundEnabled: %d", isSoundEnabled);
			} else {
				NSLog(@"isSoundEnabled: %d (default)", isSoundEnabled);
			}
			lua_pop(L, 1);
			
			lua_getfield(L, kPARAM_TABLE_INDEX, kIS_CLOSE_SHOWN_KEY);
			if (!lua_isnil(L, -1)) {
				isCloseShown = lua_toboolean(L, -1);
				NSLog(@"isCloseShown: %d", isCloseShown);
			} else {
				NSLog(@"isCloseShown: %d (default)", isCloseShown);
			}
			lua_pop(L, 1);
		}
		[VGVunglePub setSoundEnabled:isSoundEnabled];
		[VGVunglePub allowAutoRotate:isAutoRotationEnabled];
		
		// incentivized
		if (adType == kINCENTIVIZED_AD_TYPE) {
			std::string username("");
			if (numArgs >= kPARAM_TABLE_INDEX) {
				lua_getfield(L, kPARAM_TABLE_INDEX, kUSERNAME_KEY);
				if (!lua_isnil(L, -1)) {
					username = lua_tostring(L, -1);
				}
			}
			NSLog(@"username: '%s'", username.c_str());
			success = vungleProvider->ShowIncentivized(isAnimated, isCloseShown, username);
		} // interstitial
		else {
			success = vungleProvider->Show(isAnimated, isCloseShown);
		}
	} else {
		// no ad available
		vungleProvider->DispatchEvent(true, NULL, @{
									  kEVENT_TYPE_KEY: kAD_START_EVENT_TYPE,
									  [NSString stringWithUTF8String:CoronaEventResponseKey()]: @"Ad not available"});
	}
	lua_pushboolean(L, success);
	return 1;
}

// TODO remove
int Vungle::setBackButtonEnabled(lua_State* L) {
	lua_pushboolean(L, true);
	return 1;
}

int Vungle::versionString(lua_State* L) {
	NSString* version = [NSString stringWithFormat:@"%@ (%@)", kVERSION, [VGVunglePub versionString]];
	const char* cVersion = [version UTF8String];
	lua_pushstring(L, cVersion);
	return 1;
}

int Vungle::Hide(lua_State* L) {
	NSLog(@"hide() not implemented");
	lua_pushboolean(L, true);
	return 1;
}

int Vungle::showCacheFiles(lua_State* L) {
	[VGVunglePub showCacheFiles];
	lua_pushboolean(L, true);
	return 1;
}

int Vungle::adIsAvailable(lua_State* L) {
	lua_pushboolean(L, [VGVunglePub adIsAvailable]);
	return 1;
}

// ----------------------------------------------------------------------------

Vungle::Vungle( id<CoronaRuntime> runtime )
:	fRuntime( runtime ),
	fAppId( nil ),
	fListener( NULL )
{
	_controller = [runtime.appViewController retain];
	_delegate = [[VungleDelegate alloc] init];
}

Vungle::~Vungle()
{
	CoronaLuaDeleteRef( fRuntime.L, fListener );
    [_controller release];
	[_delegate release];
	[fAppId release];
}

bool Vungle::Init(lua_State *L, const char *appId, int listenerIndex)
{
    bool result = false;
    
    if ( appId )
    {
        NSString* str = [NSString stringWithUTF8String:appId];
        [VGVunglePub startWithPubAppID:str];
		[VGVunglePub setDelegate:_delegate];

		// set the new asset loader
		VGBytesAssetLoader* loader = [[VGBytesAssetLoader alloc] init];
		[VGVunglePub setAssetLoader:loader];
		[loader release];

		fListener = ( CoronaLuaIsListener( L, listenerIndex, "adsRequest" ) ? CoronaLuaNewRef( L, listenerIndex ) : NULL );
		_delegate.vungle = this;
        result = true;
    }
    
    return result;
}

bool Vungle::Show(bool animated, bool showClose) {
	if ([VGVunglePub adIsAvailable]) {
		[VGVunglePub playModalAd:_controller animated:animated showClose:showClose];
		return true;
	}
	return false;
}
	
bool Vungle::ShowIncentivized(bool animated, bool showClose, const std::string& userTag) {
	NSString* str = [NSString stringWithUTF8String:userTag.c_str()];
	if ([VGVunglePub adIsAvailable]) {
		[VGVunglePub playIncentivizedAd:_controller animated:animated showClose:showClose userTag:str];
		return true;
	}
	return false;
}
	
void
Vungle::DispatchEvent(bool isError, const char* eventName, NSDictionary* opts) const
{
	if ([NSThread currentThread] != [NSThread mainThread]) {
		NSLog(@"not on main thread!!!");
		return;
	}
	lua_State *L = fRuntime.L;

	CoronaLuaNewEvent( L, CoronaEventAdsRequestName() );

	if (eventName) {
		lua_pushstring( L, eventName );
		lua_setfield( L, -2, CoronaEventTypeKey() );
	}

	lua_pushstring( L, kProviderName );
	lua_setfield( L, -2, CoronaEventProviderKey() );

	lua_pushboolean( L, isError );
	lua_setfield( L, -2, CoronaEventIsErrorKey() );

	if (opts) {
		for (NSString* key in opts) {
			NSValue* val = [opts objectForKey:key];
			if ([val isKindOfClass:[NSNumber class]]) {
				NSNumber* n = (NSNumber*)val;
				if (strcmp([n objCType], @encode(BOOL)) == 0) {
					lua_pushboolean(L, [n boolValue]);
				} else {
					lua_pushnumber(L, [(NSNumber*)val doubleValue]);
				}
			} else if ([val isKindOfClass:[NSString class]]) {
				lua_pushstring(L, [(NSString*)val UTF8String]);
			}
			lua_setfield(L, -2, [key UTF8String]);
		}
	}

	CoronaLuaDispatchEvent( L, fListener, 0 );
}

// ----------------------------------------------------------------------------

} // namespace Corona

// ----------------------------------------------------------------------------
