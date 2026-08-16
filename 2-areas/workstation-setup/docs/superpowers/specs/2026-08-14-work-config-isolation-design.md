# Work Configuration Isolation Design

## Goal

Keep work-only shell settings out of the general interactive shell while preserving the current work profile behavior.

## Scope

Create `.zshrc.work` for clearly work-specific settings:

- `AWS_PROFILE=okta-prod-engineer`
- `.kubectlAliases` sourcing
- DoorDash ETL environment variables
- the `devbox` alias
- Pedregal `grpf.sh` sourcing
- Herdr workspace/title hooks

Google Cloud SDK initialization, language runtimes, mobile tooling, editors, OMP, and other general developer setup remain in `.zshrc`.

## Integration

`.zshrc` sources `$HOME/.zshrc.work` at the end of the file, after the shared shell hooks are initialized. The work file also loads `add-zsh-hook` and `zsh/datetime` defensively because its Herdr hook depends on them. The workstation catalog adds a `work`-profile symlink mapping from `.zshrc.work` in `~/utils` to `$HOME/.zshrc.work`. Base profiles therefore do not load work settings.

The work file remains credential-free and guards optional files, commands, and project paths. Kubernetes credentials, GitHub hosts, and other authentication state remain outside the shared configuration.

## Verification

Run shell syntax checks and isolated startup smoke tests with and without `.zshrc.work`. Update the workstation fixture mapping and verify base/work profile behavior, then run the existing fixture and usage test suites.
