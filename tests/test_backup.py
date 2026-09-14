"""Exercise the rendered backup script without a database or cloud account."""
import gzip
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest

from jinja2 import Environment, StrictUndefined

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which('flock'), 'flock is required (included on Ubuntu)')
class BackupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name)
        self.backups = self.directory / 'backups'
        self.backups.mkdir()
        env = Environment(undefined=StrictUndefined)
        env.filters['quote'] = shlex.quote
        script = env.from_string((ROOT / 'templates/postgres-backup.sh.j2').read_text()).render(
            postgres_backup_dir=str(self.backups), postgres_backup_retention_days=7
        )
        self.script = self.directory / 'backup.sh'
        self.script.write_text(script)

    def run_backup(self, fail=False):
        # Export a fake Docker command; run the real script, compression, and retention.
        # An absolute flock path also supports Homebrew outside the script's fixed PATH.
        wrapper = '''
        docker() { printf 'CREATE DATABASE test;\\n'; return "$TEST_DUMP_STATUS"; }
        flock() { "$TEST_FLOCK" "$@"; }
        export -f docker flock
        exec bash "$TEST_SCRIPT"
        '''
        return subprocess.run(['bash', '-c', wrapper], capture_output=True, text=True,
                              env={**os.environ, 'TEST_DUMP_STATUS': '1' if fail else '0',
                                   'TEST_SCRIPT': str(self.script),
                                   'TEST_FLOCK': shutil.which('flock')})

    def old_backup(self):
        old = self.backups / 'postgres-20000101T000000.sql.gz'
        old.write_bytes(b'existing backup')
        timestamp = time.time() - 10 * 86400
        os.utime(old, (timestamp, timestamp))
        return old

    def test_success_publishes_private_compressed_dump(self):
        result = self.run_backup()
        self.assertEqual(result.returncode, 0, result.stderr)
        backups = list(self.backups.glob('postgres-*.sql.gz'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(gzip.decompress(backups[0].read_bytes()), b'CREATE DATABASE test;\n')
        self.assertEqual(backups[0].stat().st_mode & 0o777, 0o600)
        self.assertEqual(list(self.backups.glob('.postgres-*')), [])

    def test_failed_dump_keeps_old_backup_and_removes_partial(self):
        old = self.old_backup()
        result = self.run_backup(fail=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(list(self.backups.glob('postgres-*.sql.gz')), [old])
        self.assertEqual(old.read_bytes(), b'existing backup')
        self.assertEqual(list(self.backups.glob('.postgres-*')), [])

    def test_success_prunes_only_old_matching_files(self):
        old = self.old_backup()
        unrelated = self.backups / 'keep-me.sql.gz'
        unrelated.write_text('keep')
        result = self.run_backup()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(old.exists())
        self.assertTrue(unrelated.exists())

class ShellTemplateTests(unittest.TestCase):
    def test_all_shell_templates_parse(self):
        env = Environment(undefined=StrictUndefined)
        env.filters['quote'] = shlex.quote
        for template in (ROOT / 'templates').glob('*.sh.j2'):
            with self.subTest(template=template.name):
                script = env.from_string(template.read_text()).render(
                    postgres_backup_dir='/var/backups/postgresql',
                    postgres_backup_retention_days=7,
                    postgres_ready_timeout=300,
                )
                result = subprocess.run(['bash', '-n'], input=script, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
