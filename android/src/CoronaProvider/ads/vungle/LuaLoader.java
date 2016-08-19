/*
 * The MIT License (MIT)
 * 
 * Copyright (c) 2013-2014 Vungle
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
package CoronaProvider.ads.vungle;

import java.util.Locale;

import android.app.Activity;
import android.content.Context;
import android.os.Looper;

import com.ansca.corona.CoronaEnvironment;
import com.ansca.corona.CoronaLua;
import com.ansca.corona.CoronaLuaEvent;
import com.ansca.corona.CoronaRuntime;
import com.ansca.corona.CoronaRuntimeListener;
import com.ansca.corona.CoronaRuntimeTask;
import com.ansca.corona.CoronaRuntimeTaskDispatcher;
import com.naef.jnlua.JavaFunction;
import com.naef.jnlua.LuaState;
import com.naef.jnlua.NamedJavaFunction;
import com.vungle.publisher.AdConfig;
import com.vungle.publisher.EventListener;
import com.vungle.publisher.Orientation;
import com.vungle.publisher.VunglePub;
import com.vungle.publisher.env.WrapperFramework;
import com.vungle.publisher.inject.Injector;
import com.vungle.log.Logger;

/**
 * <p>Vungle AdsProvider plugin.</p>
 */
public class LuaLoader implements JavaFunction, CoronaRuntimeListener {
	private static final String TAG = "VungleCorona";
	private static final String VERSION = "2.2.2";//plugin version. Do not delete this comment
	private static final Locale LOCALE = Locale.US;

	// LUA method names
	static final String GET_VERSION_STRING_METHOD = "getVersionString";
	static final String HIDE_METHOD = "hide";
	static final String INIT_METHOD = "init";
	static final String IS_CACHED_AD_AVAILABLE_METHOD = "isAdAvailable";
	static final String SHOW_CACHE_FILES_METHOD = "showCacheFiles";
	static final String SHOW_METHOD = "show";
    static final String SHOWEX_METHOD = "showEx";
    static final String CLEAR_CACHE_METHOD = "clearCache";
    static final String CLEAR_SLEEP_METHOD = "clearSleep";
    static final String SET_SOUND_ENABLED_METHOD = "setSoundEnabled";
    static final String ENABLE_LOGGING_METHOD = "enableLogging";

	// show() ad types
//	private static final String INTERSTITIAL_AD_TYPE = "interstitial";
	private static final String INCENTIVIZED_AD_TYPE = "incentivized";

	// show() ad properties and defaults
	private static final String IS_AUTO_ROTATION_KEY = "isAutoRotation";
	private static final boolean IS_AUTO_ROTATION_DEFAULT = false;
    private static final String IS_IMMERSIVE_KEY = "immersive";
    private static final boolean IS_IMMERSIVE_DEFAULT = false;
    
	private static final String IS_BACK_BUTTON_IMMEDIATELY_ENABLED_KEY = "isBackButtonEnabled";
	private static final boolean IS_BACK_BUTTON_IMMEDIATELY_ENABLED_DEFAULT = false;
	private static final String IS_SOUND_ENABLED_KEY = "isSoundEnabled";
	private static boolean IS_SOUND_ENABLED_DEFAULT = true;
	private static final String INCENTIVIZED_USER_ID_KEY = "username";

	// events
	static final String EVENT_TYPE_KEY = "type";
	static final String AD_START_EVENT_TYPE = "adStart";
	static final String AD_VIEW_EVENT_TYPE = "adView";
	static final String AD_VIEW_IS_COMPLETED_VIEW_KEY = "isCompletedView";
	static final String AD_VIEW_SECONDS_WATCHED_KEY = "secondsWatched";
	static final String AD_VIEW_TOTAL_AD_SECONDS_KEY = "totalAdSeconds";
	static final String AD_END_EVENT_TYPE = "adEnd";
	static final String CACHED_AD_AVAILABLE_EVENT_TYPE = "cachedAdAvailable";
	static final String CORONA_AD_PROVIDER_NAME = "vungle";
	static final String WAS_CALL_TO_ACTION_CLICKED_KEY = "wasCallToActionClicked";

