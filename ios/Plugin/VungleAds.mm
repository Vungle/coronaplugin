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
#import "VungleSDKCreativeTracking.h"
#import "VungleSDKHeaderBidding.h"
#import "CoronaRuntime.h"
#import "VungleBytesAssetLoader.h"

// Converts C style string to NSString
#define GetStringParam( _x_ ) ( _x_ != NULL ) ? [NSString stringWithUTF8String:_x_] : [NSString stringWithUTF8String:""]

// Converts C style string to NSString as long as it isnt empty
#define GetStringParamOrNil( _x_ ) ( _x_ != NULL && strlen( _x_ ) ) ? [NSString stringWithUTF8String:_x_] : nil

// events
static const NSString* kEVENT_TYPE_KEY = @"type";
static const NSString* kAD_START_EVENT_TYPE = @"adStart";
static const NSString* kAD_END_EVENT_TYPE = @"adEnd";
static const NSString* kAD_AVAILABLE_EVENT_TYPE = @"adAvailable";
static const NSString* kAD_INITIALIZE_EVENT_TYPE = @"adInitialize";
static const NSString* kAD_LOG_EVENT_TYPE = @"adLog";
static const NSString* kAD_PLACEMENT_PREPARED_EVENT_TYPE = @"adPlacementPrepared";
static const NSString* kAD_VUNGLE_CREATIVE_EVENT_TYPE = @"adVungleCreative";

static const NSString* kVERSION = @"5_4_0";//plugin version. Do not delete this comment

// ----------------------------------------------------------------------------

CORONA_EXPORT
int luaopen_plugin_vungle( lua_State *L )
{
	return Corona::Vungle::Open( L );
}

@implementation VungleDelegate
@synthesize vungle;

- (void)vungleWillCloseAdWithViewInfo:(nonnull VungleViewInfo *)info placementID:(nonnull NSString *)placementID {
//    NSNumber* playTime = [info playTime];
    NSLog(@"vungleWillCloseAdWithViewInfo");
    NSNumber* completedView = [info completedView];
    NSNumber* didDownload = [info didDownload];
    if (placementID == nil)
        placementID = @"";
    vungle->DispatchEvent(false, [kAD_END_EVENT_TYPE UTF8String], @{@"placementID":placementID, @"completedView":completedView, @"didDownload":didDownload});
}

- (void)vungleWillShowAdForPlacementID:(nullable NSString *)placementID {
    NSLog(@"vungleWillShowAdForPlacementID");
    if (placementID == nil)
        placementID = @"";
    vungle->DispatchEvent(false, [kAD_START_EVENT_TYPE UTF8String], @{@"placementID":placementID});
}

- (void)vungleAdPlayabilityUpdate:(BOOL)isAdPlayable placementID:(nullable NSString *)placementID {
    NSLog(@"vungleAdPlayabilityUpdate");
    if (placementID == nil)
        placementID = @"";
    vungle->DispatchEvent(false, [kAD_AVAILABLE_EVENT_TYPE UTF8String], @{@"placementID":placementID, @"isAdPlayable":[NSNumber numberWithBool:isAdPlayable]});
}

- (void)vungleSDKDidInitialize {
    NSLog(@"vungleSDKDidInitialize");
    vungle->DispatchEvent(false, [kAD_INITIALIZE_EVENT_TYPE UTF8String]);
}
@end

@implementation VungleCoronaLogger
@synthesize vungle;
- (void)vungleSDKLog:(NSString *)message {
    vungle->DispatchEvent(false, [kAD_LOG_EVENT_TYPE UTF8String], @{@"message": message});
}
@end

@implementation VungleCreativeTracking
@synthesize vungle;
- (void)vungleCreative:(nullable NSString *)creativeID readyForPlacement:(nullable NSString *)placementID {
    NSLog(@"vungleCreative");
    if (placementID == nil)
        placementID = @"";
    if (creativeID == nil)
        creativeID = @"";
    vungle->DispatchEvent(false, [kAD_VUNGLE_CREATIVE_EVENT_TYPE UTF8String], @{@"placementID":placementID, @"creativeID":creativeID});
}
@end

@implementation VungleHeaderBidding
@synthesize vungle;
- (void)placementPrepared:(NSString *)placement withBidToken:(NSString *)bidToken {
    NSLog(@"placementPrepared");
    if (placement == nil)
        placement = @"";
    if (bidToken == nil)
        bidToken = @"";
    dispatch_async(dispatch_get_main_queue(), ^{
        vungle->DispatchEvent(false, [kAD_PLACEMENT_PREPARED_EVENT_TYPE UTF8String], @{@"placementID":placement, @"bidToken":bidToken});
    });
}
@end

// ----------------------------------------------------------------------------

