# Work profile

The **work** package profile is opt-in and layers on top of [base](base.md). It adds work-oriented developer commands — Devbox, Teleport CLI, Kubernetes tooling, Bazel, GitHub CLI, and Herdr — **without** any authentication state. The optional `WORKSTATION_PROFILE=work` selector applies the personal-compatible configuration set plus work mappings; work endpoints, user identifiers, cluster names, and tokens are never included.

## Included catalog IDs

From [`references/tool-catalog.tsv`](../references/tool-catalog.tsv), the work profile adds (on top of base):

- **Work CLI tools:** `devbox`, `teleport`, `kubectl`, `bazel`, `github-cli`
- **Session utility (work-scoped):** `herdr`

`kubectl` carries the alias command candidates `k`, `kgpo`, and `kgcmoyaml`. These aliases live in `~/utils/.kubectlAliases`, which the `work` package profile and `WORKSTATION_PROFILE=work` environment link into `$HOME` (see below). The alias file contains no cluster or credential data.

## Platform prerequisites

- **macOS:** Homebrew installs `kubectl`, `bazel`, `devbox`, and `tsh` where available. See [macOS profile](macos.md).
- **Debian/Ubuntu:** `apt`/`dpkg` plus any vendor installers. See [Debian/Ubuntu profile](linux-debian.md).

GitHub CLI (`gh`) is named in this profile's intent; a future manifest entry will record its package name per platform.

## Configuration sources

The work package profile adds the work mappings on top of base (see [`references/config-sources.md`](../references/config-sources.md)). When `WORKSTATION_PROFILE=work` is set, mappings declared for both `personal` and `work` are selected, so shared shell/editor mappings and work-only mappings are available together:

- `.zshrc.work` → `$HOME/.zshrc.work` (symlink, `work` package profile and environment)
- `.kubectlAliases` → `$HOME/.kubectlAliases` (symlink, `work` package profile and environment)
- `.config/gh/config.yml` → `$HOME/.config/gh/config.yml` (symlink, `work` package profile and environment)
- `.local/bin/herdr-title-watch` → `$HOME/.local/bin/herdr-title-watch` (symlink, `work` package profile and environment)

It deliberately does **not** map `~/.kube/config`. Cluster credentials and contexts are a manual handoff. Unset `WORKSTATION_PROFILE` preserves the legacy mapping behavior.

## Manual authentication and licensing handoffs

The kit documents the command or service needed but **never** stores the resulting secret or authenticated state:

- **Devbox:** run `devbox auth` / team onboarding; no secrets are stored by the kit.
- **Teleport CLI (`tsh`):** run `tsh login` against your Teleport proxy. The kit stores no proxy host, user, or certificate.
- **Kubernetes:** set up `~/.kube/config` and contexts manually. `kubectl` aliases are linked, but cluster credentials are not.
- **Bazel:** configure any remote-cache or build-cluster credentials through your project's onboarding, not here.
- **GitHub CLI:** run `gh auth login`. The kit stores no token.
- **Herdr:** authenticate through its own flow when used for work sessions.

## What this profile does not restore

- No Teleport certificates, `tsh` profiles, or proxy hostnames.
- No `~/.kube/config`, cluster contexts, service-account tokens, or cloud credentials.
- No Devbox project environments, caches, or tunnel state.
- No Bazel remote-cache credentials or build-cluster auth.
- No GitHub CLI token or OAuth state.
- No work endpoint hostnames, internal URLs, or user identifiers in any tracked file.
- Nothing from [base](base.md)'s "does not restore" list is restored here either.
