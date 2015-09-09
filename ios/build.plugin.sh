#!/bin/sh

IOS_SDK=8.2
CORONA_RELEASES="2013.1137 2014.2264 2014.2430"

xcodebuild -target ads-vungle -sdk iphoneos${IOS_SDK} -project Plugin.xcodeproj clean
xcodebuild -target ads-vungle -sdk iphonesimulator${IOS_SDK} -project Plugin.xcodeproj clean
xcodebuild -target ads-vungle -sdk iphoneos${IOS_SDK} -project Plugin.xcodeproj build
xcodebuild -target ads-vungle -sdk iphonesimulator${IOS_SDK} -project Plugin.xcodeproj build
for version in $CORONA_RELEASES; do
	cp build/Release-iphoneos/libads-vungle.a ../plugins/${version}/iphone/libads-vungle.a
	cp build/Release-iphonesimulator/libads-vungle.a ../plugins/${version}/iphone-sim/libads-vungle.a
done
