# Changelog

## Unreleased

### Fixed

- Removed the default database-directory deletion on Ansible reruns.
- Replaced the invalid environment lookup with `ansible.builtin.env` and declared required collections.
- Let the official PostgreSQL entrypoint manage data ownership instead of assuming UID 1000.
- Check final TCP readiness rather than the temporary initialization server.
- Keep failed and partial dumps out of the completed backup set; prune only after success.
- Validate credentials and existing PostgreSQL major version before changing the host.
- Use an SSH configuration drop-in and disable interactive authentication as well as passwords.

### Added

- Locked uv development environment shared by Make, CI, and setup instructions.

- MIT license, scheduled weekly validation, and monthly dependency-update PRs.

- Optional Terraform provisioning of private Hetzner Object Storage buckets, isolated bucket state, and automatic Ansible configuration export.
- S3-compatible pgBackRest backups, continuous WAL archiving, isolated restore drills, and guarded recovery onto an empty server.
- Conservative RAM/CPU-aware tuning with explicit overrides and preserved durability settings.
- Make commands for deployment, status, local/S3 backups, restore drills, and backup-before-patch updates.

- Dynamic Terraform-backed Ansible inventory, with alternate tool/directory support.
- Configurable server size, location, public key, name, and optional Hetzner backups.
- PostgreSQL 17 and 18 opt-in support with an explicit data directory.
- Compressed backups with a lock, atomic publication, and configurable retention.
- Container health checks, shared memory configuration, and bounded Docker logs.
- CI checks, backup/inventory regression tests, and deployment/recovery documentation.

### Changed

- Keep PostgreSQL major 16 by default; pull a newer image only when missing or explicitly requested.
- Default new servers to `cx23` and Ed25519 public keys. Existing users should set their current values explicitly before applying Terraform.
- Require a restricted SSH CIDR and remove the unused public PostgreSQL firewall rule.
- Store new backups under `/var/backups/postgresql`; existing backups are left in place.
- Refresh apt metadata without performing an automatic distribution upgrade.
- Refresh the Hetzner provider lock file with Terraform registry checksums for Linux AMD64 and macOS ARM64.
