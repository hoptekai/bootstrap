# Single source of truth for GUI apps + fast-moving CLIs installed via Homebrew.
# Consumed by BOTH profiles:
#   - engineers: modules/homebrew.nix imports this into nix-darwin's homebrew.*
#   - staff:     staff/Brewfile mirrors this list (keep them in sync)
#
# Why Homebrew and not nixpkgs: these should track upstream and not be frozen behind the
# flake pin. Adding an always-installed app = one line here. Optional/pick-your-own apps
# live in packages/optional.list instead.
{
  casks = [
    "bitwarden"          # password manager + SSH agent
    "google-chrome"
    "slack"
    "zed"                # default editor
    # Claude Code — a cask (installs the `claude` binary). In Homebrew, not the nixpkgs pin,
    # so it stays current independent of `nix flake update`.
    "claude-code"
  ];

  brews = [
    "bitwarden-cli"      # `bw` for secrets from the vault
  ];
}
