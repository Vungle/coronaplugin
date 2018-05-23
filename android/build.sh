#!/bin/sh

CORONA_RELEASES="2017.3081"
if [ -f ../version.ver ]; then
    version=$(cat ../version.ver)
else
    version="1.0"
fi
echo "Version:" $version
d1=$(date +%s)
#25.05.2015 16:00 MSK
build=$(expr $d1 / 60 - 25225980)
echo "Build:" $build

code=$(expr "$version" : '\([0-9]*\)')
echo "Code:" $code
        
sed -E -i .bak "s/versionName \"[0-9]+\.[0-9]+\.[0-9]+\"/versionName \"$version.$build\"/g" ./app/build.gradle
sed -E -i .bak "s/versionCode [0-9]+/versionCode $code/g" ./app/build.gradle
        
#Update plugin version in the LuaLoader.java according to plugin_version.txt file
pluginVersion=$(cat ../plugin_version.txt)
sub="\"$pluginVersion\";//plugin version. Do not delete this comment"
sed -E -i .bak "s#\"[0-9]+\.[0-9]+\.[0-9]+\";//plugin version. Do not delete this comment#$sub#g" plugin/src/main/java/plugin/vungle/LuaLoader.java
rm plugin/src/main/java/plugin/vungle/LuaLoader.java.bak

./gradlew build

#[ -f ./plugin.vungle.jar ] && rm ./plugin.vungle.jar
#cp ./plugin/build/outputs/jar/plugin.vungle.jar ./corona_plugin/plugin.vungle.jar
[ -f ./VungleCoronaTest.apk ] && rm ./VungleCoronaTest.apk
cp ./app/build/outputs/apk/VungleCoronaTest-debug.apk ./VungleCoronaTest.apk

#/usr/local/bin/puck -api_token=d6cb4cec883a44a5a39a0ed21a845ff3 -app_id=3887b118a4ab23e2b88b7a0be99087a3 -submit=auto -download=true -notify=false -open=nothing VungleCoronaTest.apk
