# run with: nix-shell
let
  pkgs = import <nixpkgs> { };
in
pkgs.mkShell {
  packages = with pkgs; [
    zsh

    # [python]: benchmark harness + the receipt generator (pillow/numpy)
    (python3.withPackages (pp: [
      pp.pillow
      pp.numpy
      pp.pydantic # schema definition + validation (Python's zod/yup)
      pp.requests
    ]))

    # fonts for the generator (it hard-codes Debian paths; we point it at these)
    fontconfig
    dejavu_fonts
    liberation_ttf
  ];

  shellHook = ''
    # Expose the exact monospace font files to the generator (see
    # receipt_bench/generate.py -> resolve_fonts). fc-match is used as a
    # fallback, but explicit paths are the most robust on a pure nix-shell.
    export RB_FONT_DEJAVU_MONO="$(find ${pkgs.dejavu_fonts} -name 'DejaVuSansMono.ttf' | head -1)"
    export RB_FONT_DEJAVU_MONO_BOLD="$(find ${pkgs.dejavu_fonts} -name 'DejaVuSansMono-Bold.ttf' | head -1)"
    export RB_FONT_LIBERATION_MONO="$(find ${pkgs.liberation_ttf} -name 'LiberationMono-Regular.ttf' | head -1)"
    export RB_FONT_LIBERATION_MONO_BOLD="$(find ${pkgs.liberation_ttf} -name 'LiberationMono-Bold.ttf' | head -1)"

    # zsh terminal forwarding (same pattern as the sibling projects):
    export SHELL=${pkgs.zsh}/bin/zsh
    export ZDOTDIR="$(pwd)/.zshrc.d"
    mkdir -p "$ZDOTDIR"
    cat > "$ZDOTDIR/.zshrc" <<'EOF'
      [[ -f ~/.zshrc ]] && source ~/.zshrc
      PROMPT="%F{white}(nix-shell)%f $PROMPT"
EOF
    exec ${pkgs.zsh}/bin/zsh
  '';
}
