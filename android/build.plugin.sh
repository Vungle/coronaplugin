#!/bin/sh

CORONA_RELEASES="2017.3184"
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
        
#sed -E -i .bak "s/versionName \"[0-9]+\.[0-9]+\.[0-9]+\"/versionName \"$version.$build\"/g" ./app/build.gradle
#sed -E -i .bak "s/versionCode [0-9]+/versionCode $code/g" ./app/build.gradle
        
#Update plugin version in the LuaLoader.java according to plugin_version.txt file
pluginVersion=$(cat ../plugin_version.txt)
sub="\"$pluginVersion\";//plugin version. Do not delete this comment"
sed -E -i .bak "s#\"[0-9]+\.[0-9]+\.[0-9]+\";//plugin version. Do not delete this comment#$sub#g" plugin/src/main/java/plugin/vungle/LuaLoader.java
rm plugin/src/main/java/plugin/vungle/LuaLoader.java.bak

#./gradlew :plugin:build
./gradlew :plugin:exportPluginJar

for version in $CORONA_RELEASES; do
    cp ./plugin/build/outputs/jar/plugin.vungle.jar ../plugins/${version}/android/
done
	