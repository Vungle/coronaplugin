local params = {
	platform='Android',
	appName='VungleCoronaTest',
	appVersion='6.2.235486',
	dstPath='/tmp/jenkins/workspace/Mobile_Corona_Test_App/coronaplugin/android',
	projectPath='/tmp/jenkins/workspace/Mobile_Corona_Test_App/corona-test-app/app',
	subscription='enterprise',
	sdkPath='/Applications/android-sdk',
--	dstPath='/Users/admin/work/corona-build/coronaplugin/android',
--	projectPath='/Users/admin/work/corona-build/corona-test-app/app',
--	subscription='enterprise',
--	sdkPath='/Users/admin/Library/Android/sdk',
	androidVersionCode='6',
	androidAppPackage='com.vungle.VungleCoronaTest'
}
return params;
