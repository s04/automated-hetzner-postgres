# S3 backups, WAL, and recovery

There are two complementary backup paths:

- Daily local SQL dumps are portable across major versions and useful for migrations.
- Optional pgBackRest backups store physical backups and continuous WAL in S3-compatible object storage, supporting recovery after VM loss and recovery to a chosen point in time within the retained WAL history.

Physical restores require the same PostgreSQL major version. A successful upload is not enough: run restore drills and validate application data.

## Enable S3

You can let Terraform create the bucket or use one you already have. Either way, generate a separate S3 access-key/secret-key pair in Hetzner Console under **Security → S3 Credentials**. The Cloud API token used for servers does not work for S3, and Hetzner does not expose an API to generate S3 credentials ([Hetzner documentation](https://docs.hetzner.com/storage/object-storage/faq/buckets-objects/)).

Export the pair in Bash:

```bash
read -rsp 'S3 access key: ' S3_ACCESS_KEY_ID; echo
read -rsp 'S3 secret key: ' S3_SECRET_ACCESS_KEY; echo
export S3_ACCESS_KEY_ID S3_SECRET_ACCESS_KEY
```

### Option A: provision the bucket with Terraform

```bash
make bucket
make configure  # Or make deploy if the database server does not exist yet.
```

`make bucket` uses the optional [`terraform/object-storage`](../terraform/object-storage/main.tf) configuration and asks you to confirm its plan. Defaults create a uniquely named **private Hetzner bucket in Falkenstein**. To change its name or region, copy `terraform/object-storage/terraform.tfvars.example` to `terraform/object-storage/terraform.tfvars` and edit it first.

Terraform exports the non-secret bucket settings to ignored `backup.generated.yml`. Make loads that file after `config.yml`, enabling S3 without copying names or endpoints by hand. Keep exporting the same S3 credentials when configuring the database. Direct Ansible users need `-e @config.yml -e @backup.generated.yml`. `make bucket-config` regenerates the file from existing bucket state. Use `BUCKET_TF_DIR` when keeping multiple bucket environments.

The bucket has **separate Terraform state** from the VM. A server destroy leaves it alone, and bucket destruction refuses to delete a nonempty bucket (`force_destroy = false`). Deliberate retirement requires removing/migrating the backup objects yourself, then running Terraform destroy in the bucket directory. Back up both state files. The provider is S3-compatible MinIO, following [Hetzner's Terraform example](https://docs.hetzner.com/storage/object-storage/getting-started/creating-a-bucket-minio-terraform/); no MinIO service is installed for real Hetzner storage.

### Option B: use an existing bucket

Create or choose a private bucket with your provider. Give the backup credentials access to list the bucket and read/write/delete objects under a dedicated prefix; deletion is needed for retention. Enable provider-side encryption if required by your data policy. Transport uses certificate-verified TLS by default.

Edit `config.yml`:

```yaml
postgres_s3_backup_enabled: true
postgres_s3_bucket: my-postgres-backups
postgres_s3_endpoint: fsn1.your-objectstorage.com
postgres_s3_region: fsn1
postgres_s3_prefix: /my-postgres-server
postgres_s3_retention_full: 2
```

This example uses a Hetzner Falkenstein endpoint. Use your bucket's actual endpoint/region; the endpoint is a hostname **without `https://` or a path**. Path-style requests are the default; set `postgres_s3_uri_style: host` for providers that require virtual-host addressing. See [Hetzner's S3 documentation](https://docs.hetzner.com/storage/object-storage/getting-started/using-s3-api-tools/).

With the credentials exported, run `make configure` (or `make deploy` for a new server).

`S3_BUCKET`, `S3_ENDPOINT`, and `S3_REGION` can also supply the settings via environment variables. Credentials are rendered into a private host configuration file, readable by the container's PostgreSQL OS user, and hidden from Ansible output. Root and Docker administrators can still access them.

Enabling S3 builds a small local image based on the official PostgreSQL image with pgBackRest installed. It verifies the repository and WAL archiving, takes an initial full backup if none exists, and installs weekly full/daily differential schedules. Configuration fails if these checks fail. On large databases the initial backup can take a while.

Retaining two full backups also retains their dependent differential backups and required WAL. This is a backup-count policy, not an exact number of recovery days. Do not use bucket lifecycle rules that independently remove active pgBackRest objects. Use a unique prefix for each independent cluster; a replacement of the same cluster uses its original prefix.

## Daily operations

```bash
make status
make s3-backup
make restore-drill
```

The restore drill restores the latest backup to consistency in a temporary directory, starts it without a TCP listener or archiving, checks that recovery completes, lists databases, and removes its container/data. It requires extra disk space comparable to the database. `postgres_ready_timeout` defaults to 300 seconds for database startup/recovery; increase it for large restores. It does not replace application-level integrity checks.

For a time-targeted drill, run on the server:

```bash
/usr/local/sbin/postgres-restore-drill '2026-09-15 10:30:00+00'
```

Use a timestamp after a retained backup's completion and within archived WAL history. To check your own data during the drill:

```bash
RESTORE_CHECK_DB=mydb RESTORE_CHECK_SQL='SELECT count(*) FROM important_table' \
  /usr/local/sbin/postgres-restore-drill '2026-09-15 10:30:00+00'
```

A query error fails the drill. To enforce an expected business invariant, make the SQL raise an error when it is not satisfied; merely printing a count does not verify its correctness.

## Recover onto an empty server

1. Stop/fence the original database if it is reachable. Two writers must not archive into the same repository as the same cluster.
2. Provision a new server using a separate Terraform directory/state and unique `server_name`. Preserve the original PostgreSQL major, database user, and S3 prefix/credentials. Do **not** initialize an unrelated empty database against the old repository first.
3. Once the new infrastructure exists, configure and restore in one run:

```bash
make configure TF_DIR=/path/to/recovery/terraform \
  ANSIBLE_ARGS='-e postgres_restore_from_s3=true'
```

To recover to a specific point, put `postgres_restore_target` with a timestamp and timezone in your recovery `config.yml`. An empty target replays all available archived WAL. Remove a one-off target after recovery.

The playbook refuses to restore over any existing data files. It restores before starting PostgreSQL, then checks database readiness and WAL archiving. `postgres_restore_from_s3` is a one-off flag: omit it on subsequent reruns. If a restore is interrupted, investigate and preserve the partial directory before deliberately retrying on an empty destination; the playbook will not erase it for you.

Validate the recovered data and application before moving clients. Retain the old machine until recovery is accepted. SQL dump/restore remains the path for major-version migrations.

## Recovery limits and monitoring

`archive_timeout` defaults to 300 seconds to encourage WAL segment switches during light write activity. This is not a guaranteed five-minute recovery objective: upload delay, outages, and archive failures can extend the gap. Restores recover only WAL that reached the repository.

If S3 is unavailable, PostgreSQL retains unarchived WAL locally and retries. The configuration does not drop WAL to hide a full archive queue. Monitor free disk space, archive failures, the last successful backup, and periodic restore results. A full disk can stop writes. `make status` exposes these values; connect monitoring/alert delivery appropriate to your environment.

The playbook rejects an accidental switch from an active S3 configuration to local-only mode. To deliberately stop S3 archiving, remove `backup.generated.yml` if present, set `postgres_s3_backup_enabled: false` and pass `-e postgres_allow_disable_s3=true`. Existing repository contents are retained; recovery coverage stops extending once archiving is disabled.

See the [pgBackRest user guide](https://pgbackrest.org/user-guide.html) for recovery semantics and its [configuration reference](https://pgbackrest.org/configuration.html) for retention and S3 behavior.
