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
build=$(expr $d1 / 60 - 23875980)
echo "Build:" $build

#sed -E -i .bak "s/\<key\>CFBundleVersion\<\/key\>\s+\<string\>[0-9]+\.[0-9]+\<\/string\>/<key>CFBundleVersion<\/key>\n<string>$version.$build<\/string>/g" App-Info.plist
sed -E -i .bak "s/\<string\>[0-9]+\.[0-9]+\<\/string\>/<string>$version.$build<\/string>/g" App-Info.plist

[ -f ./VungleCoronaTest.ipa ] && rm ./VungleCoronaTest.ipa

xcodebuild -target VungleCoronaTest -project VungleCoronaTest.xcodeproj clean
xcodebuild -project VungleCoronaTest.xcodeproj -scheme AdsTestApp archive -archivePath ./VungleCoronaTest.xcarchive
xcodebuild -exportArchive -exportFormat ipa -archivePath "./VungleCoronaTest.xcarchive/" -exportPath "./VungleCoronaTest.ipa" -exportProvisioningProfile "Vungle In House Distribution"

puck -api_token=d6cb4cec883a44a5a39a0ed21a845ff3 -app_id=a63c146c01e7fd8eeebe15fad3dfc269 -submit=auto -download=true -notify=false -open=nothing VungleCoronaTest.ipa