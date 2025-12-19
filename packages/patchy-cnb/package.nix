{
  lib,
  rustPlatform,
  fetchFromGitHub,
  napi-rs-cli,
  nodejs,
}:

rustPlatform.buildRustPackage rec {
  pname = "patchy-cnb";
  version = "0.14.10";

  src = fetchFromGitHub {
    owner = "k3d3";
    repo = "claude-desktop-linux-flake";
    rev = "v${version}";
    hash = "sha256-dT+YtJLHIxLHNQNjnhfVlSg2KQsXIQahK+1DQi3cIjA=";
  };

  sourceRoot = "${src.name}/patchy-cnb";

  cargoHash = "sha256-oU5+Ts09k/Fe4ujvgSC8Mz1uDbvPx3J2vNoY5S3DQZU=";

  nativeBuildInputs = [
    napi-rs-cli
    nodejs
  ];

  buildPhase = ''
    runHook preBuild

    npm run build --offline

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib
    cp patchy-cnb.*.node $out/lib/

    runHook postInstall
  '';

  meta = with lib; {
    description = "Stub replacement for claude-native-bindings.node for Claude Desktop on Linux";
    homepage = "https://github.com/k3d3/claude-desktop-linux-flake";
    license = with licenses; [ mit asl20 ];
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
  };
}
