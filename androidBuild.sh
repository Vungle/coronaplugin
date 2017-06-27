set -ve
pwd
cd ..
[ -d ./corona-test-app ] && rm -rf ./corona-test-app
git clone git@github.com:Vungle/corona-test-app.git
git checkout sdk5
cd coronaplugin
cd android
./build.sh ~/Library/Android/sdk/
cd ..
[ -d ../corona-test-app ] && rm -rf ../corona-test-app
