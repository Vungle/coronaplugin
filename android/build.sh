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
#cp ./app/build/outputs/apk/debug/VungleCoronaTest-debug.apk ./VungleCoronaTest.apk

tar -cvzf android.tgz -C ../plugins/2017.3081/android .
/usr/local/aws/bin/aws s3 cp ./android.tgz s3://kosyakow --grants read=uri=http://acs.amazonaws.com/groups/global/AllUsers

sed -E -i .bak "s/appVersion=\'[0-9]+\.[0-9]+\.[0-9]+\'/appVersion=\'$version.$build\'/g" ./buildAndroid.lua
sed -E -i .bak "s/androidVersionCode=\'[0-9]+\'/androidVersionCode=\'$code\'/g" ./buildAndroid.lua

java -jar /Users/administrator/Documents/apktool_2.3.3.jar d VungleCoronaTest.apk
cp -r /Users/administrator/Documents/xml ./VungleCoronaTest/res
sed -E -i .bak "s/android:name=\"android.support.multidex.MultiDexApplication\"/android:name=\"android.support.multidex.MultiDexApplication\" android:networkSecurityConfig=\"@xml\/network_security_config\"/g" ./VungleCoronaTest/AndroidManifest.xml
rm ./VungleCoronaTest/AndroidManifest.xml.bak 
rm ./VungleCoronaTest.apk
java -jar /Users/administrator/Documents/apktool_2.3.3.jar b VungleCoronaTest VungleCoronaTest-unsign.apk
/Users/administrator/Library/Android/sdk/build-tools/27.0.3/apksigner sign --ks /Users/administrator/.android/debug.keystore --out VungleCoronaTest.apk --ks-pass pass:android VungleCoronaTest-unsign.apk


/Applications/Corona/Native/Corona/mac/bin/CoronaBuilder.app/Contents/MacOS/CoronaBuilder build --lua ./buildAndroid.lua

/usr/local/bin/puck -api_token=d6cb4cec883a44a5a39a0ed21a845ff3 -app_id=3887b118a4ab23e2b88b7a0be99087a3 -submit=auto -download=true -notify=false -open=nothing VungleCoronaTest.apk

#/usr/local/bin/puck -api_token=d6cb4cec883a44a5a39a0ed21a845ff3 -app_id=3887b118a4ab23e2b88b7a0be99087a3 -submit=auto -download=true -notify=false -open=nothing VungleCoronaTest.apk