	private static final String DEFAULT_CORONA_APPLICATION_ID = "defaultCoronaApplicationId";
	private final VunglePub vunglePub = VunglePub.getInstance();

	/**
	 * application ID for ad network
	 */
	private String applicationId;

	// lua state
	CoronaRuntimeTaskDispatcher taskDispatcher;
	int luaListener = CoronaLua.REFNIL;

	// N.B. not called on UI thread 
	@Override
	public int invoke(LuaState luaState) {
		final String libName = luaState.toString(1);
		luaState.register(libName, new NamedJavaFunction[] {
			new GetVersionStringWrapper(),
			new HideWrapper(),
			new InitWrapper(),
			new IsCachedAdAvailableWrapper(),
			new ShowCacheFilesWrapper(),
			new ShowWrapper(),
            new ShowExWrapper(),
            new ClearCacheWrapper(),
            new ClearSleepWrapper(),
            new SetSoundEnabledWrapper(),
            new EnableLoggingWrapper()
		});
		// add fallback test app id
		luaState.pushString(DEFAULT_CORONA_APPLICATION_ID);
		luaState.setField(-2, "testAppId");
		return 1;
	}

	private class InitWrapper implements NamedJavaFunction {
		private InitWrapper() {}

		@Override
		public String getName() {
			return INIT_METHOD;
		}

		// N.B. not called on UI thread
		@Override
		public int invoke(LuaState luaState) {
			return init(luaState);
		}
	}

