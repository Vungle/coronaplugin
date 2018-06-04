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

#./gradlew build

[ -f ./VungleCoronaTest.apk ] && rm ./VungleCoronaTest.apk
#cp ./app/build/outputs/apk/VungleCoronaTest-debug.apk ./VungleCoronaTest.apk


tar -cvzf android.tgz -C ../plugins/2017.3081/android .
aws s3 cp ./android.tgz s3://kosyakow --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers

sed -E -i .bak "s/appVersion=\'[0-9]+\.[0-9]+\.[0-9]+\'/appVersion=\'$version.$build\'/g" ./buildAndroid.lua
sed -E -i .bak "s/androidVersionCode=\'[0-9]+\'/androidVersionCode=\'$code\'/g" ./buildAndroid.lua

/Applications/Corona/Native/Corona/mac/bin/CoronaBuilder.app/Contents/MacOS/CoronaBuilder build --lua ./buildAndroid.lua

/usr/local/bin/puck -api_token=d6cb4cec883a44a5a39a0ed21a845ff3 -app_id=3887b118a4ab23e2b88b7a0be99087a3 -submit=auto -download=true -notify=false -open=nothing VungleCoronaTest.apk
