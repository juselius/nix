# Build:
# $ nix-build dockerImg.nix
# $ docker load < result
#
# Run:
# $ docker run demo
# $ docker stop <tab>
#
# Remove:
# $ docker rm <tab>
# $ docker rmi demo
# $ docker volume prune
#
# Populate /data with current directory:
# $ cat > Dockerfile << EOF
# FROM demo
# ADD .
# EOF
# $ docker build -t demo2 .
# $ docker run demo2
#

{ pkgs ? import <nixpkgs> {} }:

with pkgs;
let
  name = "demo";
  entrypoint = writeScript "entrypoint.sh" ''
    #!${stdenv.shell}
    set -e
    $@; pwd; ls -l; echo $DEMO
    while true; do
      echo -n "*"
    sleep 2
    done
  '';
in {
  dockerImg = dockerTools.buildImage {
    name = name;
    contents = [
      coreutils

    ];

    runAsRoot = ''
      #!${stdenv.shell}
      ${dockerTools.shadowSetup}
      groupadd demo
      useradd demo
      mkdir -p /opt
      chown -R demo:demo /opt
    '';

    config = {
      Cmd = [ "id" "-a" ];
      User = "demo";
      Env = [ ''DEMO="Hello world"'' ];
      Entrypoint = [ entrypoint ];
      ExposedPorts = {
        "80/tcp" = {};
      };
      WorkingDir = "/data";
      Volumes = {
        "/data" = {};
      };
    };
  };
}

