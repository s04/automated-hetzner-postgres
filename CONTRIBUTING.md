# Contributing

Issues and pull requests are welcome. Describe the problem, expected behavior, and your Terraform, Ansible, OS, and PostgreSQL versions. Remove tokens, passwords, state contents, and private keys from logs before sharing them.

Install the dependencies and run the checks in the README. Keep changes small enough to review, document new variables, and preserve existing Terraform resource addresses and data paths where possible. A PostgreSQL major version bump needs an explicit migration guide.

For deployment changes, use a disposable Hetzner project/server and restricted SSH CIDR. Live tests incur costs and must be explicitly authorized by whoever owns the account. Verify:

1. A fresh deployment becomes healthy and accepts an authenticated connection through an SSH tunnel.
2. A second Ansible run preserves a known row and does not recreate the container unnecessarily.
3. A completed backup restores into an isolated container with the expected row.
4. Failed backups do not publish partial dumps or prune existing backups.
5. An incompatible PostgreSQL major version fails before modifying the host.
6. With S3 enabled, an initial full backup and a differential backup succeed, and a row created after the base backup is recovered from WAL to a time before its deletion.
7. Recovery refuses a nonempty directory and succeeds on an empty destination; active S3 archiving cannot be accidentally disabled.
8. A patch upgrade backs up before changing the image, and a subsequent configuration run reports no changes.
9. Public database access is blocked, and Terraform destroy removes all resources created for the test, including the temporary SSH key.

Do not run destructive tests against an existing database. Include test results and limitations in the pull request.

## Maintenance cadence

Review the weekly validation run and dependency-update PRs monthly. Ansible collection ranges in `requirements.yml` and PostgreSQL image majors still need explicit review; Dependabot does not update those for this repository. For a running server, inspect backup freshness, archive failures, disk usage, and restore-drill results regularly, and schedule security/patch maintenance. Repository CI never connects to deployed databases or upgrades them automatically.

GitHub can [disable scheduled workflows after 60 days without repository activity](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/disable-and-enable-workflows). Check that the weekly workflow remains enabled during extended quiet periods.

This project is licensed under the [MIT License](LICENSE).
