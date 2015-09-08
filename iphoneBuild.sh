set -ve
cd ..
[ -d ./corona-test-app ] && rm -rf ./corona-test-app
git clone git@github.com:Vungle/corona-test-app.git
cd coronaplugin
cd ios
./build.sh
cd ..
[ -d ../corona-test-app ] && rm -rf ../corona-test-app