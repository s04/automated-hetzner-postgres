# Operating your database

Run server commands below over SSH as root. Substitute your actual database names, roles, and backup filenames.

For S3 physical backups, continuous WAL, and point-in-time recovery, see [the S3 guide](backups.md).

## Back up and verify

```bash
/usr/local/sbin/postgres-backup
ls -lh /var/backups/postgresql/
gzip -t /var/backups/postgresql/postgres-<timestamp>.sql.gz
```

Dumps contain all databases and global objects, including role password hashes. Keep them private. The backup script uses `pipefail`, a restrictive umask, a lock, and a temporary file. A failed dump cannot become a completed backup or trigger retention cleanup. Backups require free disk space; monitor both disk usage and the age of the latest completed dump. Cron output needs a configured mail service if you want email notifications.

Copy a completed dump to another machine with `scp` or your preferred encrypted backup system. A gzip integrity check verifies compression, not restorability: perform a restore drill too.

## Restore drill on the same host

Use a disposable container with a different name, no published ports, and no production data mount. This example matches the default PostgreSQL major version. Choose a bootstrap superuser name that does not exist in the source cluster to avoid a role collision.

```bash
docker run -d --name postgres-restore-test \
  -e POSTGRES_USER=restore_operator \
  -e POSTGRES_HOST_AUTH_METHOD=trust \
  postgres:16-bookworm
# Wait until this succeeds:
docker exec postgres-restore-test pg_isready -h 127.0.0.1 -U restore_operator
set -o pipefail
gzip -dc /var/backups/postgresql/postgres-<timestamp>.sql.gz | \
  docker exec -i postgres-restore-test psql -X -v ON_ERROR_STOP=1 -U restore_operator -d postgres

docker exec postgres-restore-test psql -U restore_operator -d mydb -c '\dt'
# Query known application records and validate counts, then remove the test container/volume:
docker rm -fv postgres-restore-test
```

Trust authentication is only for this isolated disposable container, which must not be attached to an application network or expose ports. For disaster recovery, restore into a new, empty server, verify your data, then move clients over. Do not stream a full-cluster dump into a running application database without planning for existing object conflicts and writes.

## Patch updates

Keep the same configuration and credentials. From your workstation, take pre-upgrade backups and update with:

```bash
make upgrade
```

The command takes a local backup and an S3 differential backup when configured before pulling/rebuilding the image. This can recreate the container and briefly interrupt connections when a newer image is available. It keeps the major version and persistent host data. Normal reruns use `missing`, so they do not silently pull a new image. Host package upgrades are a separate maintenance task; the playbook refreshes apt metadata without running a distribution upgrade.

## Major upgrades

Do not point a newer PostgreSQL major version at the old data directory. The playbook checks `PG_VERSION` and refuses this before installing packages or modifying the container.

1. Read the target PostgreSQL release notes and check extension compatibility.
2. Make an off-server backup and successfully rehearse restoring it with the target version.
3. Provision a separate VM using separate Terraform state and unique `server_name`; configure the target major on its empty data directory.
4. Stop application writes, take a final dump, and restore it into the new cluster. Account for bootstrap role collisions as in the restore drill.
5. Validate data and application behavior, switch clients, and keep the old server until the migration is accepted.

The default stays on major 16 for existing users. Versions 17 and 18 are opt-in. Explicit `PGDATA` keeps the host mount consistent with this repository rather than adopting the image's PostgreSQL 18 default layout.

## Credentials

Reusing the initial environment values is required for consistent Ansible configuration. To rotate a password, change it inside PostgreSQL (for example with interactive `psql` and `\password`), then update your secret store and Ansible inputs. Updating `POSTGRES_PASSWORD` alone does not change an initialized role's password. Container environment variables are visible to root and Docker administrators; restrict access to both.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| SSH times out | Public IP changed? Update `allowed_cidr` and apply Terraform; verify the key and server readiness. |
| Ansible cannot read inventory | Run Terraform apply first; check the state directory and `TF_BIN`. |
| Container fails readiness | `docker logs --tail 100 postgres`; check free disk space and `PG_VERSION`. |
| Password changed but login fails | Initialization variables do not rotate existing passwords. |
| Local tunnel cannot bind | Choose a free local port, e.g. `-L 127.0.0.1:15432:127.0.0.1:54321`, then use `psql -p 15432`. |
| Database is unreachable directly | Expected: access it through the SSH tunnel. |
| Backups are missing | Run `/usr/local/sbin/postgres-backup`; check `systemctl status cron` and disk space. |

Useful host checks:

```bash
docker ps --filter name=postgres
docker logs --tail 100 postgres
df -h /var/lib/postgresql/data /var/backups/postgresql
systemctl status docker cron fail2ban
sshd -T | head
```
