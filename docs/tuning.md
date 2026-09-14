# Host-aware PostgreSQL tuning

`postgres_autotune: true` selects starting values using Ansible's host RAM and CPU facts. It assumes a dedicated database VM with at least 1 GiB RAM. These are deterministic configuration defaults, not a workload-learning optimizer or a memory guarantee.

| Setting | Default policy |
| --- | --- |
| `shared_buffers` | 25% of host RAM |
| `effective_cache_size` | 65% of host RAM; planner estimate, not an allocation |
| `work_mem` | 5% of RAM divided by `max_connections`, clamped to 1–16 MiB |
| `maintenance_work_mem` | 5% of RAM, clamped to 64–512 MiB |
| `max_connections` | 100 |
| Parallel workers | At most 8 total and 2 per gather, bounded by CPU count |
| `max_wal_size` / `min_wal_size` | 2 GiB / 512 MiB |
| Checkpoints | 10 minutes, completion target 0.9 |
| WAL compression | Enabled |

`fsync`, `full_page_writes`, and `synchronous_commit` keep PostgreSQL's enabled defaults. No durability tradeoff is made for benchmark speed. Autovacuum stays enabled with PostgreSQL defaults; high-churn tables may need workload-specific tuning.

Override individual `postgres_*` settings from [the defaults](../group_vars/postgres.yml) in `config.yml`, then `make configure`. To retain PostgreSQL defaults for memory/checkpoint settings, set `postgres_autotune: false`. That also disables the tuning overrides, including `postgres_max_connections`; S3/WAL archiving remains independently configurable.

`work_mem` applies per operation and per worker, not once per connection. Autovacuum workers can each consume maintenance memory. High concurrency can still exhaust RAM; use application connection pools and benchmark your workload. If other services share the host or a container memory limit is introduced, override the memory values to fit the database's actual budget.

The WAL size setting is a soft checkpoint target, not a hard disk quota. Archiving failures, replication slots, and long-running operations can retain more WAL. Monitor disk usage and `pg_stat_archiver`; never delete WAL files by hand. The shared memory mount defaults to 256 MiB; increase `postgres_shm_size` if parallel queries need more dynamic shared memory.

Inspect effective values over SQL:

```sql
SELECT name, setting, unit, pending_restart
FROM pg_settings
WHERE name IN ('shared_buffers', 'work_mem', 'effective_cache_size',
               'max_connections', 'max_wal_size', 'archive_mode',
               'fsync', 'full_page_writes', 'synchronous_commit');
```

RAM percentages follow PostgreSQL's [resource configuration guidance](https://www.postgresql.org/docs/17/runtime-config-resource.html). Checkpoint and WAL behavior is described in the [WAL configuration documentation](https://www.postgresql.org/docs/17/wal-configuration.html). Percentages and caps here are project choices, not universal PostgreSQL recommendations.
