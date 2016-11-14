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
#import "VungleSDK.h"
#import "CoronaRuntime.h"

// Converts C style string to NSString
#define GetStringParam( _x_ ) ( _x_ != NULL ) ? [NSString stringWithUTF8String:_x_] : [NSString stringWithUTF8String:""]

// Converts C style string to NSString as long as it isnt empty
#define GetStringParamOrNil( _x_ ) ( _x_ != NULL && strlen( _x_ ) ) ? [NSString stringWithUTF8String:_x_] : nil


static const char* kINCENTIVIZED_AD_TYPE = "incentivized";

// show() ad properties and defaults
static const char* kIS_ANIMATED_KEY = "isAnimated";
static const bool  kIS_ANIMATED_DEFAULT = true;
static const char* kORIENTATIONS = "orientations";
static const char* kIS_SOUND_ENABLED_KEY = "isSoundEnabled";
static const bool  kIS_SOUND_ENABLED_DEFAULT = true;
static const char* kIS_CLOSE_SHOWN_KEY = "isCloseShown";
static const bool  kIS_CLOSE_SHOWN_DEFAULT = true;
static const char* kUSERNAME_KEY = "username";
static const char* kIS_COMPLETED_VIEW = "isCompletedView";

// events
static const NSString* kEVENT_TYPE_KEY = @"type";
static const NSString* kAD_START_EVENT_TYPE = @"adStart";
static const NSString* kAD_VIEW_EVENT_TYPE = @"adView";
static const NSString* kAD_END_EVENT_TYPE = @"adEnd";
static const NSString* kAD_AD_AVAILABLE_EVENT_TYPE = @"cachedAdAvailable";
static const NSString* kAD_LOG_EVENT_TYPE = @"adLog";
static const NSString* kVERSION = @"2_0_4";//plugin version. Do not delete this comment

// ----------------------------------------------------------------------------

CORONA_EXPORT
int luaopen_CoronaProvider_ads_vungle( lua_State *L )
{
	return Corona::Vungle::Open( L );
}

@implementation VungleDelegate
@synthesize vungle;

- (void)vungleSDKwillCloseAdWithViewInfo:(NSDictionary *)viewInfo willPresentProductSheet:(BOOL)willPresentProductSheet {
    NSNumber* playTime = [viewInfo objectForKey:@"playTime"] ? [viewInfo objectForKey:@"playTime"] : @(0);
    bool completedView = [[viewInfo objectForKey:@"completedView"] boolValue];
    float allTime = completedView ? [playTime floatValue] : [playTime floatValue]*2;
    vungle->DispatchEvent(false, [kAD_VIEW_EVENT_TYPE UTF8String], @{@"secondsWatched": playTime, @"isCompletedView": [viewInfo objectForKey:@"completedView"], @"totalAdSeconds": @(allTime)});
    if (!willPresentProductSheet) {
        vungle->DispatchEvent(false, [kAD_END_EVENT_TYPE UTF8String], @{@"wasCallToActionClicked": [viewInfo objectForKey:@"didDownload"] ? @YES : @NO});
    }
}

- (void)vungleSDKwillCloseProductSheet:(id)productSheet {
    vungle->DispatchEvent(false, [kAD_END_EVENT_TYPE UTF8String], @{@"wasCallToActionClicked": @YES});
}

- (void)vungleSDKwillShowAd {
	vungle->DispatchEvent(false, [kAD_START_EVENT_TYPE UTF8String]);
}

- (void)vungleSDKhasCachedAdAvailable {
	vungle->DispatchEvent(false, [kAD_AD_AVAILABLE_EVENT_TYPE UTF8String]);
}

- (void)vungleSDKAdPlayableChanged:(BOOL)isAdPlayable {
	if (isAdPlayable) {
		vungle->DispatchEvent(false, [kAD_AD_AVAILABLE_EVENT_TYPE UTF8String]);
	}
}

@end

@implementation VungleCoronaLogger
@synthesize vungle;

