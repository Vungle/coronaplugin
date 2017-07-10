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
package plugin.vungle;

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
import com.vungle.publisher.*;
import com.vungle.publisher.env.WrapperFramework;
import com.vungle.publisher.inject.Injector;
import android.util.Log;
import java.util.*;

/**
 * <p>Vungle AdsProvider plugin.</p>
 */
public class LuaLoader implements JavaFunction, CoronaRuntimeListener {
	private static final String TAG = "VungleCorona";
	private static final String VERSION = "2.3.2";//plugin version. Do not delete this comment
	private static final Locale LOCALE = Locale.US;

	// LUA method names
	static final String GET_VERSION_STRING_METHOD = "getVersionString";
	static final String INIT_METHOD = "init";
	static final String IS_AD_AVAILABLE_METHOD = "isAdAvailable";
	static final String SHOW_METHOD = "show";
    static final String LOAD_METHOD = "load";
    static final String CLEAR_CACHE_METHOD = "clearCache";
    static final String CLEAR_SLEEP_METHOD = "clearSleep";
    static final String ENABLE_LOGGING_METHOD = "enableLogging";

	// events
	static final String EVENT_TYPE_KEY = "type";
	static final String AD_START_EVENT_TYPE = "adStart";
    static final String AD_END_EVENT_TYPE = "adEnd";
	static final String AD_UNABLE_TYPE = "unableToPlayAd";
    static final String AD_AVAILABLE_EVENT_TYPE = "adAvailable";
    static final String AD_INITIALIZE_TYPE = "adInitialize";
    static final String AD_INIT_FAILURE_TYPE = "adInitFailure";

    static final String AD_VIEW_IS_COMPLETED_VIEW_KEY = "completedView";
    static final String AD_PLACEMENT_ID_KEY = "placementID";
	static final String AD_VIEW_SECONDS_WATCHED_KEY = "secondsWatched";
	static final String AD_VIEW_TOTAL_AD_SECONDS_KEY = "totalAdSeconds";
	static final String CORONA_AD_PROVIDER_NAME = "vungle";
	static final String WAS_CALL_TO_ACTION_CLICKED_KEY = "didDownload";
    static final String IS_AD_AVAILABLE_KEY = "isAdPlayable";
    
