set -ve

cd android
./build.plugin.sh
cd ..
cd ios
./build.plugin.sh
cd ..
tar -zcvf plugins.tgz ./plugins