local metadata =
{
    plugin =
    {
        format = 'jar',
        manifest = 
        {
            permissions = {},
            usesPermissions =
            {
                "android.permission.INTERNET",
                "android.permission.WRITE_EXTERNAL_STORAGE",
                "android.permission.ACCESS_NETWORK_STATE"
            },
            usesFeatures = {},
            applicationChildElements =
            {
                [[<activity android:name="com.vungle.warren.ui.VungleActivity"
                    android:configChanges="keyboardHidden|orientation|screenSize|screenLayout|smallestScreenSize"
                    android:launchMode="singleTop"
                    android:theme="@android:style/Theme.NoTitleBar.Fullscreen"/>]],
                [[<activity android:name="com.vungle.warren.ui.VungleFlexViewActivity"
                    android:configChanges="keyboardHidden|orientation|screenSize|screenLayout|smallestScreenSize"
                    android:launchMode="singleTop"
                    android:theme="@android:style/Theme.Translucent.NoTitleBar"/>]], 
            },
        },
    },
    coronaManifest = {
        dependencies =
        { 
    	    ["shared.android.support.v4"] = "com.coronalabs" 
    	}
    }
}

return metadata