	/**
	 * <p>Initializes this ad provider.</p>
	 * 
	 * <p>In Lua, returns <code>true</code> if successful; <code>false</code> otherwise.
	 * 
	 * @param luaState [1: providerName,
	 *                  2: pubAppId,
	 *                  3: listener (optional)]
	 * @return <code>1</code> (the number of return values).
	 */
	public int init(LuaState luaState) {
		final boolean[] isSuccess = {false};
		final String applicationId = this.applicationId = luaState.toString(2);
		if (applicationId == null) {
			Logger.w(TAG, "WARNING: " + INIT_METHOD + "() application ID was null");
		}
		else {
			final int LISTENER_INDEX = 3;
			if (CoronaLua.isListener(luaState, LISTENER_INDEX, CoronaLuaEvent.ADSREQUEST_TYPE)) {
				luaListener = CoronaLua.newRef(luaState, LISTENER_INDEX);
			}
			final Context applicationContext = CoronaEnvironment.getApplicationContext();
			final Injector injector = Injector.getInstance();
			injector.setWrapperFramework(WrapperFramework.corona);
			injector.setWrapperFrameworkVersion(VERSION);
			final VunglePub vunglePub = this.vunglePub;
			CoronaEnvironment.getCoronaActivity().runOnUiThread(new Runnable() {
				@Override
				public void run() {
					isSuccess[0] = vunglePub.init(applicationContext, applicationId);

			vunglePub.setEventListeners(new EventListener() {
				@Override
				public void onAdEnd(boolean wasSuccessfulView, final boolean wasCallToActionClicked) {
					if (luaListener != CoronaLua.REFNIL) {
						taskDispatcher.send(
							new CoronaRuntimeTask() {
								@Override
								public void executeUsing(CoronaRuntime coronaRuntime) {
									final String eventType = AD_END_EVENT_TYPE;
									try {
										final LuaState asyncLuaState = createBaseEvent(coronaRuntime, eventType, false);
										asyncLuaState.pushBoolean(wasCallToActionClicked);
										asyncLuaState.setField(-2, WAS_CALL_TO_ACTION_CLICKED_KEY);
										CoronaLua.dispatchEvent(asyncLuaState, luaListener, 0);
									}
									catch (Exception exception) {
										Logger.e(TAG, "Unable to dispatch event " + eventType, exception);
									}
								}
							}
						);
						taskDispatcher.send(
							new CoronaRuntimeTask() {
								@Override
								public void executeUsing(CoronaRuntime coronaRuntime) {
									final String eventType = AD_VIEW_EVENT_TYPE;
									try {
										final LuaState asyncLuaState = createBaseEvent(coronaRuntime, eventType, false);
										asyncLuaState.pushBoolean(wasSuccessfulView);
										asyncLuaState.setField(-2, AD_VIEW_IS_COMPLETED_VIEW_KEY);
										if (wasSuccessfulView)
											asyncLuaState.pushNumber(15);
										else
											asyncLuaState.pushNumber(1);
										asyncLuaState.setField(-2, AD_VIEW_SECONDS_WATCHED_KEY);
										asyncLuaState.pushNumber(15);
										asyncLuaState.setField(-2, AD_VIEW_TOTAL_AD_SECONDS_KEY);
										CoronaLua.dispatchEvent(asyncLuaState, luaListener, 0);
									}
									catch (Exception exception) {
										Logger.e(TAG, "Unable to dispatch event " + eventType, exception);
									}
								}
							}
						);
					}
				}

				@Override
				public void onAdStart() {
					sendEmptyEvent(AD_START_EVENT_TYPE);
				}

				@Override
				public void onAdUnavailable(final String reason) {
					if (luaListener != CoronaLua.REFNIL) {
						taskDispatcher.send(
							new CoronaRuntimeTask() {
								@Override
								public void executeUsing(CoronaRuntime coronaRuntime) {
									final String eventType = AD_START_EVENT_TYPE;
									try {
										final LuaState asyncLuaState = createBaseEvent(coronaRuntime, eventType, true);
										asyncLuaState.pushString(reason);
										asyncLuaState.setField(-2, CoronaLuaEvent.RESPONSE_KEY);
										CoronaLua.dispatchEvent(asyncLuaState, luaListener, 0);
									}
									catch (Exception exception) {
										Logger.e(TAG, "Unable to dispatch event " + eventType, exception);
									}
								}
							}
						);
					}
				}
				
				@Override
				public void onAdPlayableChanged(boolean arg) {
					if (arg) {
						sendEmptyEvent(CACHED_AD_AVAILABLE_EVENT_TYPE);
					}
				}

				@Override
				public void onVideoView(final boolean isCompletedView, final int watchedMillis, final int videoMillis) {
					if (luaListener != CoronaLua.REFNIL) {
						taskDispatcher.send(
							new CoronaRuntimeTask() {
								@Override
								public void executeUsing(CoronaRuntime coronaRuntime) {
									final String eventType = AD_VIEW_EVENT_TYPE;
									try {
										final LuaState asyncLuaState = createBaseEvent(coronaRuntime, eventType, false);
										asyncLuaState.pushBoolean(isCompletedView);
										asyncLuaState.setField(-2, AD_VIEW_IS_COMPLETED_VIEW_KEY);
										asyncLuaState.pushNumber(watchedMillis / 1000.0);
										asyncLuaState.setField(-2, AD_VIEW_SECONDS_WATCHED_KEY);
										asyncLuaState.pushNumber(videoMillis / 1000.0);
										asyncLuaState.setField(-2, AD_VIEW_TOTAL_AD_SECONDS_KEY);
										CoronaLua.dispatchEvent(asyncLuaState, luaListener, 0);
									}
									catch (Exception exception) {
										Logger.e(TAG, "Unable to dispatch event " + eventType, exception);
									}
								}
							}
						);
					}
				}

				private void sendEmptyEvent(final String eventType) {
					if (luaListener != CoronaLua.REFNIL) {
						taskDispatcher.send(
							new CoronaRuntimeTask() {
								@Override
								public void executeUsing(CoronaRuntime coronaRuntime) {
									try {
										final LuaState asyncLuaState = createBaseEvent(coronaRuntime, eventType, false);
										CoronaLua.dispatchEvent(asyncLuaState, luaListener, 0);
									}
									catch (Exception exception) {
										Logger.e(TAG, "Unable to dispatch event " + eventType, exception);
									}
								}
							}
						);
					}
				}

				private LuaState createBaseEvent(CoronaRuntime coronaRuntime, String eventType, boolean isError) {
					final LuaState currentLuaState = coronaRuntime.getLuaState();
					LuaLoader.this.createBaseEvent(currentLuaState, isError);
					currentLuaState.pushString(eventType);
					currentLuaState.setField(-2, EVENT_TYPE_KEY);
					return currentLuaState;
				}
			});
			vunglePub.onResume();

				}
			});
		}
		luaState.pushBoolean(isSuccess[0]);
		return 1;
	}

