# Server Service Synchronization Design

## Status

Design ready for user spec review.

## Goal

Extend the workstation setup kit with a safe, explicit synchronization layer for the Linux server profile. Capture only portable service definitions in `~/utils`, then apply those definitions to another server through a dry-run-first command. Existing home-file mappings and `WORKSTATION_PROFILE=server` behavior remain unchanged.

## Current server inventory

The target Linux host currently runs these application or service workloads:

- Apache2 under systemd.
- Syncthing as a user systemd service.
- Immich through Docker Compose, including its database, Redis, server, and machine-learning containers.
- Home Assistant through Docker Compose.
- Mosquitto through Docker Compose.
- MariaDB under systemd.
- Samba (`smbd`/`nmbd`) under systemd.
- x11vnc under systemd.

Docker, SSH, cron, logging, containerd, Docker itself, desktop/session services, and other OS infrastructure are not application synchronization targets. They remain installation or host-operations concerns.

## Non-goals and privacy boundary

The synchronization layer MUST NOT copy, commit, render, or back up into `~/utils`:

- `.env` files, passwords, tokens, credentials, password databases, or TLS certificates/private keys;
- Syncthing `config.xml`, device IDs, encryption keys, folder identities, or sync database state;
- Home Assistant `.storage`, databases, logs, backups, device/entity IDs, automations tied to local devices, or commented credentials;
- Immich uploads, photo/media roots, PostgreSQL data, Redis data, model caches, or generated runtime state;
- Mosquitto data, logs, password files, or broker identity state;
- MariaDB data, Samba account/share secrets, x11vnc credentials, service journals, or host-specific runtime files;
- hostnames, personal domains, usernames, machine-specific absolute paths, or private network identifiers.

A live service file is never copied wholesale. Portable templates are written from reviewed, sanitized content. The existing `~/utils` privacy boundary remains authoritative.

## Source layout

The server layer is separate from `references/config-sources.tsv`, whose destination model is intentionally `$HOME`-relative:

```text
server/
├── services.tsv
└── templates/
    ├── apache/
    │   └── virtual-host.conf.tmpl
    ├── compose/
    │   ├── homeassistant/compose.yaml
    │   ├── immich/compose.yaml
    │   └── mosquitto/compose.yaml
    └── examples/
        ├── homeassistant-configuration.yaml
        ├── immich.env.example
        └── mosquitto.conf
```

`services.tsv` is a declarative inventory and synchronization contract. Its columns are:

```text
id  manager  probe  artifact  destination_key  policy  excluded_classes
```

`policy` is one of `template`, `manual-review`, or `inventory-only`. Destination keys are fixed identifiers resolved from a local variables file; arbitrary destination paths are rejected.

## Service policies

| Service | Manager | Policy | Portable artifact | Excluded state |
| --- | --- | --- | --- | --- |
| Apache2 | systemd | template | Sanitized virtual-host template | certificates, private keys, logs, host-specific domains and document roots |
| Immich | docker-compose | template | Compose definition and non-secret variable example | `.env`, uploads, media, PostgreSQL, Redis, model cache |
| Home Assistant | docker-compose | template | Compose definition and sanitized configuration example | `.storage`, databases, logs, backups, device IDs, automations, credentials |
| Mosquitto | docker-compose | template | Compose definition and reviewed broker config example | password files, data, logs, credentials, runtime identity |
| Syncthing | systemd-user | inventory-only | Service metadata and safe setup notes | `config.xml`, keys, device IDs, folders, indexes, database state |
| MariaDB | systemd | manual-review | No automatic artifact | database files, users, grants, credentials, logs |
| Samba | systemd | manual-review | No automatic artifact | account database, share ACLs, host-specific shares and credentials |
| x11vnc | systemd | manual-review | No automatic artifact | passwords, display/session state, machine-specific service overrides |

## Command and data flow

The command is Linux-only and requires `WORKSTATION_PROFILE=server`:

```bash
WORKSTATION_PROFILE=server \
  bash scripts/server-sync.sh --os linux --utils-path "$HOME/utils"
```

Dry-run is the default. Supported operations are:

```bash
WORKSTATION_PROFILE=server \
  bash scripts/server-sync.sh --inventory
WORKSTATION_PROFILE=server \
  bash scripts/server-sync.sh --service apache2
WORKSTATION_PROFILE=server \
  bash scripts/server-sync.sh --service immich
WORKSTATION_PROFILE=server \
  bash scripts/server-sync.sh --apply \
  --vars-file "$HOME/.config/workstation-setup/server.env"
```

`--inventory` performs read-only probes against systemd, the user systemd manager, and Docker Compose. It reports known services, missing services, unexpected application workloads, Compose roots, and listening service classes. It does not collect raw configuration, environment values, container logs, or data paths beyond the declared inventory fields.

For template services, the normal flow is:

1. Parse and validate `services.tsv`.
2. Validate the selected service and the fixed variable names allowed by its template.
3. Render placeholders with literal replacement only; no `eval`, command substitution, or arbitrary shell expansion.
4. Stage the rendered result in a private temporary directory.
5. Validate the staged result (`docker compose config` for Compose projects and Apache syntax validation for the virtual-host template).
6. In apply mode, back up only an existing declared destination under `/var/backups/workstation-setup/server/<timestamp>/`.
7. Install only the declared configuration artifact.
8. Print a manual follow-up. The command never restarts services, runs `docker compose up`, changes users/groups, or touches excluded state.

The local variables file MUST be a regular file with mode `0600`, MUST live outside `~/utils`, and MUST never appear in output. Missing variables, unresolved placeholders, unsafe destinations, invalid service IDs, and excluded paths fail closed before mutation.

## Validation and tests

Add a fixture-driven `scripts/tests/test_server_sync.sh` that does not require root, Docker, systemd, or a live service. It will verify:

- every metadata row uses an allowlisted manager, policy, artifact, destination key, and exclusion class;
- templates contain no credential-shaped values, private-key markers, commented credentials, real host paths, device IDs, IP addresses, or personal domains;
- inventory probes parse deterministic fake systemd/Docker output;
- dry-run selects only declared services and never creates files;
- invalid service IDs, missing variables, unresolved placeholders, malformed metadata, unsafe destinations, and excluded data paths fail closed;
- Compose validation is required before apply;
- backups contain only declared configuration destinations;
- no apply path invokes a restart, `docker compose up`, or a data-directory mutation.

The existing workstation profile suite remains required. `server-sync.sh --inventory` is also smoke-tested on the target host as a read-only operation.

## Acceptance criteria

- `WORKSTATION_PROFILE=server` continues to pass the existing profile tests unchanged.
- The service inventory covers Apache2, Syncthing, Immich, Home Assistant, Mosquitto, MariaDB, Samba, and x11vnc.
- Portable templates contain no raw service configuration or sensitive runtime state.
- Dry-run output is deterministic and mutation-free.
- Apply requires explicit `--apply`, validates before mutation, backs up only declared config files, and never restarts services or touches excluded state.
- Documentation explains service policies, local variables, excluded state, and manual follow-up.
- All existing tests plus the new server-sync fixture pass; metadata and template privacy checks pass.
