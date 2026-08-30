{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  nix-update-script,

  alsa-lib,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  gcc-unwrapped,
  glib,
  gtk3,
  libgbm,
  libGL,
  libsecret,
  libX11,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libXrandr,
  libxcb,
  libxkbcommon,
  nspr,
  nss,
  pango,
  systemd,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "tabby-terminal";
  version = "1.0.235";

  src =
    let
      asset =
        {
          x86_64-linux = "tabby-${finalAttrs.version}-linux-x64.deb";
          aarch64-linux = "tabby-${finalAttrs.version}-linux-arm64.deb";
        }
        .${stdenv.hostPlatform.system} or (throw "Unsupported system: ${stdenv.hostPlatform.system}");
    in
    fetchurl {
      url = "https://github.com/Eugeny/tabby/releases/download/v${finalAttrs.version}/${asset}";
      hash =
        {
          x86_64-linux = "sha256-7M3DTW0X74ZNWbuhzQTX7UoMJ7ECvc0e3pvastaT6Ro=";
          aarch64-linux = "sha256-kagkxJPzO7VGOXgYYaA7/90WDIU0WzY6Ys2FtVx1cIQ=";
        }
        .${stdenv.hostPlatform.system};
    };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-core
    cairo
    cups
    dbus
    expat
    gcc-unwrapped
    glib
    gtk3
    libgbm
    libGL
    libsecret
    libX11
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libXrandr
    libxcb
    libxkbcommon
    nspr
    nss
    pango
  ];

  # Needed for the Chromium sandbox's zygote process to fork() correctly
  runtimeDependencies = [ systemd ];

  # node_modules/@serialport/bindings-cpp ships a musl-libc prebuild alongside
  # the glibc one we actually use; node-gyp-build never loads it on NixOS.
  autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ];

  # Chromium's ANGLE dlopen()s libGL.so.1/libEGL.so.1 by name at runtime
  # instead of declaring them as ELF dependencies, so autoPatchelfHook never
  # adds their rpath. Force them in so the dynamic linker resolves them.
  preFixup = ''
    patchelf --add-needed libGL.so.1 \
      --add-needed libEGL.so.1 \
      --add-rpath ${lib.makeLibraryPath [ libGL ]} \
      $out/opt/tabby/tabby
  '';

  unpackPhase = ''
    runHook preUnpack

    mkdir -p "$out/share" "$out/opt/tabby" "$out/bin"
    dpkg-deb --fsys-tarfile "$src" | tar --extract --directory="$out"

    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    cp -av $out/opt/Tabby/* $out/opt/tabby
    cp -av $out/usr/share/* $out/share
    rm -rf $out/usr $out/opt/Tabby
    ln -sf "$out/opt/tabby/tabby" "$out/bin/tabby"

    substituteInPlace "$out/share/applications/tabby.desktop" \
      --replace "Exec=/opt/Tabby/tabby" "Exec=$out/bin/tabby"

    runHook postInstall
  '';

  passthru.updateScript = nix-update-script { };

  meta = {
    description = "Highly configurable terminal emulator with SSH and serial connection support, split panes, and themes";
    homepage = "https://tabby.sh";
    changelog = "https://github.com/Eugeny/tabby/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    maintainers = with lib.maintainers; [ crisautomata ];
    mainProgram = "tabby";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
})
