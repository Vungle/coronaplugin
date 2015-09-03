set -ve
currentPath=$(pwd)
echo "Path:" $currentPath

[ -f ./VungleCoronaTest.ipa ] && rm ./VungleCoronaTest.ipa

xcodebuild -target VungleCoronaTest -project VungleCoronaTest.xcodeproj clean
xcodebuild -project VungleCoronaTest.xcodeproj -scheme AdsTestApp archive -archivePath ./VungleCoronaTest.xcarchive
xcodebuild -exportArchive -exportFormat ipa -archivePath "./VungleCoronaTest.xcarchive/" -exportPath "./VungleCoronaTest.ipa" -exportProvisioningProfile "Vungle In House Distribution"
