# Hoptek engineering — shared Claude Code guidance

Fleet-wide defaults, managed by the [bootstrap](https://github.com/hoptekai/bootstrap) repo.
Do **not** edit this file directly — it's refreshed on `boot update`. Put personal
preferences in your own `~/.claude/CLAUDE.md`, which imports this via `@common.md`.

## Commits & PRs
- Use **Conventional Commits**: `type(scope): summary` (`feat`, `fix`, `chore`, `docs`,
  `refactor`, `test`, `build`, `ci`). Imperative mood, lower-case summary, no trailing period.
- Keep commits focused; separate refactors from behavior changes.
- Commits are **signed** (SSH signing via the Bitwarden agent) — don't disable it.

## Environments & tooling
- **Prefer devbox for project toolchains.** Add languages/runtimes to the project's
  `devbox.json`, not globally. `direnv allow` activates the shell.
- Machine-level tools come from the bootstrap repo; don't `brew install` or `nix profile
  install` project dependencies ad hoc.
- Fast-moving apps/CLIs belong in Homebrew (via bootstrap), not the nixpkgs pin.

## Secrets
- **Never commit secrets.** Pull them from Bitwarden: `bw get password <item>` / `bw get notes <item>`.
- Don't print secret values into logs, terminals, or commit messages.

## Working style
- Match the surrounding code's style, naming, and structure before introducing new patterns.
- Prefer small, reviewable changes. Don't refactor unrelated code in the same change.
- Before claiming something works, verify it: run the tests / `nix flake check` /
  the actual command — don't assert success from inspection alone.
- Default editor is **Zed** (`zed --wait`).
