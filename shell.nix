# run with: nix-shell shell.nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.mkShell {
  # [rust]: nixowy hardening psuje debug-buildy
  hardeningDisable = [ "all" ];

  packages = with pkgs; [
    zsh

    # [backend: go]:
    go
    gopls
    golangci-lint

    # [mobile: expo / react native + mobile-tauri-svelte: frontend]:
    nodejs_24
    watchman        # szybszy watch plików dla Metro (opcjonalnie)
    jdk17           # potrzebny do `npx expo run:android`

    # [mobile-tauri-svelte: rust]: rustup zamiast nixowego rustc/cargo -
    # `tauri android init/dev` woła `rustup target add` (targety androidowe);
    # binarki z rustup działają na NixOS dzięki nix-ld
    rustup
    cargo-tauri      # `cargo tauri dev` - to samo co `npm run tauri dev`
    rust-analyzer

    # [mobile-tauri-svelte: narzędzia natywnego builda]:
    pkg-config
    gobject-introspection

    # [narzędzia]:
    python3          # backend/scripts/smoke.sh
    postgresql       # psql do zaglądania w bazę z docker-compose
    minio-client     # mc do zaglądania w bucket
  ];

  # [mobile-tauri-svelte: biblioteki systemowe Tauri (desktopowy webview GTK)]:
  buildInputs = with pkgs; [
    at-spi2-atk
    atkmm
    cairo
    gdk-pixbuf
    glib
    glib-networking
    gsettings-desktop-schemas
    gtk3
    harfbuzz
    librsvg
    libsoup_3
    pango
    webkitgtk_4_1
    openssl
  ];

  shellHook = ''
    # [rust]:
    export NIX_ENFORCE_PURITY=0

    # [mobile-tauri-svelte: android]: SDK/NDK zainstalowane imperatywnie w ~/Android/Sdk
    # (binarki z Google dzialaja na NixOS dzieki nix-ld)
    export ANDROID_HOME="$HOME/Android/Sdk"
    export NDK_HOME="$ANDROID_HOME/ndk/29.0.13846066"
    export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"

    # [mobile-tauri-svelte]: webview musi widzieć schematy GSettings i moduły TLS
    export XDG_DATA_DIRS="$GSETTINGS_SCHEMAS_PATH:$XDG_DATA_DIRS"
    export GIO_EXTRA_MODULES="${pkgs.glib-networking}/lib/gio/modules"
    # export WEBKIT_DISABLE_DMABUF_RENDERER=1  # odkomentuj przy pustym/zaciętym oknie (np. NVIDIA)

    # zsh terminal forwarding:
    export SHELL=${pkgs.zsh}/bin/zsh
    export ZDOTDIR="$(pwd)/.zshrc.d"
    mkdir -p "$ZDOTDIR"
    cat > "$ZDOTDIR/.zshrc" <<'EOF'
      # Source your original config
      [[ -f ~/.zshrc ]] && source ~/.zshrc

      # Prepend plain white (nix-shell) to the existing prompt
      PROMPT="%F{white}(nix-shell)%f $PROMPT"
    EOF
    exec ${pkgs.zsh}/bin/zsh
  '';
}
