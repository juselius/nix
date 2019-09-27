with (import <nixpkgs> {});
pkgs.androidsdk.overrideAttrs (attrs: rec {
  buildCommand = ''
      ${attrs.buildCommand}

      export ANDROID_SDK_HOME=/tmp/android.$$
      mkdir -p $ANDROID_SDK_HOME/.android
      touch $ANDROID_SDK_HOME/.android/repositories.cfg
      sdkmgr="${androidsdk}/libexec/tools/bin/sdkmanager --sdk_root=$out/libexec"

      echo y | $sdkmgr "platforms;android-23"
      echo y | $sdkmgr "platforms;android-25"
      echo y | $sdkmgr "patcher;v4"
      echo y | $sdkmgr "extras;google;m2repository"
      echo y | $sdkmgr "extras;google;google_play_services"
  '';
  buildInputs = attrs.buildInputs ++ [jdk];
})
