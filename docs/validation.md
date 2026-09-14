# Validation record

Tested on 15 September 2026 (Europe/Brussels) using an authorized disposable Hetzner `cx23` VM in `nbg1`, Ubuntu 24.04, PostgreSQL 16, Terraform 1.10.5, and Ansible Core 2.18.19.

## Local checks

`make check` passed:

- Terraform formatting and validation for server and optional bucket configurations.
- Ansible lint and syntax checks.
- Eight regression tests covering backup failure/retention/permissions, shell-template syntax, inventory behavior, and tuning budgets across host sizes.

## Live VM checks

- Terraform provisioned the VM, restricted firewall, and temporary SSH key.
- PostgreSQL accepted the correct password through an SSH tunnel and rejected an incorrect one. Direct public database access failed.
- A probe row survived Ansible reruns and image configuration updates. The final S3-enabled rerun reported `changed=0`, `failed=0`.
- Local compressed dumps restored into a disposable PostgreSQL container with the expected row.
- A deliberately failed live dump left older backups intact and removed incomplete output.
- PostgreSQL 17 and 18 images started with the explicit persistent data-directory layout. These were image smoke tests, not full deployment/backup matrices.
- Effective tuning settings were queried from PostgreSQL; `fsync`, `full_page_writes`, and `synchronous_commit` remained enabled.
- `make status` and backup-before-image-update operations succeeded.
- In-place major upgrades, restores over existing files, and accidental disabling of active S3 archiving were rejected.

## S3 and recovery checks

A disposable MinIO service ran on the test VM with TLS and a self-signed certificate. Certificate verification was disabled only in the temporary test configuration; the repository defaults verify TLS.

- pgBackRest created the stanza, verified archiving, and completed full and differential backups.
- An isolated restore reached consistency and exposed the expected databases.
- Point-in-time recovery recovered a row inserted **after** the base backup, at a target before its later deletion. This tested WAL replay, not merely restoration of the base backup.
- Empty-destination disaster recovery succeeded after stopping/removing the database container and preserving the original host data directory elsewhere. This simulated lost PGDATA on the same VM; it was not a second-region recovery exercise.
- The optional bucket Terraform stack created a private bucket and generated Ansible settings. A second plan had no changes. Destroying a nonempty test bucket failed while preserving its object; after deliberately removing that test object, bucket destruction succeeded.

**Boundary:** the database VM was real Hetzner Cloud infrastructure, but the S3 backend was a disposable compatible service. Actual Hetzner Object Storage integration still needs a separate S3 access-key/secret-key pair. The supplied Cloud API token cannot create those credentials. Bucket configuration follows Hetzner's documented Terraform provider setup.

These checks do not establish production-scale throughput, recovery time, ARM deployment coverage, or high availability. Use workload-specific performance testing, monitoring, and periodic off-server restore drills.

## Cleanup

Terraform destroyed the disposable server, firewall, and SSH key. Follow-up Hetzner API requests returned 404 for all three resource IDs. The test S3 service and its remaining objects disappeared with the VM; the separately tested bucket had already been explicitly emptied and destroyed. Temporary local credentials and the SSH keypair were removed.