	private class GetVersionStringWrapper implements NamedJavaFunction {
		private GetVersionStringWrapper() {}

		@Override
		public String getName() {
			return GET_VERSION_STRING_METHOD;
		}

		// N.B. not called on UI thread
		@Override
		public int invoke(LuaState luaState) {
			return getVersionString(luaState);
		}
	}

	/**
	 * <p>Returns the version string.</p>
	 * 
	 * @return <code>1</code>.
	 */
	public int getVersionString(LuaState luaState) {
		final String version = VERSION + " (" + VunglePub.VERSION + ")";
		luaState.pushString(version);
		return 1;
	}

	/**
	 * @deprecated
	 */
	private class ShowCacheFilesWrapper implements NamedJavaFunction {
		ShowCacheFilesWrapper() {}

		@Override
		public String getName() {
			return SHOW_CACHE_FILES_METHOD;
		}

		// N.B. not called on UI thread
		@Override
		public int invoke(LuaState luaState) {
			Logger.d(TAG, SHOW_CACHE_FILES_METHOD + "() deprecated");
			return 0;
		}
	}

	private class IsCachedAdAvailableWrapper implements NamedJavaFunction {
		IsCachedAdAvailableWrapper() {}

		@Override
		public String getName() {
			return IS_CACHED_AD_AVAILABLE_METHOD;
		}

		// N.B. not called on UI thread
		@Override
		public int invoke(LuaState luaState) {
			return isCachedAdAvailable(luaState);
		}
	}

	/**
	 * <p>Returns <code>true</code> if a cached ad is available; otherwise, returns <code>false</code>.</p>
	 * 
	 * @param luaState
	 * @return <code>1</code> (the number of return values).
	 */
	public int isCachedAdAvailable(LuaState luaState) {
		luaState.pushBoolean(vunglePub.isAdPlayable());
		return 1;
	}

	private class ShowWrapper implements NamedJavaFunction {
		ShowWrapper() {}

		@Override
		public String getName() {
			return SHOW_METHOD;
		}
		
		// N.B. not called on UI thread
		@Override
		public int invoke(LuaState luaState) {
			return show(luaState);
		}
	}

