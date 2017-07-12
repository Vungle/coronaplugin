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
                "android.permission.ACCESS_NETWORK_STATE",
                "android.permission.WRITE_EXTERNAL_STORAGE"
            },
            usesFeatures = {},
            applicationChildElements =
            {
                [[<activity android:name="com.vungle.publisher.VideoFullScreenAdActivity"
                    android:configChanges="keyboardHidden|orientation|screenSize|screenLayout|smallestScreenSize"
                    android:theme="@android:style/Theme.NoTitleBar.Fullscreen"/>]],
                [[<activity android:name="com.vungle.publisher.MraidFullScreenAdActivity"
                    android:configChanges="keyboardHidden|orientation|screenSize|screenLayout|smallestScreenSize"
                    android:theme="@android:style/Theme.Translucent.NoTitleBar.Fullscreen"/>]],
                [[<activity android:name="com.vungle.publisher.FlexViewAdActivity"
                    android:configChanges="keyboardHidden|orientation|screenSize|screenLayout|smallestScreenSize"
                    android:theme="@android:style/Theme.Translucent.NoTitleBar.Fullscreen"/>]],
                [[<service android:name="com.vungle.publisher.VungleService" android:exported="false"/>]],
            },
        },
    },
    coronaManifest = {
        dependencies =
        { ["shared.google.play.services.ads"] = "com.coronalabs" }
    }
}

return metadata