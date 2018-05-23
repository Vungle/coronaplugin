set -ve
currentPath=$(pwd)
echo "Path:" $currentPath

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

sed -E -i .bak "s/\<string\>[0-9]+\.[0-9]+\.[0-9]+\<\/string\>/<string>$version.$build<\/string>/g" App-Info.plist

pluginVersion=$(cat ../plugin_version.txt)
_pluginVersion=$(echo "$pluginVersion" | sed "s/\./_/g")
sub="@\"$_pluginVersion\";//plugin version. Do not delete this comment"
sed -E -i .bak "s#@\"[0-9]+_[0-9]+_[0-9]+\";//plugin version. Do not delete this comment#$sub#g" Plugin/VungleAds.mm
rm Plugin/VungleAds.mm.bak

[ -f ./VungleCoronaTest.ipa ] && rm ./VungleCoronaTest.ipa

xcodebuild -project VungleCoronaTest.xcodeproj -scheme VungleCoronaTest archive -archivePath ./VungleCoronaTest.xcarchive -allowProvisioningUpdates
xcodebuild -exportArchive -archivePath "./VungleCoronaTest.xcarchive/" -exportPath "." -exportOptionsPlist "./exportOptions.plist" -allowProvisioningUpdates

#/usr/local/bin/puck -api_token=d6cb4cec883a44a5a39a0ed21a845ff3 -app_id=a63c146c01e7fd8eeebe15fad3dfc269 -submit=auto -download=true -notify=false -open=nothing VungleCoronaTest.ipa