	/**
	 * <p>Plays an ad.</p>
	 * 
	 * @param luaState [1: "interstitial" || "incentivized", 
	 *                  2: {
	 *                       isAnimated:           true* || false   (ignored),
	 *                       isAutoRotation:       true || false*,
	 *                       isBackButtonEnabled:  true || false*,
	 *                       isSoundEnabled:       true* || false,
	 *                       username:             string          (optional, only used for incentivized ad type)
	 *                     }
	 * @return <code>0</code>.
	 */
	public int show(LuaState luaState) {
		final String METHOD_NAME = SHOW_METHOD + "(): ";
		final int AD_TYPE_INDEX = 1;
		final int PARAM_TABLE_INDEX = 2;
		final int numberOfArguments = luaState.getTop();
		final AdConfig adConfig = new AdConfig();
		// get the lower case ad type if it exists:
		final String adType = 
			(numberOfArguments >= AD_TYPE_INDEX ? 
				(luaState.toString(AD_TYPE_INDEX) == null ?
					null : 
					luaState.toString(AD_TYPE_INDEX).toLowerCase(LOCALE)) :
				null);
		Logger.v(TAG, METHOD_NAME + "adType = " + adType);
		final boolean isIncentivized = INCENTIVIZED_AD_TYPE.equals(adType);
		adConfig.setIncentivized(isIncentivized);
		if (numberOfArguments >= PARAM_TABLE_INDEX && luaState.isTable(PARAM_TABLE_INDEX)) {
			boolean isAutoRotation = IS_AUTO_ROTATION_DEFAULT;
			luaState.getField(PARAM_TABLE_INDEX, IS_AUTO_ROTATION_KEY);
			if (luaState.isNil(-1)) {
				Logger.v(TAG, METHOD_NAME + IS_AUTO_ROTATION_KEY + " = " + isAutoRotation + " (default)");
			}
			else {
				isAutoRotation = luaState.toBoolean(-1);
				Logger.v(TAG, METHOD_NAME + IS_AUTO_ROTATION_KEY + " = " + isAutoRotation);
			}
			luaState.pop(1);
			adConfig.setOrientation(isAutoRotation ? Orientation.autoRotate : Orientation.matchVideo);

			boolean isBackButtonImmediatelyEnabled = IS_BACK_BUTTON_IMMEDIATELY_ENABLED_DEFAULT;
			luaState.getField(PARAM_TABLE_INDEX, IS_BACK_BUTTON_IMMEDIATELY_ENABLED_KEY);
			if (luaState.isNil(-1)) {
				Logger.v(TAG, METHOD_NAME + IS_BACK_BUTTON_IMMEDIATELY_ENABLED_KEY + " = " + isBackButtonImmediatelyEnabled + " (default)");
			}
			else {
				isBackButtonImmediatelyEnabled = luaState.toBoolean(-1);
				Logger.v(TAG, METHOD_NAME + IS_BACK_BUTTON_IMMEDIATELY_ENABLED_KEY + " = " + isBackButtonImmediatelyEnabled);
			}
			luaState.pop(1);
			adConfig.setBackButtonImmediatelyEnabled(isBackButtonImmediatelyEnabled);

			boolean isSoundEnabled = IS_SOUND_ENABLED_DEFAULT;
			luaState.getField(PARAM_TABLE_INDEX, IS_SOUND_ENABLED_KEY);
			if (luaState.isNil(-1)) {
				Logger.v(TAG, METHOD_NAME + IS_SOUND_ENABLED_KEY + " = " + isSoundEnabled + " (default)");
			}
			else {
				isSoundEnabled = luaState.toBoolean(-1);
				Logger.v(TAG, METHOD_NAME + IS_SOUND_ENABLED_KEY + " = " + isSoundEnabled);
			}
			luaState.pop(1);
			adConfig.setSoundEnabled(isSoundEnabled);

			if (isIncentivized) {
				String incentivizedUserId = null; 
				luaState.getField(PARAM_TABLE_INDEX, INCENTIVIZED_USER_ID_KEY);
				if (!luaState.isNil(-1)) {
					incentivizedUserId = luaState.toString(-1);
				}
				Logger.v(TAG, METHOD_NAME + "username = " + incentivizedUserId);
				luaState.pop(1);
				adConfig.setIncentivizedUserId(incentivizedUserId);
			}
		}
		vunglePub.playAd(adConfig);
		return 0;
	}
    
    private class ShowExWrapper implements NamedJavaFunction {
        ShowExWrapper() {}
        
        @Override
        public String getName() {
            return SHOWEX_METHOD;
        }
        
        // N.B. not called on UI thread
        @Override
        public int invoke(LuaState luaState) {
            return showEx(luaState);
        }
    }
    
