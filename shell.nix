# run with: nix-shell shell.nix
let
  pkgs = import <nixpkgs> { };
in
pkgs.mkShell {
  packages = with pkgs; [
    zsh

    # [backend: go]:
    go
    # gopls
    # golangci-lint

    # [mobile: flutter]:
    # (zawiera darta; Android SDK najprościej mieć z Android Studio
    #  i ustawić ANDROID_HOME - patrz mobile/README.md)
    flutter
    # jdk17
    # android-studio  # unfree - wymaga allowUnfree = true

    # [narzędzia]:
    curl
    python3          # backend/scripts/smoke.sh
    postgresql       # psql do zaglądania w bazę z docker-compose
    minio-client     # mc do zaglądania w bucket
    # docker-compose # zwykle systemowy; odkomentuj, jeśli wolisz z nixa
  ];

  shellHook = ''
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
