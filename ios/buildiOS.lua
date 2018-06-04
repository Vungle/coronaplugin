local params = {
	platform='ios',
	appName='VungleCoronaTest',
	appVersion='6.2.1585492',
	dstPath='/tmp/jenkins/workspace/Mobile_Corona_Test_App/coronaplugin/ios',
	projectPath='/tmp/jenkins/workspace/Mobile_Corona_Test_App/corona-test-app/app',
--	dstPath='/Users/admin/work/corona-build/coronaplugin/ios',
--	projectPath='/Users/admin/work/corona-build/corona-test-app/app',
	subscription='enterprise',
	certificatePath='/Users/administrator/Library/MobileDevice/Provisioning Profiles/04c6cb0d-a6c3-410d-a0ed-de4418d2266c.mobileprovision',
--	certificatePath='/Users/admin/Library/MobileDevice/Provisioning Profiles/04c6cb0d-a6c3-410d-a0ed-de4418d2266c.mobileprovision',
}
return params;
