import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class InventoryTests(unittest.TestCase):
    def test_host_query_does_not_require_terraform(self):
        result = subprocess.run([str(ROOT / 'scripts/inventory.py'), '--host', 'example'],
                                capture_output=True, text=True,
                                env={**os.environ, 'TF_BIN': '/does/not/exist'})
        self.assertEqual(result.returncode, 0)
        self.assertEqual(json.loads(result.stdout), {})

    def test_inventory_reads_output_and_adds_hostvars(self):
        with tempfile.TemporaryDirectory() as directory:
            binary = Path(directory) / 'terraform'
            binary.write_text('''#!/bin/sh
case "$1" in -chdir=*/terraform) ;; *) exit 1;; esac
[ "$2 $3 $4 $5" = "output -json ansible_inventory " ] || exit 2
printf '%s' '{"postgres_servers":{"hosts":["192.0.2.1"],"vars":{"ansible_user":"root"}}}'
''')
            binary.chmod(0o755)
            result = subprocess.run([str(ROOT / 'scripts/inventory.py'), '--list'],
                                    capture_output=True, text=True,
                                    env={**os.environ, 'TF_BIN': str(binary)})
            self.assertEqual(result.returncode, 0, result.stderr)
            inventory = json.loads(result.stdout)
            self.assertEqual(inventory['postgres_servers']['hosts'], ['192.0.2.1'])
            self.assertEqual(inventory['_meta'], {'hostvars': {}})

    def test_missing_terraform_returns_actionable_error(self):
        result = subprocess.run([str(ROOT / 'scripts/inventory.py'), '--list'],
                                capture_output=True, text=True,
                                env={**os.environ, 'TF_BIN': '/does/not/exist'})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Run terraform apply first', result.stderr)


if __name__ == '__main__':
    unittest.main()