    public int showEx(LuaState luaState) {
        final String METHOD_NAME = SHOW_METHOD + "(): ";
        final AdConfig adConfig = new AdConfig();
        final int numberOfArguments = luaState.getTop();
        // get the lower case ad type if it exists:
        if (numberOfArguments >= 1 && luaState.isTable(1)) {
            
            luaState.getField(1, "isAutoRotation");
            if (!luaState.isNil(-1)) {
                adConfig.setOrientation(luaState.toBoolean(-1) ? Orientation.autoRotate : Orientation.matchVideo);
            }
            luaState.getField(1, "isSoundEnabled");
            if (!luaState.isNil(-1)) {
                adConfig.setSoundEnabled(luaState.toBoolean(-1));
            }
            luaState.pop(1);
            luaState.getField(1, "incentivized");
            if (!luaState.isNil(-1)) {
                adConfig.setIncentivized(luaState.toBoolean(-1));
            }
            luaState.pop(1);
            luaState.getField(1, "immersive");
            if (!luaState.isNil(-1)) {
                adConfig.setImmersiveMode(luaState.toBoolean(-1));
            }
            luaState.pop(1);
            luaState.getField(1, "userTag");
            if (!luaState.isNil(-1)) {
                adConfig.setIncentivizedUserId(luaState.toString(-1));
            }
            luaState.pop(1);
            luaState.getField(1, "alertTitle");
            if (!luaState.isNil(-1)) {
                adConfig.setIncentivizedCancelDialogTitle(luaState.toString(-1));
            }
            luaState.pop(1);
            luaState.getField(1, "alertText");
            if (!luaState.isNil(-1)) {
                adConfig.setIncentivizedCancelDialogBodyText(luaState.toString(-1));
            }
            luaState.pop(1);
            luaState.getField(1, "alertClose");
            if (!luaState.isNil(-1)) {
                adConfig.setIncentivizedCancelDialogCloseButtonText(luaState.toString(-1));
            }
            luaState.pop(1);
            luaState.getField(1, "alertContinue");
            if (!luaState.isNil(-1)) {
                adConfig.setIncentivizedCancelDialogKeepWatchingButtonText(luaState.toString(-1));
            }
            luaState.pop(1);
            luaState.getField(1, "placement");
            if (!luaState.isNil(-1)) {
                adConfig.setPlacement(luaState.toString(-1));
            }
            luaState.pop(1);


            luaState.getField(1, "key1");
            if (!luaState.isNil(-1)) {
                adConfig.setExtra1(luaState.toString(-1));
            }
            luaState.pop(1);
            luaState.getField(1, "key2");
            if (!luaState.isNil(-1)) {
                adConfig.setExtra2(luaState.toString(-1));
            }
            luaState.pop(1);
            luaState.getField(1, "key3");
            if (!luaState.isNil(-1)) {
                adConfig.setExtra3(luaState.toString(-1));
            }
            luaState.pop(1);
            luaState.getField(1, "key4");
            if (!luaState.isNil(-1)) {
                adConfig.setExtra4(luaState.toString(-1));
            }
            luaState.pop(1);
            luaState.getField(1, "key5");
            if (!luaState.isNil(-1)) {
                adConfig.setExtra5(luaState.toString(-1));
            }
            luaState.pop(1);
            luaState.getField(1, "key6");
            if (!luaState.isNil(-1)) {
                adConfig.setExtra6(luaState.toString(-1));
            }
            luaState.pop(1);
            luaState.getField(1, "key7");
            if (!luaState.isNil(-1)) {
                adConfig.setExtra7(luaState.toString(-1));
            }
            luaState.pop(1);
            luaState.getField(1, "key8");
            if (!luaState.isNil(-1)) {
                adConfig.setExtra8(luaState.toString(-1));
            }
            luaState.pop(1);

        }
        vunglePub.playAd(adConfig);
        return 0;
    }

    private class ClearCacheWrapper implements NamedJavaFunction {
        ClearCacheWrapper() {}
        
        @Override
        public String getName() {
            return CLEAR_CACHE_METHOD;
        }
        
        // N.B. not called on UI thread
        @Override
        public int invoke(LuaState luaState) {
            return 0;
        }
    }
    
