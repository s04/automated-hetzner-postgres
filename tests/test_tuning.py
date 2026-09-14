"""Check the default resource policy across small and large dedicated hosts."""
from pathlib import Path
import unittest

from jinja2 import Environment, StrictUndefined
import yaml

ROOT = Path(__file__).resolve().parents[1]


class TuningTests(unittest.TestCase):
    def test_default_resource_budgets_are_bounded(self):
        defaults = yaml.safe_load((ROOT / 'group_vars/postgres.yml').read_text())
        env = Environment(undefined=StrictUndefined)
        for ram, cpus in [(1024, 1), (4096, 2), (16384, 8), (65536, 64)]:
            with self.subTest(ram=ram, cpus=cpus):
                context = {**defaults, 'ansible_memtotal_mb': ram, 'ansible_processor_vcpus': cpus,
                           'postgres_max_connections': '100'}

                def setting(name):
                    return int(env.from_string(str(defaults[name])).render(context))

                shared = setting('postgres_shared_buffers_mb')
                maintenance = setting('postgres_maintenance_work_mem_mb')
                work = setting('postgres_work_mem_mb')
                self.assertGreater(shared, 0)
                self.assertLess(shared, ram * .4)
                self.assertGreaterEqual(work, 1)
                self.assertLessEqual(work, 16)
                # Three autovacuum workers plus one work allocation per connection
                # must leave OS headroom under the default policy. This is not a
                # worst-case bound: each real query can allocate work_mem repeatedly.
                self.assertLess(shared + 3 * maintenance + 100 * work, ram * .9)
                self.assertLessEqual(setting('postgres_max_parallel_workers'), cpus)
                self.assertLessEqual(setting('postgres_max_parallel_workers_per_gather'), cpus)


if __name__ == '__main__':
    unittest.main()
