with import <nixpkgs> {};
stdenv.mkDerivation rec {
  version = "master";
  pname = "fake-cli";

  src = ./deploy;

  builder = pkgs.writeText "builder.sh" ''
    . $stdenv/setup
    mkdir -p $out/lib/fake-cli
    cp -r $src/* $out/lib/fake-cli
    mkdir -p $out/bin
    cat << EOF > $out/bin/fake
    #!/bin/sh
    exec ${dotnet-sdk}/dotnet $out/lib/fake-cli/fake-cli.dll \$*
    EOF
    chmod 755 $out/bin/fake
  '';

  #src = fetchgit {
  #  url = "https://github.com/fsharp/FAKE.git";
  #  rev =  "refs/tags/${version}";
  #  sha256 = "0qw3n47knis2wrrsk0njk3m2ih39gfg9nv86chd5yz77mpkakcw1";
  #};

  #patchPhase = ''
  #  ls -l
  #  sed -i 's/2.1.508/2.2.402/' global.json
  #'';

  #buildPhase = ''
  #  # . $stdenv/setup
  #  mkdir -p /tmp/.dotnet.$$
  #  export DOTNET_SKIP_FIRST_TIME_EXPERIENCE=true
  #  export DOTNET_CLI_HOME=/tmp/.dotnet.$$
  #  export HOME=/tmp/.dotnet.$$
  #  dotnet dev-certs https
  #  mono .paket/paket.exe install
  #  dotnet restore build.proj
  #  cd src/app/fake-cli
  #  mkdir -p $out/lib/fake-cli
  #  dotnet publish -c Release -o $out/lib/fake-cli
  #  rm -rf /tmp/.dotnet.$$
  #'';

  #installPhase = ''
  #  mkdir -p $out/bin
  #  cat << EOF > $out/bin/fake
  #  #!/bin/sh
  #  exec ${dotnet-sdk}/dotnet $out/lib/fake-cli/fake-cli.dll \$*
  #  EOF
  #  chmod 755 $out/bin/fake
  #'';

  buildInputs = [ pkgs.dotnet-sdk ];

  meta = with stdenv.lib; {
    homepage = https://github.com/fsharp/Fake;
    description = "F# FAKE ${version} for .NET Core";
    platforms = [ "x86_64-linux" ];
    maintainers = with maintainers; [ "jonas" ];
    license = licenses.mit;
  };
}
