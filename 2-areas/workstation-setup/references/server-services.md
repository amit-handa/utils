# Server service synchronization

The server service layer is an explicit, Linux-only companion to the normal workstation setup mappings. It manages portable service configuration templates and read-only service inventory; it does not copy a server's runtime state or data. The command requires `WORKSTATION_PROFILE=server` and never restarts, reloads, starts, or stops a service.

The source contract is [`server/services.tsv`](../server/services.tsv). Templates and non-secret examples live under [`server/templates/`](../server/templates/). Existing home-file mappings remain unchanged.

## Metadata contract

`services.tsv` has seven tab-separated columns:

| Column | Meaning |
| --- | --- |
| `id` | Stable service identifier used by `--service`. |
| `manager` | Declarative manager class: `systemd`, `systemd-user`, or `docker-compose`. |
| `probe` | Declarative probe label. It is never executed as shell code. |
| `artifact` | Repository-relative template path, or `-` when no portable artifact exists. |
| `destination_key` | Allowlisted variable name for the destination, or `-`. |
| `policy` | `template`, `manual-review`, or `inventory-only`. |
| `excluded_classes` | State categories that remain local and are never synchronized. |

The ten service rows are:

| Service | Policy | Portable artifact | Excluded state |
| --- | --- | --- | --- |
| Apache2 | `template` | Apache virtual-host template | certificates, private keys, logs, hostnames, document roots |
| Immich | `template` | Docker Compose template | env, uploads, media, PostgreSQL, Redis, model cache |
| Home Assistant | `template` | Docker Compose template | env, storage, databases, logs, backups, device IDs, automations, credentials |
| Mosquitto | `template` | Docker Compose template | password files, data, logs, credentials, runtime identity |
| Syncthing | `inventory-only` | none | config, keys, device IDs, folders, indexes, database |
| MariaDB | `manual-review` | none | data, users, grants, credentials, logs |
| Samba | `manual-review` | none | account database, ACLs, shares, credentials |
| x11vnc | `manual-review` | none | passwords, display state, session state, overrides |
| Photoview | `manual-review` | none | Compose, env, media, database, logs |
| vsftpd | `manual-review` | none | config, credentials, certificates, logs, user data |

Policy behavior:

- `template` rows can be rendered, validated, and explicitly applied. Only the declared template destination is written.
- `inventory-only` rows are reported by `--inventory` and are always skipped by configuration planning.
- `manual-review` rows are reported in a plan but have no portable artifact. Their data, identities, and local configuration require a separate operator-reviewed procedure.

## Inventory

Run from the package directory. Inventory is read-only:

```bash
WORKSTATION_PROFILE=server \
  bash scripts/server-sync.sh --os linux --inventory
```

The command probes the declared systemd services, the user systemd manager for Syncthing, and Docker Compose project status. Output is limited to stable service/project status records, including missing known Compose projects:

```text
OK service apache2 active
INACTIVE service photoview
UNAVAILABLE service vsftpd
OK compose immich-app running
UNEXPECTED compose project unexpected-app
INACTIVE compose ha2 missing
```

It does not print environment variables, Compose file paths, container logs, Docker inspect data, database contents, media paths, credentials, or identity files. Missing tools produce `UNAVAILABLE`; inactive services or missing known Compose projects do not trigger repair or restart actions.

## Dry-run and apply

A dry-run is the default. Select one service to inspect its plan:

```bash
WORKSTATION_PROFILE=server \
  bash scripts/server-sync.sh --os linux --service immich
```

A plan prints the service policy, repository-relative source, safe destination label, and validation step. It does not render into a live destination, create a Compose `.env`, or modify a service data directory. With no `--service`, a dry-run lists all `template` and `manual-review` rows; `inventory-only` rows are skipped.

Apply is intentionally narrower: it requires one selected `template` service, a local vars file, and an explicit `--apply`:

```bash
WORKSTATION_PROFILE=server \
  bash scripts/server-sync.sh --os linux --service immich --apply \
  --vars-file "$HOME/.config/workstation-setup/server.env"
```

Before writing, the command validates metadata, variables, destination safety, and the staged artifact. Apache templates are checked with `apachectl -t`; Compose templates are checked with `docker compose ... config --quiet`. Missing validation tooling is a dry-run warning and an apply error. Apply writes only the selected Apache file or `<ROOT>/compose.yaml`, with mode `0644`.

Destination rules are fixed:

- Apache destinations must be regular `.conf` files directly under `/etc/apache2/sites-available/`. Applying there requires root.
- Compose roots must be absolute paths under `/srv`, `/opt`, or `/mnt`. Filesystem roots, `/etc`, `/var/lib`, `/var/log`, `/home`, symlinked components, traversal, and state-like names such as `.env`, `database`, `media`, `log`, and `key` are rejected.
- Existing destination symlinks, directories, or non-regular files fail closed.
- The command never reads or creates a service-local `.env` file.

If an existing regular destination file is replaced, it is copied with metadata preserved to `/var/backups/workstation-setup/server/<UTC timestamp>/` with backup-directory mode `0700`. No backup is created when no existing destination file is present. The command never invokes `systemctl restart`, `systemctl reload`, `docker compose up`, or `docker compose down`; service reloads and operational follow-up remain manual.

## Local vars file

The vars file is an operator-local input. It must be a regular, non-symlink file with mode `0600` or stricter, must be outside `~/utils`, and must never be committed. Only these keys are accepted:

```text
APACHE_SITE_PATH
APACHE_SERVER_NAME
APACHE_DOCUMENT_ROOT
IMMICH_ROOT
HOMEASSISTANT_ROOT
MOSQUITTO_ROOT
```

Values are parsed as literal `KEY=VALUE` records. Duplicate or unknown keys, shell metacharacters, traversal, unsafe destinations, and values beginning with `-` fail closed. Apache rendering accepts only the fixed `__APACHE_SERVER_NAME__` and `__APACHE_DOCUMENT_ROOT__` markers. Compose runtime variables remain in the template for the service-local environment; the synchronization command does not expand or source them.

The command never logs vars-file values. Do not place passwords, tokens, private keys, certificates, database credentials, media locations, or other sensitive data in the file beyond the minimum local destination values required for the selected template.

## Configuration versus service data

The repository contains sanitized service definitions only. It does not contain or synchronize:

- databases, uploads, media, indexes, model caches, backups, or logs;
- passwords, credentials, private keys, certificates, account databases, ACLs, or device identities;
- service-local `.env` files or authentication state;
- live hostnames, personal paths, or runtime overrides.

Use the service's own deployment and backup procedures for those categories. Review every generated plan before apply and perform any service-specific reload or migration manually.
