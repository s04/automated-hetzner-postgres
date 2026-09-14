#!/usr/bin/env python3
"""Read Terraform outputs without maintaining a second copy of the server IP."""
import json
import os
from pathlib import Path
import subprocess
import sys


def main():
    if "--host" in sys.argv:
        print("{}")
        return
    root = Path(__file__).resolve().parents[1]
    terraform_dir = Path(os.environ.get("TF_DIR", root / "terraform")).resolve()
    result = subprocess.run(
        [os.environ.get("TF_BIN", "terraform"), f"-chdir={terraform_dir}",
         "output", "-json", "ansible_inventory"],
        check=True, capture_output=True, text=True,
    )
    inventory = json.loads(result.stdout)
    inventory["_meta"] = {"hostvars": {}}
    print(json.dumps(inventory))


if __name__ == "__main__":
    try:
        main()
    except (subprocess.CalledProcessError, FileNotFoundError, ValueError) as exc:
        print(f"Cannot read Terraform inventory. Run terraform apply first. {exc}", file=sys.stderr)
        sys.exit(1)