- (void)vungleSDKLog:(NSString *)message {
    vungle->DispatchEvent(false, [kAD_LOG_EVENT_TYPE UTF8String], @{@"message": message});
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
            { "showEx", Vungle::showEx },
            { "clearCache", Vungle::clearCache },
            { "clearSleep", Vungle::clearSleep },
            { "setSoundEnabled", Vungle::setSoundEnabled },
            { "enableLogging", Vungle::enableLogging },
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
	NSUInteger orientations = UIInterfaceOrientationMaskAll;
	bool isCloseShown = kIS_CLOSE_SHOWN_DEFAULT;
	bool success = false;
    VungleSDK* sdk = [VungleSDK sharedSDK];
	if ([sdk isAdPlayable]) {
		if (numArgs >= kPARAM_TABLE_INDEX && lua_istable(L, kPARAM_TABLE_INDEX)) {
			lua_getfield(L, kPARAM_TABLE_INDEX, kIS_ANIMATED_KEY);
			if (!lua_isnil(L, -1)) {
				isAnimated = lua_toboolean(L, -1);
				NSLog(@"isAnimated: %d", isAnimated);
			} else {
				NSLog(@"isAnimated: %d (default)", isAnimated);
			}
			lua_pop(L, 1);
			
			lua_getfield(L, kPARAM_TABLE_INDEX, kORIENTATIONS);
			if (!lua_isnil(L, -1)) {
				orientations = lua_tointeger(L, -1);
				NSLog(@"orientations: %lud", (unsigned long)orientations);
			} else {
				NSLog(@"orientations: %lud (default)", (unsigned long)orientations);
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
        sdk.muted = !isSoundEnabled;
		
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
            success = vungleProvider->ShowIncentivized(isCloseShown, orientations, username);
		} // interstitial
		else {
			success = vungleProvider->Show(isCloseShown, orientations);
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

NSNumber* makeOrientation(int code) {
    NSNumber* orientationMask;
    switch( code )
    {
        case 0:
            orientationMask = @(UIInterfaceOrientationMaskPortrait);
            break;
        case 1:
            orientationMask = @(UIInterfaceOrientationMaskLandscapeLeft);
            break;
        case 2:
            orientationMask = @(UIInterfaceOrientationMaskLandscapeRight);
            break;
        case 3:
            orientationMask = @(UIInterfaceOrientationMaskPortraitUpsideDown);
            break;
        case 4:
            orientationMask = @(UIInterfaceOrientationMaskLandscape);
            break;
        case 5:
            orientationMask = @(UIInterfaceOrientationMaskAll);
            break;
        case 6:
            orientationMask = @(UIInterfaceOrientationMaskAllButUpsideDown);
            break;
        default:
            orientationMask = @(UIInterfaceOrientationMaskAllButUpsideDown);
    }
    return orientationMask;
}


int Vungle::showEx(lua_State *L) {
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    lua_getfield(L, 1, "incentivized");
    if (!lua_isnil(L, -1)) {
        [options setValue:[NSNumber numberWithBool:lua_toboolean(L, -1)] forKey:VunglePlayAdOptionKeyIncentivized];
    }
    lua_pop(L, 1);
    lua_getfield(L, 1, "orientation");
    if (!lua_isnil(L, -1)) {
        options[VunglePlayAdOptionKeyOrientations] = makeOrientation(lua_tointeger(L, -1));
    }
    lua_pop(L, 1);
    lua_getfield(L, 1, "userTag");
    if (!lua_isnil(L, -1)) {
        options[VunglePlayAdOptionKeyUser] = GetStringParam(lua_tostring(L, -1));
    }
    lua_pop(L, 1);
    lua_getfield(L, 1, "alertTitle");
    if (!lua_isnil(L, -1)) {
        options[VunglePlayAdOptionKeyIncentivizedAlertTitleText] = GetStringParam(lua_tostring(L, -1));
    }
    lua_pop(L, 1);
    lua_getfield(L, 1, "alertText");
    if (!lua_isnil(L, -1)) {
        options[VunglePlayAdOptionKeyIncentivizedAlertBodyText] = GetStringParam(lua_tostring(L, -1));
    }
    lua_pop(L, 1);
    lua_getfield(L, 1, "closeText");
    if (!lua_isnil(L, -1)) {
        options[VunglePlayAdOptionKeyIncentivizedAlertCloseButtonText] = GetStringParam(lua_tostring(L, -1));
    }
    lua_pop(L, 1);
    lua_getfield(L, 1, "continueText");
    if (!lua_isnil(L, -1)) {
        options[VunglePlayAdOptionKeyIncentivizedAlertContinueButtonText] = GetStringParam(lua_tostring(L, -1));
    }
    lua_pop(L, 1);
    lua_getfield(L, 1, "placement");
    if (!lua_isnil(L, -1)) {
        options[VunglePlayAdOptionKeyPlacement] = GetStringParam(lua_tostring(L, -1));
    }
    lua_pop(L, 1);

    NSMutableDictionary *extra = [NSMutableDictionary dictionary];
    lua_getfield(L, 1, "key1");
    if (!lua_isnil(L, -1)) {
        extra[VunglePlayAdOptionKeyExtra1] = GetStringParam(lua_tostring(L, -1));
    }
    lua_pop(L, 1);
    lua_getfield(L, 1, "key2");
    if (!lua_isnil(L, -1)) {
        extra[VunglePlayAdOptionKeyExtra2] = GetStringParam(lua_tostring(L, -1));
    }
    lua_pop(L, 1);
    lua_getfield(L, 1, "key3");
    if (!lua_isnil(L, -1)) {
        extra[VunglePlayAdOptionKeyExtra3] = GetStringParam(lua_tostring(L, -1));
    }
    lua_pop(L, 1);
    lua_getfield(L, 1, "key4");
    if (!lua_isnil(L, -1)) {
        extra[VunglePlayAdOptionKeyExtra4] = GetStringParam(lua_tostring(L, -1));
    }
    lua_pop(L, 1);
    lua_getfield(L, 1, "key5");
    if (!lua_isnil(L, -1)) {
        extra[VunglePlayAdOptionKeyExtra5] = GetStringParam(lua_tostring(L, -1));
    }
    lua_pop(L, 1);
    lua_getfield(L, 1, "key6");
    if (!lua_isnil(L, -1)) {
        extra[VunglePlayAdOptionKeyExtra6] = GetStringParam(lua_tostring(L, -1));
    }
    lua_pop(L, 1);
    lua_getfield(L, 1, "key7");
    if (!lua_isnil(L, -1)) {
        extra[VunglePlayAdOptionKeyExtra7] = GetStringParam(lua_tostring(L, -1));
    }
    lua_pop(L, 1);
    lua_getfield(L, 1, "key8");
    if (!lua_isnil(L, -1)) {
        extra[VunglePlayAdOptionKeyExtra8] = GetStringParam(lua_tostring(L, -1));
    }
    lua_pop(L, 1);
    options[VunglePlayAdOptionKeyExtraInfoDictionary] = extra;

    bool success = vungleProvider->ShowEx(options);

    lua_pushboolean(L, success);
    return 1;
}

// TODO remove
int Vungle::setBackButtonEnabled(lua_State* L) {
	lua_pushboolean(L, true);
	return 1;
}

int Vungle::versionString(lua_State* L) {
	NSString* version = [NSString stringWithFormat:@"%@ (%@)", kVERSION, VungleSDKVersion];
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
    NSLog(@"%@", [[VungleSDK sharedSDK] debugInfo]);
	lua_pushboolean(L, true);
	return 1;
}

int Vungle::adIsAvailable(lua_State* L) {
	bool available = [[VungleSDK sharedSDK] isAdPlayable];
	lua_pushboolean(L, available);
	return 1;
}

int Vungle::clearCache(lua_State* L) {
    [[VungleSDK sharedSDK] clearCache];
    lua_pushboolean(L, true);
    return 1;
}
    
int Vungle::clearSleep(lua_State* L) {
    [[VungleSDK sharedSDK] clearSleep];
    lua_pushboolean(L, true);
    return 1;
}

int Vungle::setSoundEnabled(lua_State* L) {
    bool enable = lua_toboolean( L, 1 );
    [[VungleSDK sharedSDK] setMuted: !enable];
    lua_pushboolean(L, true);
    return 1;
}

int Vungle::enableLogging(lua_State* L) {
    bool enable = lua_toboolean( L, 1 );
    [[VungleSDK sharedSDK] setLoggingEnabled: enable];
    lua_pushboolean(L, true);
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
    _logger = [[VungleCoronaLogger alloc] init];
}

Vungle::~Vungle()
{
	CoronaLuaDeleteRef( fRuntime.L, fListener );
    [_controller release];
    [_delegate release];
    [[VungleSDK sharedSDK] detachLogger:_logger];
	[_logger release];
	[fAppId release];
}

bool Vungle::Init(lua_State *L, const char *appId, int listenerIndex)
{
    bool result = false;
    
    if ( appId )
    {
        NSString* str = [NSString stringWithUTF8String:appId];
        VungleSDK* sdk = [VungleSDK sharedSDK];

		[sdk performSelector:@selector(setPluginName:version:) withObject:@"corona" withObject:kVERSION];
		[sdk startWithAppId:str];
		sdk.delegate = _delegate;
        _logger.vungle = this;
        [sdk attachLogger:_logger];
        [sdk setLoggingEnabled:true];

		fListener = ( CoronaLuaIsListener( L, listenerIndex, "adsRequest" ) ? CoronaLuaNewRef( L, listenerIndex ) : NULL );
		_delegate.vungle = this;
		result = true;
	}

    return result;
}

bool Vungle::Show(bool showClose, NSUInteger orientations) {
	VungleSDK* sdk = [VungleSDK sharedSDK];
    if ([sdk isAdPlayable]) {
    	NSError* error = nil;
        [sdk playAd:_controller withOptions:@{VunglePlayAdOptionKeyOrientations: @(orientations)} error:&error];
		return true;
	}
	return false;
}
	
bool Vungle::ShowEx(NSDictionary* options) {
    VungleSDK* sdk = [VungleSDK sharedSDK];
    if ([sdk isAdPlayable]) {
    	NSError* error = nil;
        [sdk playAd:_controller withOptions:options error:&error];
        return true;
    }
    return false;
}

bool Vungle::ShowIncentivized(bool showClose, NSUInteger orientations, const std::string& userTag) {
	NSString* userString = [NSString stringWithUTF8String:userTag.c_str()];
    VungleSDK* sdk = [VungleSDK sharedSDK];
	if ([sdk isAdPlayable]) {
    	NSError* error = nil;
        [sdk playAd:_controller withOptions:@{VunglePlayAdOptionKeyOrientations: @(orientations),
                                              VunglePlayAdOptionKeyIncentivized: @(YES),
                                              VunglePlayAdOptionKeyUser: userString}  error:&error];
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
				if ((strcmp([n objCType], @encode(BOOL)) == 0) || (strcmp([n objCType], @encode(char)) == 0)) {
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