    private class ClearSleepWrapper implements NamedJavaFunction {
        ClearSleepWrapper() {}
        
        @Override
        public String getName() {
            return CLEAR_SLEEP_METHOD;
        }
        
        // N.B. not called on UI thread
        @Override
        public int invoke(LuaState luaState) {
            return 0;
        }
    }
    
    private class SetSoundEnabledWrapper implements NamedJavaFunction {
        SetSoundEnabledWrapper() {}
        
        @Override
        public String getName() {
            return SET_SOUND_ENABLED_METHOD;
        }
        
        // N.B. not called on UI thread
        @Override
        public int invoke(LuaState luaState) {
            IS_SOUND_ENABLED_DEFAULT = luaState.toBoolean(1);
            return 0;
        }
    }
    
    private class EnableLoggingWrapper implements NamedJavaFunction {
        EnableLoggingWrapper() {}
        
        @Override
        public String getName() {
            return ENABLE_LOGGING_METHOD;
        }
        
        // N.B. not called on UI thread
        @Override
        public int invoke(LuaState luaState) {
            return 0;
        }
    }
	/**
	 * @deprecated
	 */
	private class HideWrapper implements NamedJavaFunction {
		HideWrapper() {}

		@Override
		public String getName() {
			return HIDE_METHOD;
		}

		// N.B. not called on UI thread
		@Override
		public int invoke(LuaState luaState) {
			Logger.d(TAG, HIDE_METHOD + "() not implemented");
			return 0;
		}
	}

	/**
	 * Creates a base event on the input <code>luaState</code>.
	 * 
	 * @param luaState the stack on which to create the base event.
	 */
	void createBaseEvent(LuaState luaState, boolean isError) {
		CoronaLua.newEvent(luaState, CoronaLuaEvent.ADSREQUEST_TYPE);
		luaState.pushString(CORONA_AD_PROVIDER_NAME);
		luaState.setField(-2, CoronaLuaEvent.PROVIDER_KEY);
		luaState.pushBoolean(isError);
		luaState.setField(-2, CoronaLuaEvent.ISERROR_KEY);
	}

	// CoronaRuntimeListener
	@Override
	public void onLoaded(CoronaRuntime coronaRuntime) {
		if (!isLuaStateValid()) {
			Logger.v(TAG, "onLoaded(): refreshing task dispatcher");
			taskDispatcher = new CoronaRuntimeTaskDispatcher(coronaRuntime.getLuaState());
		}
	}

	// CoronaRuntimeListener
	@Override
	public void onStarted(CoronaRuntime coronaRuntime) {
	}

	// CoronaRuntimeListener
	@Override
	public void onResumed(CoronaRuntime coronaRuntime) {
		if (!isLuaStateValid()) {
			Logger.v(TAG, "onResumed(): refreshing task dispatcher");
			taskDispatcher = new CoronaRuntimeTaskDispatcher(coronaRuntime.getLuaState());
		}
		vunglePub.onResume();
	}

	/**
	 * Returns <code>true</code> if the cached Lua runtime state is valid; otherwise, 
	 * returns <code>false</code>.
	 * 
	 * @return <code>true</code> if the cached Lua runtime state is valid; otherwise, 
	 * returns <code>false</code>.
	 */
	boolean isLuaStateValid() {
		return applicationId != null && taskDispatcher != null && taskDispatcher.isRuntimeAvailable();
	}

	// CoronaRuntimeListener
	@Override
	public void onSuspended(CoronaRuntime coronaRuntime) {
		vunglePub.onPause();
	}

	// CoronaRuntimeListener
	@Override
	public void onExiting(CoronaRuntime coronaRuntime) {
		Logger.v(TAG, "onExiting(): invalidating Lua state");
		final LuaState luaState = coronaRuntime.getLuaState();
		CoronaLua.deleteRef(luaState, luaListener);
		luaListener = CoronaLua.REFNIL;
		taskDispatcher = null;
	}
}
