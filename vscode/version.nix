let
  version = "1.32.2";
  channel = "stable";
  arch = "linux-x64";
  archive_fmt = "tar.gz";
  url = "https://update.code.visualstudio.com/${version}/${arch}/${channel}";
  archive = "VSCode_${version}_${arch}.${archive_fmt}";
  sha256 = "1r139a8ddxw9pww773f8p10hy6kkakn9ql83ab2pg7nzy9r0kfmk";
in
  {
    inherit url version archive sha256;
  }
