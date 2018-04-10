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
                "android.permission.WAKE_LOCK",
                "android.permission.ACCESS_NETWORK_STATE",
                "android.permission.RECEIVE_BOOT_COMPLETED"
            },
            usesFeatures = {},
            applicationChildElements =
            {
                [[<activity android:name="com.vungle.warren.ui.VungleActivity"
                    android:configChanges="keyboardHidden|orientation|screenSize|screenLayout|smallestScreenSize"
                    android:launchMode="singleTop"
                    android:theme="@android:style/Theme.Translucent.NoTitleBar"/>]],
                [[<service android:name="com.evernote.android.job.v21.PlatformJobService" android:exported="false" android:permission="android.permission.BIND_JOB_SERVICE"/>]],
                [[<service android:name="com.evernote.android.job.v14.PlatformAlarmService" android:exported="false" android:permission="android.permission.BIND_JOB_SERVICE" />]],
                [[<service android:name="com.evernote.android.job.v14.PlatformAlarmServiceExact" android:exported="false"/>]],
                [[<receiver android:name="com.evernote.android.job.v14.PlatformAlarmReceiver" android:exported="false" >
                    <intent-filter>
                        <action android:name="com.evernote.android.job.v14.RUN_JOB" />
                        <action android:name="net.vrallev.android.job.v14.RUN_JOB" />
                    </intent-filter>
                </receiver>]],
                [[<receiver android:name="com.evernote.android.job.JobBootReceiver" android:exported="false" >
                    <intent-filter>
                        <action android:name="android.intent.action.BOOT_COMPLETED" />
                        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
                        <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
                    </intent-filter>
                </receiver>]],
                [[<service android:name="com.evernote.android.job.gcm.PlatformGcmService" android:enabled="false" android:exported="true" android:permission="com.google.android.gms.permission.BIND_NETWORK_TASK_SERVICE" >
                    <intent-filter>
                        <action android:name="com.google.android.gms.gcm.ACTION_TASK_READY" />
                    </intent-filter>
                </service>]],
                [[<service android:name="com.evernote.android.job.JobRescheduleService" android:exported="false" android:permission="android.permission.BIND_JOB_SERVICE" />]],
            },
        },
    },
    coronaManifest = {
        dependencies =
        { 
    	    ["shared.google.play.services.ads"] = "com.coronalabs",
    	    ["shared.android.support.v4"] = "com.coronalabs" 
    	}
    }
}

return metadata
