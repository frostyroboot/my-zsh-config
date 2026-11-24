{
  description = "my-zsh-config development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            zsh
            fzf
            fd
            ripgrep
            eza
            bat
            starship
            atuin
            zoxide
            neovim
            yazi
            chafa
            jq
            tree
            git
            curl
            python3
          ];
          shellHook = ''
            echo "my-zsh-config dev shell ready"
          '';
        };
      }
    );
}
