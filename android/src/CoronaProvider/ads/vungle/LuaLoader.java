/*
 * The MIT License (MIT)
 * 
 * Copyright (c) 2013 Vungle
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
import android.util.Log;
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
import com.vungle.sdk.VunglePub;

/**
 * <p>Vungle AdsProvider plugin.</p>
 *
 * <p>Copyright &copy; 2013 Vungle.  All rights reserved.</p>
 */
public class LuaLoader implements JavaFunction, CoronaRuntimeListener {
	private static final String TAG = "Corona/Vungle";
	private static final String VERSION = "1.1.0";
	private static final Locale LOCALE = Locale.US;

	// show() ad types
//	private static final String INTERSTITIAL_AD_TYPE = "interstitial";
	private static final String INCENTIVIZED_AD_TYPE = "incentivized";

	// show() ad properties and defaults
	private static final String IS_AUTO_ROTATION_KEY = "isAutoRotation";
	private static final boolean IS_AUTO_ROTATION_DEFAULT = true;
	private static final String IS_BACK_BUTTON_ENABLED_KEY = "isBackButtonEnabled";
	private static final boolean IS_BACK_BUTTON_ENABLED_DEFAULT = false;
	private static final String IS_SOUND_ENABLED_KEY = "isSoundEnabled";
	private static final boolean IS_SOUND_ENABLED_DEFAULT = true;
	private static final String IS_CLOSE_SHOWN_KEY = "isCloseShown";
	private static final boolean IS_CLOSE_SHOWN_DEFAULT = true;
	private static final String USERNAME_KEY = "username";
	
	// events
	static final String EVENT_TYPE_KEY = "type";
	static final String AD_START_EVENT_TYPE = "adStart";
	static final String AD_VIEW_EVENT_TYPE = "adView";
	static final String AD_END_EVENT_TYPE = "adEnd";
	static final String CORONA_AD_PROVIDER_NAME = "vungle";

