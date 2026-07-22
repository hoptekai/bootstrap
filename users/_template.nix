# Per-user overlay TEMPLATE.
#
# install.sh renders this to users/<your-macos-username>.nix in your fork, filling in the
# __PLACEHOLDER__ values. This is the ONLY file you normally edit — everything else is owned
# upstream, so `boot update` (git pull upstream) stays conflict-free.
#
# The filename determines your username (the flake auto-discovers users/*.nix), which is
# passed in below as `username`.
{ username, ... }:
{
  users.users.${username} = {
    name = username;
    home = "/Users/${username}";
  };
  system.primaryUser = username;

  # Optional GUI apps you picked (merges with the shared cask list). Managed by `boot pick`.
  # BOOT:OPTIONAL_CASKS (managed by `boot pick` — safe to also edit by hand)
  homebrew.casks = [ ];
  # BOOT:END

  home-manager.users.${username} = { pkgs, ... }: {
    imports = [ ../home/common.nix ];

    programs.git = {
      settings.user.name = "__FULL_NAME__";
      settings.user.email = "__GIT_EMAIL__";
      signing = {
        # Your Bitwarden SSH PUBLIC key (starts with "ssh-ed25519 ..."). Used to sign commits.
        key = "__BITWARDEN_SSH_PUBLIC_KEY__";
        signByDefault = true;
      };
    };

    # Optional Nix packages you picked. Managed by `boot pick`.
    # BOOT:OPTIONAL_NIX (managed by `boot pick` — safe to also edit by hand)
    home.packages = with pkgs; [ ];
    # BOOT:END
  };
}
