set -ve
cd ..
[ -d ./corona-test-app ] && rm -rf ./corona-test-app
[ -d ./Corona-Plugin ] && rm -rf ./Corona-Plugin
git clone git@github.com:Vungle/Corona-Plugin.git
mkdir corona-test-app
pushd corona-test-app
mkdir app
popd
cp -av ./Corona-Plugin/Sample/* ./corona-test-app/app/
cd coronaplugin
cd ios
./build.sh
cd ..
[ -d ../corona-test-app ] && rm -rf ../corona-test-app
[ -d ../Corona-Plugin ] && rm -rf ../Corona-Plugin