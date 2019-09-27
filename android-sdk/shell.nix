with import <nixpkgs> {};
let
  sdk = androidenv.androidsdk {
    platformVersions = [ "26" ];
    abiVersions = [ "x86" ];
    useGoogleAPIs = true;
    useExtraSupportLibs = false;
    useGooglePlayServices = false;
  };
  unpatched-sdk = stdenv.mkDerivation rec {
    version = "4333796";
    name = "unpatched-android-sdk";
    src = fetchzip {
      url = "https://dl.google.com/android/repository/sdk-tools-linux-${version}.zip";
      sha256 = "0010za2n8vycr29j846qscbdb4vq2b9g1fplqqw16hb0hhn9n039";
    };
    installPhase = ''
        mkdir -p $out
        cp -r * $out/
    '';
    dontPatchELF = true;
  };
  run-react-native = pkgs.buildFHSUserEnv {
    name = "react-native";
    targetPkgs = (pkgs: [
      nodejs
      zlib
    ]);
    profile = ''
        export JAVA_HOME=${openjdk.home}
        export ANDROID_HOME=$HOME/.android
        export PATH=$PWD/node_modules/.bin:$PATH
    '';
    runScript = "react-native";
  };
  run-emulator = pkgs.buildFHSUserEnv {
    name = "emulator";
    targetPkgs = (pkgs: [
      xorg.libX11
      libGL
      qt5.full
      libpulseaudio
      libcxx
      zlib
    ]);
    profile = ''
        export JAVA_HOME=${openjdk.home}
        export ANDROID_HOME=$HOME/.android
        export PATH=$ANDROID_HOME:$ANDROID_HOME/bin:$PATH
    '';
    runScript = "~/.android/sdk/emulator";
  };
  run-shell = pkgs.buildFHSUserEnv {
    name = "run-shell";
    targetPkgs = (pkgs: [
      openjdk
      zlib
      nodejs
      bash
    ]);
    profile = ''
        export JAVA_HOME=${openjdk.home}
        export ANDROID_HOME=$HOME/.android
        export PATH=$ANDROID_HOME:$ANDROID_HOME/bin:$PATH
    '';
    runScript = "bash";
  };
in
  stdenv.mkDerivation {
    name = "react-native";
    nativeBuildInputs = [
      run-react-native
      run-emulator
      run-shell
    ];
    buildInputs = [
      coreutils
      nodejs
      sdk
      unpatched-sdk
    ];
    shellHook = ''
      export JAVA_HOME=${openjdk}
      export ANDROID_HOME=$HOME/.android/sdk
      export PATH=$ANDROID_HOME/bin:$PATH

      if ! test -d $HOME/.android/sdk; then
        mkdir -p $HOME/.android/sdk
        cp -r ${unpatched-sdk}/* $HOME/.android/sdk/
      fi
      $ANDROID_HOME/bin/sdkmanager --update
      $ANDROID_HOME/bin/sdkmanager \
        "platforms;android-26" \
        "build-tools;26.0.3" \
        "add-ons;addon-google_apis-google-24" \
        "emulator"
    '';
  }