namespace Corona
{

// ----------------------------------------------------------------------------

const char Vungle::kName[] = "plugin.vungle";
static const char kProviderName[] = "vungle";
static const char kPublisherId[] = "com.vungle";

Vungle* vungleProvider = NULL;

int Vungle::Open( lua_State *L ) {
	void *platformContext = CoronaLuaGetContext( L ); // lua_touserdata( L, lua_upvalueindex( 1 ) );
	id<CoronaRuntime> runtime = (id<CoronaRuntime>)platformContext;
	const char kMetatableName[] = __FILE__;

	const luaL_Reg kFunctions[] =
	{
		{ "init", Vungle::Init },
		{ "show", Vungle::Show },
		{ "load", Vungle::Load },
        { "closeAd", Vungle::closeAd },
		{ "getVersionString", Vungle::versionString },
		{ "isAdAvailable", Vungle::adIsAvailable },
		{ "clearCache", Vungle::clearCache },
		{ "clearSleep", Vungle::clearSleep },
		{ "enableLogging", Vungle::enableLogging },
        { "subscribeHB", Vungle::subscribeHB },
		{ NULL, NULL }
	};

	CoronaLuaInitializeGCMetatable( L, kMetatableName, Finalizer );
	
	// Use 'provider' in closure for kFunctions
	if (!vungleProvider)
		vungleProvider = new Vungle( runtime );
	CoronaLuaPushUserdata( L, vungleProvider, kMetatableName );
	luaL_openlib( L, kName, kFunctions, 1 );

	const char kTestAppId[] = "someDefaultAppId";
	lua_pushstring( L, kTestAppId );
	lua_setfield( L, -2, "testAppId" );

	return 1;
}

int
Vungle::Finalizer( lua_State *L )
{
	delete vungleProvider;
	vungleProvider = NULL;
	return 0;
}

// ads.init( plugin, "appId, placements" [, listener] )
int Vungle::Init( lua_State *L )
{
	int nextArg = 1;

	const char *provider = lua_tostring(L, 1);
	NSString * providerStr = GetStringParam(provider);
	if([providerStr isEqualToString:@"vungle"]) {
		// skip "vungle" as legacy argument
		nextArg++;
	}

    const char *params = lua_tostring(L, nextArg++);
    NSArray* array = [GetStringParam(params) componentsSeparatedByString:@","];
    if ([array count] == 0)
        return 0;
    NSString* appId = [array[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    NSMutableArray *placements = [NSMutableArray array];
    for (int i = 1; i<[array count]; i++)
        [placements addObject:[array[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]];
    /*
    NSMutableArray *placements = [NSMutableArray array];
    luaL_checktype(L, 2, LUA_TTABLE);
    
    for (lua_pushnil(L); lua_next(L, 2); lua_pop(L, 1)) {
        int luaType = lua_type(L, -1);
        NSLog(@"%d", luaType);
        if (luaType == LUA_TSTRING) {
            [placements addObject:GetStringParam(lua_tostring(L, -1))];
        }
    }
    */
    bool success = vungleProvider->Init(L, appId, placements, nextArg);
    lua_pushboolean( L, success );
    
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


int Vungle::Show(lua_State *L) {
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    lua_getfield(L, 1, "placementId");
    NSString* placementId = @"";
    if (!lua_isnil(L, -1))
        placementId = GetStringParam(lua_tostring(L, -1));
    else
        return -1;
    lua_getfield(L, 1, "orientation");
    if (!lua_isnil(L, -1))
        options[VunglePlayAdOptionKeyOrientations] = makeOrientation(lua_tointeger(L, -1));
    lua_pop(L, 1);
    lua_getfield(L, 1, "userTag");
    if (!lua_isnil(L, -1))
        options[VunglePlayAdOptionKeyUser] = GetStringParam(lua_tostring(L, -1));
    lua_pop(L, 1);
    lua_getfield(L, 1, "alertTitle");
    if (!lua_isnil(L, -1))
        options[VunglePlayAdOptionKeyIncentivizedAlertTitleText] = GetStringParam(lua_tostring(L, -1));
    lua_pop(L, 1);
    lua_getfield(L, 1, "alertText");
    if (!lua_isnil(L, -1))
        options[VunglePlayAdOptionKeyIncentivizedAlertBodyText] = GetStringParam(lua_tostring(L, -1));
    lua_pop(L, 1);
    lua_getfield(L, 1, "alertClose");
    if (!lua_isnil(L, -1))
        options[VunglePlayAdOptionKeyIncentivizedAlertCloseButtonText] = GetStringParam(lua_tostring(L, -1));
    lua_pop(L, 1);
    lua_getfield(L, 1, "alertContinue");
    if (!lua_isnil(L, -1))
        options[VunglePlayAdOptionKeyIncentivizedAlertContinueButtonText] = GetStringParam(lua_tostring(L, -1));
    lua_pop(L, 1);
    lua_getfield(L, 1, "flexCloseSec");
    if (!lua_isnil(L, -1))
        options[VunglePlayAdOptionKeyFlexViewAutoDismissSeconds] = GetStringParam(lua_tostring(L, -1));
//        options[VunglePlayAdOptionKeyFlexViewAutoDismissSeconds] = [NSNumber numberWithUnsignedInteger:[GetStringParam(lua_tostring(L, -1)) integerValue]];
    lua_pop(L, 1);
    lua_getfield(L, 1, "ordinal");
    if (!lua_isnil(L, -1))
        options[VunglePlayAdOptionKeyOrdinal] = [NSNumber numberWithUnsignedInteger:[GetStringParam(lua_tostring(L, -1)) integerValue]];
    lua_pop(L, 1);
    lua_getfield(L, 1, "isSoundEnabled");
    if (!lua_isnil(L, -1)) {
        bool b = lua_toboolean(L, -1);
        [VungleSDK sharedSDK].muted = !lua_toboolean(L, -1);
    } else
        [VungleSDK sharedSDK].muted = false;
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

    bool success = vungleProvider->Show(options, placementId);

    lua_pushboolean(L, success);
    return 1;
}
    
int Vungle::Load(lua_State* L) {
    const char *str = lua_tostring( L, 1 );
    NSString* placementId = [NSString stringWithUTF8String:str];
    NSError* err;
    bool load = [[VungleSDK sharedSDK] loadPlacementWithID:placementId error:&err];
    lua_pushboolean(L, load);
    return 1;
}

int Vungle::closeAd(lua_State* L) {
    const char *str = lua_tostring( L, 1 );
    [[VungleSDK sharedSDK] finishedDisplayingAd];
    lua_pushboolean(L, true);
    return 1;
}
    
int Vungle::versionString(lua_State* L) {
	NSString* version = [NSString stringWithFormat:@"%@ (%@)", kVERSION, VungleSDKVersion];
	const char* cVersion = [version UTF8String];
	lua_pushstring(L, cVersion);
	return 1;
}

int Vungle::adIsAvailable(lua_State* L) {
    const char *str = lua_tostring( L, 1 );
    NSString* placementId = [NSString stringWithUTF8String:str];
    bool available = [[VungleSDK sharedSDK] isAdCachedForPlacementID:placementId];
	lua_pushboolean(L, available);
	return 1;
}

int Vungle::clearCache(lua_State* L) {
    lua_pushboolean(L, true);
    return 1;
}
    
int Vungle::clearSleep(lua_State* L) {
    [[VungleSDK sharedSDK] clearSleep];
    lua_pushboolean(L, true);
    return 1;
}

int Vungle::enableLogging(lua_State* L) {
    bool enable = lua_toboolean( L, 1 );
    [[VungleSDK sharedSDK] setLoggingEnabled: enable];
    lua_pushboolean(L, true);
    return 1;
}

int Vungle::subscribeHB(lua_State* L) {
    vungleProvider->subscribeHB();
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
    _creativeTracking = [[VungleCreativeTracking alloc] init];
    _headerBidding = [[VungleHeaderBidding alloc] init];
    _logger = [[VungleCoronaLogger alloc] init];
}

Vungle::~Vungle() {
	CoronaLuaDeleteRef( fRuntime.L, fListener );
    [_controller release];
    [_delegate release];
    [_creativeTracking release];
    [_headerBidding release];
    [[VungleSDK sharedSDK] detachLogger:_logger];
	[_logger release];
	[fAppId release];
}

void Vungle::subscribeHB() {
    [VungleSDK sharedSDK].headerBiddingDelegate = _headerBidding;
}
    
bool Vungle::Init(lua_State *L, NSString* appId, NSMutableArray* placements, int listenerIndex) {
    bool result = false;
    if (appId) {
        // set the new asset loader
        VungleBytesAssetLoader* loader = [[VungleBytesAssetLoader alloc] init];
        [VungleSDK setupSDKWithAssetLoader:loader];
        VungleSDK* sdk = [VungleSDK sharedSDK];

		[sdk setAssetLoader:loader];
		[loader release];

		[sdk performSelector:@selector(setPluginName:version:) withObject:@"corona" withObject:kVERSION];
        NSError* err;
        [sdk startWithAppId:appId placements:placements error:&err];
		sdk.delegate = _delegate;
        sdk.creativeTrackingDelegate = _creativeTracking;
        //sdk.headerBiddingDelegate = _headerBidding;
        _logger.vungle = this;
        [sdk attachLogger:_logger];
        [sdk setLoggingEnabled:true];

		fListener = ( CoronaLuaIsListener( L, listenerIndex, "adsRequest" ) ? CoronaLuaNewRef( L, listenerIndex ) : NULL );

		_delegate.vungle = this;
        _creativeTracking.vungle = this;
        _headerBidding.vungle = this;
		result = true;
	}

    return result;
}

bool Vungle::Show(NSDictionary* options, NSString* placementID) {
    VungleSDK* sdk = [VungleSDK sharedSDK];
    if ([sdk isAdCachedForPlacementID:placementID]) {
    	NSError* error = nil;
        [sdk playAd:_controller options:options placementID: placementID error:&error];
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
