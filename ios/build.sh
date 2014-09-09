#!/bin/sh

IOS_SDK=7.1
CORONA_RELEASE=2014.2264

xcodebuild -target ads-vungle -sdk iphoneos${IOS_SDK} -project Plugin.xcodeproj clean
xcodebuild -target ads-vungle -sdk iphonesimulator${IOS_SDK} -project Plugin.xcodeproj clean
xcodebuild -target ads-vungle -sdk iphoneos${IOS_SDK} -project Plugin.xcodeproj build
xcodebuild -target ads-vungle -sdk iphonesimulator${IOS_SDK} -project Plugin.xcodeproj build
cp build/Release-iphoneos/libads-vungle.a ../release/plugins/${CORONA_RELEASE}/iphone/libads-vungle.a
cp build/Release-iphonesimulator/libads-vungle.a ../release/plugins/${CORONA_RELEASE}/iphone-sim/libads-vungle.a
