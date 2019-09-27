with import <nixpkgs> {};
stdenv.mkDerivation {
  name = "android-sdk-licenses";
  buildCommand = ''
    ANDROID_HOME=$out
    mkdir -p "$ANDROID_HOME/licenses"
    echo -e "\nd56f5187479451eabf01fb78af6dfcb131a6481e" > "$ANDROID_HOME/licenses/android-sdk-license"
    echo -e "\n84831b9409646a918e30573bab4c9c91346d8abd" > "$ANDROID_HOME/licenses/android-sdk-preview-license"
  '';
}

