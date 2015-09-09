local metadata =
{
	plugin =
	{
		format = 'staticLibrary',

		-- This is the name without the 'lib' prefix.
		-- In this case, the static library is called: libSTATIC_LIB_NAME.a
		staticLibs = { 'ads-vungle', 'z'}, 

		frameworks = {'AVFoundation', 'CFNetwork', 'CoreGraphics', 'AudioToolbox', 'Accounts', 'AdSupport', 'CoreMedia',
				   'Foundation', 'MediaPlayer', 'QuartzCore', 'SystemConfiguration', 'StoreKit'},
		frameworksOptional = {'CoreLocation'},
	},
}

return metadata