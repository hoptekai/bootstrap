{
  description = "Company MacBook bootstrap — nix-darwin + Home Manager (engineer profile)";

  inputs = {
    # Pinned via flake.lock. Fleet-wide upgrade = `nix flake update` + commit.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Lets nix-darwin own the Homebrew installation declaratively.
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs =
    { self, nixpkgs, nix-darwin, home-manager, nix-homebrew, ... }@inputs:
    let
      inherit (nixpkgs) lib;

      # Apple Silicon. Add "x86_64-darwin" hosts here if you still have Intel machines.
      system = "aarch64-darwin";

      # Auto-discover users/*.nix (skipping the template). In the fork-based workflow each
      # engineer's fork contains exactly their own users/<username>.nix, so onboarding needs
      # NO edit to this file — install.sh just drops the rendered overlay in place.
      userFiles = lib.filterAttrs
        (name: type:
          type == "regular"
          && lib.hasSuffix ".nix" name
          && name != "_template.nix")
        (builtins.readDir ./users);

      usernames = map (lib.removeSuffix ".nix") (builtins.attrNames userFiles);

      # Adding an engineer = add users/<name>.nix; mkUser assembles their whole machine.
      mkUser = username:
        nix-darwin.lib.darwinSystem {
          inherit system;
          specialArgs = { inherit inputs username; };
          modules = [
            ./hosts/common.nix
            ./modules/macos-defaults.nix
            ./modules/homebrew.nix
            nix-homebrew.darwinModules.nix-homebrew
            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              # Pre-existing dotfiles (installer/macOS .zshrc etc.) are moved
              # aside as *.before-hm instead of aborting the first activation.
              home-manager.backupFileExtension = "before-hm";
              home-manager.extraSpecialArgs = { inherit inputs username; };
            }
            ./users/${username}.nix
          ];
        };
    in
    {
      darwinConfigurations = lib.genAttrs usernames mkUser;
    };
}