	private static final String DEFAULT_CORONA_APPLICATION_ID = "defaultCoronaApplicationId";

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
			new HideWrapper(),
			new InitWrapper(),
			new ShowWrapper(),
			new GetVersionStringWrapper(),
			new IsAdAvailableWrapper(),
			new ShowCacheFilesWrapper(),
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
			return "init";
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
		boolean isSuccess = false;
		final String inputApplicationId = luaState.toString(2);
		if (inputApplicationId == null) {
			Log.w(TAG, "WARNING: init() application ID was null");
		}
		else {
			applicationId = inputApplicationId;
			int listenerIndex = 3;
			if (CoronaLua.isListener(luaState, listenerIndex, CoronaLuaEvent.ADSREQUEST_TYPE)) {
				luaListener = CoronaLua.newRef(luaState, listenerIndex);
			}
			VunglePub.init(CoronaEnvironment.getApplicationContext(), inputApplicationId);
			VunglePub.setVungleBitmapFactory(BytesVungleBitmapFactory.getInstance());
			VunglePub.setEventListener(new VunglePub.EventListener() {
				@Override
				public void onVungleAdStart() {
					if (luaListener != CoronaLua.REFNIL) {
						taskDispatcher.send(
							new CoronaRuntimeTask() {
								@Override
								public void executeUsing(CoronaRuntime coronaRuntime) {
									final LuaState asyncLuaState = createBaseEvent(coronaRuntime);
									asyncLuaState.pushString(AD_START_EVENT_TYPE);
									asyncLuaState.setField(-2, EVENT_TYPE_KEY);
									try {
										CoronaLua.dispatchEvent(asyncLuaState, luaListener, 0);
									}
									catch (Exception exception) {
										Log.e(TAG, "Unable to dispatch event", exception);
									}
								}
							}
						);
					}
				}

				@Override
				public void onVungleView(final double secondsWatched, final double totalAdSeconds) {
					if (luaListener != CoronaLua.REFNIL) {
						taskDispatcher.send(
							new CoronaRuntimeTask() {
								@Override
								public void executeUsing(CoronaRuntime coronaRuntime) {
									final LuaState asyncLuaState = createBaseEvent(coronaRuntime);
									asyncLuaState.pushString(AD_VIEW_EVENT_TYPE);
									asyncLuaState.setField(-2, EVENT_TYPE_KEY);
									asyncLuaState.pushNumber(secondsWatched);
									asyncLuaState.setField(-2, "secondsWatched");
									asyncLuaState.pushNumber(totalAdSeconds);
									asyncLuaState.setField(-2, "totalAdSeconds");
									try {
										CoronaLua.dispatchEvent(asyncLuaState, luaListener, 0);
									}
									catch (Exception exception) {
										Log.e(TAG, "Unable to dispatch event", exception);
									}
								}
							}
						);
					}
				}

				@Override
				public void onVungleAdEnd() {
					if (luaListener != CoronaLua.REFNIL) {
						taskDispatcher.send(
							new CoronaRuntimeTask() {
								@Override
								public void executeUsing(CoronaRuntime coronaRuntime) {
									final LuaState asyncLuaState = createBaseEvent(coronaRuntime);
									asyncLuaState.pushString(AD_END_EVENT_TYPE);
									asyncLuaState.setField(-2, EVENT_TYPE_KEY);
									try {
										CoronaLua.dispatchEvent(asyncLuaState, luaListener, 0);
									}
									catch (Exception exception) {
										Log.e(TAG, "Unable to dispatch event", exception);
									}
								}
							}
						);
					}
				}

				private LuaState createBaseEvent(CoronaRuntime coronaRuntime) {
					final LuaState currentLuaState = coronaRuntime.getLuaState();
					LuaLoader.this.createBaseEvent(currentLuaState);
					currentLuaState.pushBoolean(false);
					currentLuaState.setField(-2, CoronaLuaEvent.ISERROR_KEY);
					return currentLuaState;
				}
			});
			VunglePub.onResume();
			isSuccess = true;
		}
		luaState.pushBoolean(isSuccess);
		return 1;
	}

	/**
	 * Returns <code>true</code> if the cached Lua runtime state is valid; otherwise, 
	 * returns <code>false</code>.
	 * 
	 * @return <code>true</code> if the cached Lua runtime state is valid; otherwise, 
	 * returns <code>false</code>.
	 */
	protected boolean isLuaStateValid() {
		return applicationId != null && taskDispatcher != null && taskDispatcher.isRuntimeAvailable();
	}
	
	private class GetVersionStringWrapper implements NamedJavaFunction {
		private GetVersionStringWrapper() {}

		@Override
		public String getName() {
			return "getVersionString";
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
	 * @return <code>1</code>
	 */
	public int getVersionString(LuaState luaState) {
		final String version = VERSION + " (" + VunglePub.getVersionString() + ")";
		luaState.pushString(version);
		return 1;
	}

	private class ShowCacheFilesWrapper implements NamedJavaFunction {
		private ShowCacheFilesWrapper() {}

		@Override
		public String getName() {
			return "showCacheFiles";
		}

		// N.B. not called on UI thread
		@Override
		public int invoke(LuaState luaState) {
			return showCacheFiles(luaState);
		}
	}

	/**
	 * <p>Not implemented.</p>
	 * 
	 * @param luaState
	 * @return <code>0</code> (the number of return values).
	 */
	public int showCacheFiles(LuaState luaState) {
		Log.d(TAG, "showCacheFiles() not implemented");
		return 0;
	}
	
	private class IsAdAvailableWrapper implements NamedJavaFunction {
		private IsAdAvailableWrapper() {}

		@Override
		public String getName() {
			return "isAdAvailable";
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
	 * @param luaState [1: isDebug - if enabled, prints reason for ad unavailbility to log cat (optional)]
	 * @return <code>1</code> (the number of return values).
	 */
	public int isAdAvailable(LuaState luaState) {
		final boolean isDebug = (luaState.getTop() > 0 ? luaState.toBoolean(1) : false);
		luaState.pushBoolean(
			VunglePub.isVideoAvailable(isDebug));
		return 1;
	}

	private class ShowWrapper implements NamedJavaFunction {
		private ShowWrapper() {}

		@Override
		public String getName() {
			return "show";
		}
		
		// N.B. not called on UI thread
		@Override
		public int invoke(LuaState luaState) {
			return show(luaState);
		}
	}
	
	/**
	 * <p>Show an ad, please. Thanks.</p>
	 * 
	 * <p>In Lua, returns <code>true</code> if an ad was displayed; otherwise, returns <code>false</code>.</p>
	 * 
	 * @param luaState [1: "interstitial" || "incentivized", 
	 *                  2: {
	 *                       isAnimated:           true* || false   (ignored),
	 *                       isAutoRotation:       true* || false,
	 *                       isBackButtonEnabled:  true || false*,
	 *                       isSoundEnabled:       true* || false,
	 *                       username:             string          (optional, only used for incentivized ad type),
	 *                       isCloseShown:         true* || false  (only used for incentivized ad type)
	 *                     }
	 * @return <code>1</code>.
	 */
	public int show(LuaState luaState) {
		final String METHOD_NAME = "show(): ";
		boolean wasAdDisplayed;
		if (VunglePub.isVideoAvailable()) {
			final int AD_TYPE_INDEX = 1;
			final int PARAM_TABLE_INDEX = 2;
			final int numberOfArguments = luaState.getTop();
			// get the lower case ad type if it exists:
			final String adType = 
				(numberOfArguments >= AD_TYPE_INDEX ? 
					(luaState.toString(AD_TYPE_INDEX) == null ?
						null : 
						luaState.toString(AD_TYPE_INDEX).toLowerCase(LOCALE)) :
					null);
			Log.v(TAG, METHOD_NAME + "adType = " + adType);
			boolean isAutoRotation = IS_AUTO_ROTATION_DEFAULT;
			boolean isBackButtonEnabled = IS_BACK_BUTTON_ENABLED_DEFAULT;
			boolean isSoundEnabled = IS_SOUND_ENABLED_DEFAULT;
			if (numberOfArguments >= PARAM_TABLE_INDEX && luaState.isTable(PARAM_TABLE_INDEX)) {
				luaState.getField(PARAM_TABLE_INDEX, IS_AUTO_ROTATION_KEY);
				if (!luaState.isNil(-1)) {
					isAutoRotation = luaState.toBoolean(-1);
					Log.v(TAG, METHOD_NAME + "isAutoRotation = " + isAutoRotation);
				}
				else {
					Log.v(TAG, METHOD_NAME + "isAutoRotation = " + isAutoRotation + " (default)");
				}
				luaState.pop(1);

				luaState.getField(PARAM_TABLE_INDEX, IS_BACK_BUTTON_ENABLED_KEY);
				if (!luaState.isNil(-1)) {
					isBackButtonEnabled = luaState.toBoolean(-1);
					Log.v(TAG, METHOD_NAME + "isBackButtonEnabled = " + isBackButtonEnabled);
				}
				else {
					Log.v(TAG, METHOD_NAME + "isBackButtonEnabled = " + isBackButtonEnabled + " (default)");
				}
				luaState.pop(1);

				luaState.getField(PARAM_TABLE_INDEX, IS_SOUND_ENABLED_KEY);
				if (!luaState.isNil(-1)) {
					isSoundEnabled = luaState.toBoolean(-1);
					Log.v(TAG, METHOD_NAME + "isSoundEnabled = " + isSoundEnabled);
				}
				else {
					Log.v(TAG, METHOD_NAME + "isSoundEnabled = " + isSoundEnabled + " (default)");
				}
				luaState.pop(1);
			}
			VunglePub.setAutoRotation(isAutoRotation);
			VunglePub.setSoundEnabled(isSoundEnabled);
			// incentivized
			if (INCENTIVIZED_AD_TYPE.equals(adType)) {
				VunglePub.setIncentivizedBackButtonEnabled(isBackButtonEnabled);
				boolean isCloseShown = IS_CLOSE_SHOWN_DEFAULT;
				luaState.getField(PARAM_TABLE_INDEX, IS_CLOSE_SHOWN_KEY);
				if (!luaState.isNil(-1)) {
					isCloseShown = luaState.toBoolean(-1);
					Log.v(TAG, METHOD_NAME + "isCloseShown = " + isCloseShown);
				}
				else {
					Log.v(TAG, METHOD_NAME + "isCloseShown = " + isCloseShown + " (default)");
				}
				luaState.pop(1);

				String username = null; 
				luaState.getField(PARAM_TABLE_INDEX, USERNAME_KEY);
				if (!luaState.isNil(-1)) {
					username = luaState.toString(-1);
				}
				Log.v(TAG, METHOD_NAME + "username = " + username);
				luaState.pop(1);

				wasAdDisplayed = VunglePub.displayIncentivizedAdvert(username, isCloseShown);
			}
			// interstitial
			else {
				VunglePub.setBackButtonEnabled(isBackButtonEnabled);
				wasAdDisplayed = VunglePub.displayAdvert();
			}
		}
		else {
			createBaseEvent(luaState);
			luaState.pushString(AD_START_EVENT_TYPE);
			luaState.setField(-2, EVENT_TYPE_KEY);
			luaState.pushBoolean(true);
			luaState.setField(-2, CoronaLuaEvent.ISERROR_KEY);
			luaState.pushString("Ad not available");
			luaState.setField(-2, CoronaLuaEvent.RESPONSE_KEY);
			try {
				CoronaLua.dispatchEvent(luaState, luaListener, 0);
			}
			catch (Exception exception) {
				Log.e(TAG, METHOD_NAME + "Unable to dispatch event", exception);
			}
			wasAdDisplayed = false;
		}
		luaState.pushBoolean(wasAdDisplayed);
		return 1;
	}
	
	private class HideWrapper implements NamedJavaFunction {
		private HideWrapper() {}
		
		@Override
		public String getName() {
			return "hide";
		}

		// N.B. not called on UI thread
		@Override
		public int invoke(LuaState luaState) {
			return 0;
		}
	}

	/**
	 * <p>Not implemented.</p>
	 * 
	 * @param luaState
	 * @return <code>0</code> (the number of return values).
	 */
	public int hide(LuaState luaState) {
		Log.d(TAG, "hide() not implemented");
		return 0;
	}

	/**
	 * Creates a base event on the input <code>luaState</code>.
	 * 
	 * @param luaState the stack on which to create the base event.
	 */
	void createBaseEvent(LuaState luaState) {
		CoronaLua.newEvent(luaState, CoronaLuaEvent.ADSREQUEST_TYPE);
		luaState.pushString(CORONA_AD_PROVIDER_NAME);
		luaState.setField(-2, CoronaLuaEvent.PROVIDER_KEY);
	}
	
	// CoronaRuntimeListener
	@Override
	public void onLoaded(CoronaRuntime coronaRuntime) {
		if (!isLuaStateValid()) {
			Log.v(TAG, "onLoaded(): refreshing task dispatcher");
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
			Log.v(TAG, "onResumed(): refreshing task dispatcher");
			taskDispatcher = new CoronaRuntimeTaskDispatcher(coronaRuntime.getLuaState());
		}
		VunglePub.onResume();
	}

	// CoronaRuntimeListener
	@Override
	public void onSuspended(CoronaRuntime coronaRuntime) {
		VunglePub.onPause();
	}

	// CoronaRuntimeListener
	@Override
	public void onExiting(CoronaRuntime coronaRuntime) {
		Log.v(TAG, "onExiting(): invalidating Lua state");
		final LuaState luaState = coronaRuntime.getLuaState();
		CoronaLua.deleteRef(luaState, luaListener);
		luaListener = CoronaLua.REFNIL;
		taskDispatcher = null;
	}
}
