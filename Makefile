.DEFAULT_GOAL := help
TF ?= terraform
TF_DIR ?= $(CURDIR)/terraform
BUCKET_TF_DIR ?= $(CURDIR)/terraform/object-storage
ANSIBLE_ARGS ?=
CONFIG_ARGS := $(if $(wildcard config.yml),-e @config.yml,) $(if $(wildcard backup.generated.yml),-e @backup.generated.yml,)
PLAYBOOK = TF_BIN="$(TF)" TF_DIR="$(TF_DIR)" ansible-playbook -i scripts/inventory.py $(CONFIG_ARGS) $(ANSIBLE_ARGS)

.PHONY: help bucket bucket-config init plan deploy configure status backup s3-backup restore-drill upgrade tunnel check
help:
	@echo "make bucket     Optionally create a private Hetzner S3 bucket with Terraform"
	@echo "make deploy     Provision (with confirmation) and configure the server"
	@echo "make configure  Apply configuration without provisioning"
	@echo "make status     Show health, disk space, archiving, and backup status"
	@echo "make backup     Take a local compressed SQL backup"
	@echo "make s3-backup  Take a pgBackRest differential backup to S3"
	@echo "make upgrade    Back up locally and to configured S3, then update the selected major's image"
	@echo "make restore-drill  Restore S3 into an isolated test container and clean up"
	@echo "make tunnel     Open localhost:54321 through SSH"
	@echo "make check      Run local validation (no cloud resources)"

bucket:
	@test -n "$$S3_ACCESS_KEY_ID" -a -n "$$S3_SECRET_ACCESS_KEY" || { echo "Export S3_ACCESS_KEY_ID and S3_SECRET_ACCESS_KEY first." >&2; exit 1; }
	$(TF) -chdir="$(BUCKET_TF_DIR)" init
	@MINIO_USER="$$S3_ACCESS_KEY_ID" MINIO_PASSWORD="$$S3_SECRET_ACCESS_KEY" $(TF) -chdir="$(BUCKET_TF_DIR)" apply
	$(MAKE) bucket-config
bucket-config:
	@$(TF) -chdir="$(BUCKET_TF_DIR)" output -raw backup_config > backup.generated.yml.tmp && mv backup.generated.yml.tmp backup.generated.yml
	@echo "Saved backup.generated.yml; subsequent make commands load it automatically."

init:
	$(TF) -chdir="$(TF_DIR)" init
plan: init
	$(TF) -chdir="$(TF_DIR)" plan
deploy: init
	$(TF) -chdir="$(TF_DIR)" apply
	$(PLAYBOOK) playbook.yaml
configure:
	$(PLAYBOOK) playbook.yaml
status:
	$(PLAYBOOK) operations.yml -e operation=status
backup:
	$(PLAYBOOK) operations.yml -e operation=backup
s3-backup:
	$(PLAYBOOK) operations.yml -e operation=s3-backup
restore-drill:
	$(PLAYBOOK) operations.yml -e operation=restore-drill
upgrade:
	$(PLAYBOOK) operations.yml -e operation=upgrade-backup
	$(PLAYBOOK) playbook.yaml -e postgres_pull_policy=always
tunnel:
	ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:54321:127.0.0.1:54321 root@"$$($(TF) -chdir="$(TF_DIR)" output -raw server_ip)"
check:
	$(TF) -chdir="$(TF_DIR)" fmt -check -recursive
	$(TF) -chdir="$(TF_DIR)" init -backend=false -input=false
	$(TF) -chdir="$(TF_DIR)" validate
	$(TF) -chdir="$(BUCKET_TF_DIR)" init -backend=false -input=false
	$(TF) -chdir="$(BUCKET_TF_DIR)" validate
	ansible-lint playbook.yaml operations.yml tasks/*.yml
	ansible-playbook -i inventory.ini playbook.yaml --syntax-check
	python -m unittest discover -s tests -v
