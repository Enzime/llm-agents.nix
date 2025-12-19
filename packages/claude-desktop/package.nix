{
  lib,
  stdenvNoCC,
  fetchurl,
  electron,
  p7zip,
  icoutils,
  nodePackages,
  imagemagick,
  makeDesktopItem,
  makeWrapper,
  patchy-cnb,
  perl,
}:

stdenvNoCC.mkDerivation rec {
  pname = "claude-desktop";
  version = "0.14.10";

  src = fetchurl {
    # NOTE: The `?v=${version}` doesn't request a specific version, it's a cache buster.
    # The upstream always serves the latest installer at this URL.
    url = "https://storage.googleapis.com/osprey-downloads-c02f6a0d-347c-492b-a752-3e0651722e97/nest-win-x64/Claude-Setup-x64.exe?v=${version}";
    hash = "sha256-Sn/lvMlfKd7b/utFvCxrkWNDJTug4OOSA4lo9YV8aqk=";
  };

  nativeBuildInputs = [
    p7zip
    nodePackages.asar
    makeWrapper
    imagemagick
    icoutils
    perl
  ];

  desktopItem = makeDesktopItem {
    name = "claude";
    exec = "claude-desktop %u";
    icon = "claude";
    type = "Application";
    terminal = false;
    desktopName = "Claude";
    genericName = "Claude Desktop";
    startupWMClass = "claude";
    categories = [
      "Office"
      "Utility"
    ];
    mimeTypes = [ "x-scheme-handler/claude" ];
  };

  buildPhase = ''
    runHook preBuild

    # Create temp working directory
    mkdir -p $TMPDIR/build
    cd $TMPDIR/build

    # Extract installer exe, and nupkg within it
    7z x -y $src

    7z x -y "AnthropicClaude-${version}-full.nupkg"

    # Package the icons from claude.exe
    wrestool -x -t 14 lib/net45/claude.exe -o claude.ico
    icotool -x claude.ico

    for size in 16 24 32 48 64 256; do
      mkdir -p $TMPDIR/build/icons/hicolor/"$size"x"$size"/apps
      install -Dm 644 claude_*"$size"x"$size"x32.png \
        $TMPDIR/build/icons/hicolor/"$size"x"$size"/apps/claude.png
    done

    rm claude.ico

    # Process app.asar files
    # We need to replace claude-native-bindings.node in both the
    # app.asar package and .unpacked directory
    mkdir -p electron-app
    cp "lib/net45/resources/app.asar" electron-app/
    cp -r "lib/net45/resources/app.asar.unpacked" electron-app/

    cd electron-app
    asar extract app.asar app.asar.contents

    SEARCH_BASE="app.asar.contents/.vite/renderer/main_window/assets"
    TARGET_PATTERN="MainWindowPage-*.js"

    # Find the target file recursively (ensure only one matches)
    TARGET_FILES=$(find "$SEARCH_BASE" -type f -name "$TARGET_PATTERN")
    NUM_FILES=$(echo "$TARGET_FILES" | grep -c .)

    # Remove the "!" from 'if (!isWindows && isMainWindow) return null;'
    # to enable the title bar on Linux
    if [ "$NUM_FILES" -eq 0 ]; then
      echo "Error: No file matching '$TARGET_PATTERN' found within '$SEARCH_BASE'." >&2
      exit 1
    elif [ "$NUM_FILES" -gt 1 ]; then
      echo "Error: Expected exactly one file matching '$TARGET_PATTERN' within '$SEARCH_BASE', but found $NUM_FILES." >&2
      exit 1
    else
      TARGET_FILE="$TARGET_FILES"
      perl -i -pe \
        's{if\(!(\w+)\s*&&\s*(\w+)\)}{if($1 && $2)}g' \
        "$TARGET_FILE"
    fi

    # Replace native bindings
    cp ${patchy-cnb}/lib/patchy-cnb.*.node app.asar.contents/node_modules/claude-native/claude-native-binding.node
    cp ${patchy-cnb}/lib/patchy-cnb.*.node app.asar.unpacked/node_modules/claude-native/claude-native-binding.node

    # .vite/build/index.js in the app.asar expects the Tray icons to be
    # placed inside the app.asar.
    mkdir -p app.asar.contents/resources
    cp ../lib/net45/resources/Tray* app.asar.contents/resources/

    # Copy i18n json files
    mkdir -p app.asar.contents/resources/i18n
    cp ../lib/net45/resources/*.json app.asar.contents/resources/i18n/

    # Repackage app.asar
    asar pack app.asar.contents app.asar

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Electron directory structure
    mkdir -p $out/lib/$pname
    cp -r $TMPDIR/build/electron-app/app.asar $out/lib/$pname/
    cp -r $TMPDIR/build/electron-app/app.asar.unpacked $out/lib/$pname/

    # Install icons
    mkdir -p $out/share/icons
    cp -r $TMPDIR/build/icons/* $out/share/icons

    # Install .desktop file
    mkdir -p $out/share/applications
    install -Dm0644 ${desktopItem}/share/applications/claude.desktop $out/share/applications/claude.desktop

    # Create wrapper
    mkdir -p $out/bin
    makeWrapper ${electron}/bin/electron $out/bin/$pname \
      --add-flags "$out/lib/$pname/app.asar" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"

    runHook postInstall
  '';

  dontUnpack = true;
  dontConfigure = true;

  meta = with lib; {
    description = "Claude Desktop for Linux - AI assistant from Anthropic";
    homepage = "https://claude.ai/download";
    license = licenses.unfree;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
    maintainers = with maintainers; [ ];
    mainProgram = "claude-desktop";
    platforms = platforms.linux;
  };
}
