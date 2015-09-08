set -ve
pwd
cd ..
[ -f ./corona-test-app ] && rm -rf ./corona-test-app
git clone git@github.com:Vungle/corona-test-app.git
cd coronaplugin
cd android
./build.sh ~/Library/Android/sdk/
cd ..
cd ..
rm -rf ../corona-test-app