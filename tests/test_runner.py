import importlib.util
import json
import os
from pathlib import Path
import signal
import stat
import tempfile
import time
import unittest


MODULE_PATH = Path(__file__).resolve().parents[1] / "omdesky_runner.py"
SPEC = importlib.util.spec_from_file_location("omdesky_runner", MODULE_PATH)
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)


class RunnerTests(unittest.TestCase):
    def executable(self, directory, body):
        path = Path(directory) / "omdesky"
        path.write_text(body, encoding="utf-8")
        path.chmod(stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR)
        return path

    def test_resolve_prefers_system_binary(self):
        with tempfile.TemporaryDirectory() as directory:
            system = self.executable(directory, "")
            local = self.executable(directory, "")

            resolved = RUNNER.resolve_omdesky(
                [(system, os.getuid()), (local, os.getuid())]
            )

            self.assertEqual(resolved, system.resolve())

    def test_resolve_rejects_group_writable_binary(self):
        with tempfile.TemporaryDirectory() as directory:
            candidate = self.executable(directory, "")
            candidate.chmod(stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR | stat.S_IWGRP)

            resolved = RUNNER.resolve_omdesky([(candidate, os.getuid())])

            self.assertIsNone(resolved)

    def test_query_rejects_stdout_over_limit(self):
        with tempfile.TemporaryDirectory() as directory:
            executable = self.executable(
                directory,
                "#!/usr/bin/python3\nimport sys\nsys.stdout.write('x' * 2048)\n",
            )

            result = RUNNER.query_devices(executable, stdout_limit=1024)

            self.assertEqual(result["code"], "output_limit")

    def test_query_kills_process_that_ignores_termination(self):
        with tempfile.TemporaryDirectory() as directory:
            executable = self.executable(
                directory,
                "#!/usr/bin/python3\nimport signal,time\nsignal.signal(signal.SIGTERM, signal.SIG_IGN)\nwhile True: time.sleep(1)\n",
            )
            started = time.monotonic()

            return_code, output, failure = RUNNER.run_bounded(
                [executable, "devices", "--json"], 0.1, 1024, 1024
            )

            self.assertIsNone(return_code)
            self.assertIsNone(output)
            self.assertEqual(failure, "timeout")
            self.assertLess(time.monotonic() - started, 2)

    def test_query_limits_devices_and_fields(self):
        with tempfile.TemporaryDirectory() as directory:
            devices = [
                {
                    "name": "é" * 300,
                    "address": "100.64.0.1",
                    "status": "ready",
                    "connection": "direct",
                    "latency_ms": 12,
                    "is_local": False,
                    "agent_version": "1.0.0",
                    "omarchy_version": "4.0.0",
                }
                for _ in range(200)
            ]
            executable = self.executable(
                directory,
                "#!/usr/bin/python3\nimport json\nprint(json.loads(" + repr(json.dumps(json.dumps(devices))) + "))\n",
            )

            result = RUNNER.query_devices(executable)

            self.assertTrue(result["ok"])
            self.assertEqual(len(result["devices"]), RUNNER.MAX_DEVICES)
            self.assertLessEqual(
                len(result["devices"][0]["name"].encode("utf-8")),
                RUNNER.MAX_NAME_BYTES,
            )

    def test_closed_environment_does_not_inherit_unknown_values(self):
        os.environ["OMDESKY_TEST_SECRET"] = "secret"

        environment = RUNNER.closed_environment()

        self.assertNotIn("OMDESKY_TEST_SECRET", environment)
        self.assertEqual(environment["PATH"], "/usr/local/bin:/usr/bin")


if __name__ == "__main__":
    unittest.main()
