{ pkgs ? import <nixpkgs> {} }:
let
  ae = pkgs.androidenv;
  sdk = pkgs.androidenv.androidsdk_6_0_extras;
in
pkgs.stdenv.mkDerivation {
  name = "android-sdk";
  buildCommand = ''
      . $stdenv/setup
      mkdir -p $out/libexec

      ln -sf ${sdk}/bin $out
      ln -sf ${sdk}/libexec/* $out/libexec

      rm $out/libexec/extras
      mkdir -p $out/libexec/extras
      ln -sf ${sdk}/libexec/extras/android $out/libexec/extras

      rm $out/libexec/platforms
      mkdir -p $out/libexec/platforms
      ln -sf ${sdk}/libexec/platforms/* $out/libexec/platforms

      export ANDROID_SDK_HOME=/tmp/android.$$
      mkdir -p $ANDROID_SDK_HOME/.android
      touch $ANDROID_SDK_HOME/.android/repositories.cfg
      sdkmgr="${sdk}/libexec/tools/bin/sdkmanager --sdk_root=$out/libexec"

      echo y | $sdkmgr "platforms;android-23"
      echo y | $sdkmgr "platforms;android-25"
      echo y | $sdkmgr "patcher;v4"
      echo y | $sdkmgr "extras;google;m2repository"
      echo y | $sdkmgr "extras;google;google_play_services"
  '';
  buildInputs = with pkgs; [ sdk openjdk ];
}