    static final String AD_REASON_KEY = "reason";

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
			new InitWrapper(),
			new IsAdAvailableWrapper(),
			new ShowWrapper(),
            new LoadWrapper(),
            new ClearCacheWrapper(),
            new ClearSleepWrapper(),
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
	 * @param luaState [1: pluginName,
     *                  2: pubAppId,placementIds,
	 *                  3: listener (optional)]
	 * @return <code>1</code> (the number of return values).
	 */
	public int init(LuaState luaState) {
		int nextArg = 1;
		final String provider = luaState.toString(nextArg);
		if(provider!=null && provider.equals("vungle")) {
			// skip legacy provider name
			nextArg++;
		}

        final String params = luaState.toString(nextArg++);
        
        final String[] parts = params.split(",");
        if (parts.length == 0)
            return 0;
        final String applicationId = this.applicationId = parts[0];
        List<String> placements_tmp = new ArrayList<String>();
        for (int i = 1; i < parts.length; i++)
            placements_tmp.add(parts[i].trim());
        
        final String[] placements = placements_tmp.toArray(new String[placements_tmp.size()]);

        /*
		final String applicationId = this.applicationId = luaState.toString(2);
		if (applicationId == null) {
			Log.w(TAG, "WARNING: " + INIT_METHOD + "() application ID was null");
            luaState.pushBoolean(false);
            return 1;
		}
        List<String> placements_tmp = new ArrayList<String>();
        int luaTableStackIndex = 3;
        luaState.checkType(luaTableStackIndex, com.naef.jnlua.LuaType.TABLE);
        int arrayLength = luaState.length(luaTableStackIndex);
        if (arrayLength > 0)
            for (int index = 1; index <= arrayLength; index++) {
                luaState.rawGet(luaTableStackIndex, index);
                placements_tmp.add(luaState.toString(-1));
                luaState.pop(1);
            }
        final String[] placements = placements_tmp.toArray(new String[placements_tmp.size()]);
         */
        
		if (CoronaLua.isListener(luaState, nextArg, CoronaLuaEvent.ADSREQUEST_TYPE)) {
			luaListener = CoronaLua.newRef(luaState, nextArg);
		}
		nextArg++;
        
		final Context applicationContext = CoronaEnvironment.getApplicationContext();
		final Injector injector = Injector.getInstance();
		injector.setWrapperFramework(WrapperFramework.corona);
		injector.setWrapperFrameworkVersion(VERSION);
		final VunglePub vunglePub = this.vunglePub;
		CoronaEnvironment.getCoronaActivity().runOnUiThread(new Runnable() {
			@Override
			public void run() {
                vunglePub.init(applicationContext, applicationId, placements, new VungleInitListener() {
                    @Override
                    public void onSuccess() {
                        if (luaListener != CoronaLua.REFNIL)
                            taskDispatcher.send(new CoronaRuntimeTask() {
                                @Override
                                public void executeUsing(CoronaRuntime coronaRuntime) {
                                    final String eventType = AD_INITIALIZE_TYPE;
                                    try {
                                        final LuaState asyncLuaState = createBaseEvent(coronaRuntime, eventType, false);
                                        CoronaLua.dispatchEvent(asyncLuaState, luaListener, 0);
                                    } catch (Exception exception) {
                                        Log.e(TAG, "Unable to dispatch event " + eventType, exception);
                                    }
                                }
                            });
                        vunglePub.addEventListeners(new VungleAdEventListener() {
                            @Override
                            public void onAdStart(final String placementId) {
                                if (luaListener == CoronaLua.REFNIL) return;
                                taskDispatcher.send(new CoronaRuntimeTask() {
                                    @Override
                                    public void executeUsing(CoronaRuntime coronaRuntime) {
                                        final String eventType = AD_START_EVENT_TYPE;
                                        try {
                                            final LuaState asyncLuaState = createBaseEvent(coronaRuntime, eventType, false);
                                            asyncLuaState.pushString(placementId);
                                            asyncLuaState.setField(-2, AD_PLACEMENT_ID_KEY);
                                            CoronaLua.dispatchEvent(asyncLuaState, luaListener, 0);
                                        } catch (Exception exception) {
                                            Log.e(TAG, "Unable to dispatch event " + eventType, exception);
                                        }
                                    }
                                });
                            }
                            @Override
                            public void onAdEnd(final String placementId, final boolean wasSuccessfulView, final boolean wasCallToActionClicked) {
                                if (luaListener == CoronaLua.REFNIL) return;
                                taskDispatcher.send(new CoronaRuntimeTask() {
                                    @Override
                                    public void executeUsing(CoronaRuntime coronaRuntime) {
                                        final String eventType = AD_END_EVENT_TYPE;
                                        try {
                                            final LuaState asyncLuaState = createBaseEvent(coronaRuntime, eventType, false);
                                            asyncLuaState.pushString(placementId);
                                            asyncLuaState.setField(-2, AD_PLACEMENT_ID_KEY);
                                            
                                            asyncLuaState.pushBoolean(wasSuccessfulView);
                                            asyncLuaState.setField(-2, AD_VIEW_IS_COMPLETED_VIEW_KEY);
                                            
                                            asyncLuaState.pushBoolean(wasCallToActionClicked);
                                            asyncLuaState.setField(-2, WAS_CALL_TO_ACTION_CLICKED_KEY);
                                            CoronaLua.dispatchEvent(asyncLuaState, luaListener, 0);
                                        } catch (Exception exception) {
                                            Log.e(TAG, "Unable to dispatch event " + eventType, exception);
                                        }
                                    }
                                });
                            }
                            @Override
                            public void onUnableToPlayAd(final String placementId, final String reason) {
                                if (luaListener == CoronaLua.REFNIL) return;
                                taskDispatcher.send(new CoronaRuntimeTask() {
                                    @Override
                                    public void executeUsing(CoronaRuntime coronaRuntime) {
                                        final String eventType = AD_UNABLE_TYPE;
                                        try {
                                            final LuaState asyncLuaState = createBaseEvent(coronaRuntime, eventType, false);
                                            asyncLuaState.pushString(placementId);
                                            asyncLuaState.setField(-2, AD_PLACEMENT_ID_KEY);
                                            
                                            asyncLuaState.pushString(reason);
                                            asyncLuaState.setField(-2, AD_REASON_KEY);
                                            CoronaLua.dispatchEvent(asyncLuaState, luaListener, 0);
                                        } catch (Exception exception) {
                                            Log.e(TAG, "Unable to dispatch event " + eventType, exception);
                                        }
                                    }
                                });
                            }
                            @Override
                            public void onAdAvailabilityUpdate(final String placementId, final boolean isAdAvailable) {
                                if (luaListener == CoronaLua.REFNIL) return;
                                taskDispatcher.send(new CoronaRuntimeTask() {
                                    @Override
                                    public void executeUsing(CoronaRuntime coronaRuntime) {
                                        final String eventType = AD_AVAILABLE_EVENT_TYPE;
                                        try {
                                            final LuaState asyncLuaState = createBaseEvent(coronaRuntime, eventType, false);
                                            asyncLuaState.pushString(placementId);
                                            asyncLuaState.setField(-2, AD_PLACEMENT_ID_KEY);
                                            
                                            asyncLuaState.pushBoolean(isAdAvailable);
                                            asyncLuaState.setField(-2, IS_AD_AVAILABLE_KEY);
                                            CoronaLua.dispatchEvent(asyncLuaState, luaListener, 0);
                                        } catch (Exception exception) {
                                            Log.e(TAG, "Unable to dispatch event " + eventType, exception);
                                        }
                                    }
                                });
                            }
                        });
                    }
                    @Override
                    public void onFailure(Throwable error) {
                        if (luaListener == CoronaLua.REFNIL) return;
                        taskDispatcher.send(new CoronaRuntimeTask() {
                            @Override
                            public void executeUsing(CoronaRuntime coronaRuntime) {
                                final String eventType = AD_INIT_FAILURE_TYPE;
                                try {
                                    final LuaState asyncLuaState = createBaseEvent(coronaRuntime, eventType, false);
                                    CoronaLua.dispatchEvent(asyncLuaState, luaListener, 0);
                                } catch (Exception exception) {
                                    Log.e(TAG, "Unable to dispatch event " + eventType, exception);
                                }
                            }
                        });
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
		luaState.pushBoolean(true);
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

	private class IsAdAvailableWrapper implements NamedJavaFunction {
		IsAdAvailableWrapper() {}

		@Override
		public String getName() {
			return IS_AD_AVAILABLE_METHOD;
		}

		// N.B. not called on UI thread
		@Override
		public int invoke(LuaState luaState) {
			return isAdAvailable(luaState);
		}
	}
	/**
	 * <p>Returns <code>true</code> if an ad is available; otherwise, returns <code>false</code>.</p>
	 * 
	 * @param luaState
	 * @return <code>1</code> (the number of return values).
	 */
	public int isAdAvailable(LuaState luaState) {
        final String placementId = luaState.toString(1);

		luaState.pushBoolean(vunglePub.isAdPlayable(placementId));
		return 1;
	}
    
    private class LoadWrapper implements NamedJavaFunction {
        LoadWrapper() {}
        
        @Override
        public String getName() {
            return LOAD_METHOD;
        }
        
        // N.B. not called on UI thread
        @Override
        public int invoke(LuaState luaState) {
            return load(luaState);
        }
    }
    public int load(LuaState luaState) {
        final String placementId = luaState.toString(1);
        
        vunglePub.loadAd(placementId);
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
    
    public int show(LuaState luaState) {
        final String METHOD_NAME = SHOW_METHOD + "(): ";
        final AdConfig adConfig = new AdConfig();
        final int numberOfArguments = luaState.getTop();
        String placementId = "";
        // get the lower case ad type if it exists:
        if (numberOfArguments >= 1 && luaState.isTable(1)) {
            luaState.getField(1, "placementId");
            if (luaState.isNil(-1)) {
                return -1;
            }
            placementId = luaState.toString(-1);
            luaState.pop(1);
            luaState.getField(1, "isAutoRotation");
            if (!luaState.isNil(-1)) {
                adConfig.setOrientation(luaState.toBoolean(-1) ? Orientation.autoRotate : Orientation.matchVideo);
            }
            luaState.pop(1);
            luaState.getField(1, "isSoundEnabled");
            if (!luaState.isNil(-1)) {
                adConfig.setSoundEnabled(luaState.toBoolean(-1));
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
/*
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
 */
        }
        vunglePub.playAd(placementId, adConfig);
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
			Log.d(TAG, "onLoaded(): refreshing task dispatcher");
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
			Log.d(TAG, "onResumed(): refreshing task dispatcher");
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
		Log.d(TAG, "onExiting(): invalidating Lua state");
		final LuaState luaState = coronaRuntime.getLuaState();
		CoronaLua.deleteRef(luaState, luaListener);
		luaListener = CoronaLua.REFNIL;
		taskDispatcher = null;
	}
}
