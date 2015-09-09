set -ve

cd android
./build.plugin.sh ~/Library/Android/sdk/
cd ..
cd ios
./build.plugin.sh
cd ..
tar -zcvf plugins.tgz ./plugins