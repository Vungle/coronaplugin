--==================================================================================================
-- 
-- Vungle Video Ads Sample Project
-- 
-- This project demonstrates how to use Vungle video ads with the Corona's 'ads' library.
--
-- IMPORTANT: You must get your own "app ID" from Vungle (https://v.vungle.com/dashboard/signup).  
-- Further, you must build for device to properly test this sample, because "ads" library is not 
-- supported by the Corona Simulator.
--
--   1. Get your app ID from Vungle
--   2. Modify the code below to use your own app ID 
--   3. Build and deploy on device
--
-- The code below demonstrates how to display a Vungle video ad and how to create a listener 
-- to handle the case when an pre-cached video ad is not available to display.
--
-- Version: 2.0.2 (August 21, 2014)
-- Version: 1.0.0 (July 15, 2013)
--
-- Sample code is MIT licensed, see http://www.coronalabs.com/links/code/license
-- Copyright (c) 2012 Corona Labs Inc.  All Rights Reserved.
-- Copyright (c) 2013 Vungle.  All Rights Reserved.
-- 
--==================================================================================================

--==================================================================================================
-- Utility
--==================================================================================================

function vardump(value, depth, key)
	local linePrefix = ""
	local spaces = ""

	if key ~= nil then
		linePrefix = "["..key.."] = "
	end

	if depth == nil then
		depth = 0
	else
		depth = depth + 1
		for i=1, depth do spaces = spaces .. "  " end
	end

	if type(value) == 'table' then
		mTable = getmetatable(value)
		if mTable == nil then
			print(spaces ..linePrefix.."(table) ")
		else
			print(spaces .."(metatable) ")
			value = mTable
		end
		for tableKey, tableValue in pairs(value) do
			vardump(tableValue, depth, tableKey)
		end
	elseif type(value)    == 'function' or
		type(value)       == 'thread' or
		type(value)       == 'userdata' or
		value             == nil
	then
		print(spaces..tostring(value))
	else
		print(spaces..linePrefix.."("..type(value)..") "..tostring(value))
	end
end

--==================================================================================================
-- Initial configuration and load Corona 'ads' library
--==================================================================================================

-- hides the status bar
display.setStatusBar( display.HiddenStatusBar )

-- the name of the ad provider
-- Corona uses this value to construct the name of the plugin.
-- Corona then asks Lua to load a module with the name "CoronaProvider.ads.[provider]"
local provider = "vungle"

-- replace with your own Vungle application ID
local appId = "vungleTest"

-- load Corona 'ads' library
local ads = require "ads"

--==================================================================================================
-- Show video ad function and event listener
--==================================================================================================

-- create a text object to display ad status
local statusText = display.newText("", 0, 0, native.systemFontBold, 22 )

-- show an ad if one has been downloaded and is available for playback
function showAd()
	ads.show( "interstitial", { isBackButtonEnabled = false } )
end

-- event table includes:
--		event.name		=	'adsRequest'
--		event.provider	=	'vungle'
--		event.type			(string - e.g. 'adStart', 'adView', 'adEnd', 'cachedAdAvailable')
--		event.isError		(boolean)
--		event.response		(string)

-- create a 'function' ad listener
function functionAdListener( event )
	print("Received event:")
	vardump( event )
	-- video ad downloaded and available
	if event.type == "cachedAdAvailable" then
		showAd()
	-- video ad displayed and then closed
	elseif event.type == "adEnd" then
		statusText.text = "Hope you enjoyed the video!"
		statusText.x = display.contentWidth * 0.5
	end
end

-- or create a 'table' ad listener
local tableAdListener = {}
function tableAdListener:adsRequest(event)
	functionAdListener(event)
end

--==================================================================================================
-- Initialize 'ads' library and Vungle video ad provider
--==================================================================================================

-- use function ad listener
ads.init( provider, appId, functionAdListener )

-- use table ad listener
-- ads.init( provider, appId, tableAdListener )

--==================================================================================================
-- UI
--==================================================================================================

-- initial variables
local sysModel = system.getInfo("model")
local sysEnv = system.getInfo("environment")

-- create a background for the app
local backgroundImg = display.newImageRect( "space.png", display.contentWidth, display.contentHeight )
backgroundImg.x, backgroundImg.y = display.contentCenterX, display.contentCenterY

-- set up text object
statusText:setTextColor( 255 )
statusText.x, statusText.y = display.contentWidth * 0.5, 160
statusText:toFront()

-- if on simulator, message user that they must build for device
if sysEnv == "simulator" then
	local font, size = native.systemFontBold, 22
	local warningText = display.newRetinaText( "Please build for device or Xcode simulator to test this sample.", 0, 0, 290, 300, font, size )
	warningText:setTextColor( 255 )
	warningText:setReferencePoint( display.CenterReferencePoint )
	warningText.x, warningText.y = display.contentWidth * 0.5, display.contentHeight * 0.5
else
	statusText.text = "Downloading video ad ..."
	statusText.x = display.contentWidth * 0.5
end
