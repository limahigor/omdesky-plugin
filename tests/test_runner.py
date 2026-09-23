import importlib.util
import json
import os
from pathlib import Path
import signal
import stat
import subprocess
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

    def test_query_times_out_when_descendant_keeps_pipe_open(self):
        with tempfile.TemporaryDirectory() as directory:
            executable = self.executable(
                directory,
                "#!/usr/bin/python3\n"
                "import os,sys,time\n"
                "r, w = os.pipe()\n"
                "pid = os.fork()\n"
                "if pid == 0:\n"
                "    time.sleep(30)\n"
                "    os._exit(0)\n"
                "sys.exit(0)\n",
            )
            started = time.monotonic()

            return_code, output, failure = RUNNER.run_bounded(
                [executable, "devices", "--json"], 0.3, 1024, 1024
            )

            self.assertIsNone(return_code)
            self.assertIsNone(output)
            self.assertEqual(failure, "timeout")
            self.assertLess(time.monotonic() - started, 3)

    def test_terminate_reaps_group_after_leader_exit(self):
        with tempfile.TemporaryDirectory() as directory:
            executable = self.executable(
                directory,
                "#!/usr/bin/python3\n"
                "import os,sys,time\n"
                "pid = os.fork()\n"
                "if pid == 0:\n"
                "    time.sleep(30)\n"
                "    os._exit(0)\n"
                "sys.exit(0)\n",
            )
            process = subprocess.Popen(
                [str(executable)],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
            time.sleep(0.2)

            RUNNER.terminate_and_reap(process)

            self.assertIsNotNone(process.returncode)

            deadline = time.monotonic() + 2
            group_alive = True
            while time.monotonic() < deadline:
                try:
                    os.killpg(process.pid, 0)
                except ProcessLookupError:
                    group_alive = False
                    break
                time.sleep(0.05)

            self.assertFalse(group_alive)

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
                "#!/usr/bin/python3\nimport json\nprint(json.loads(" + repr(json.dumps(json.dumps({"schema": 1, "devices": devices}))) + "))\n",
            )

            result = RUNNER.query_devices(executable)

            self.assertTrue(result["ok"])
            self.assertEqual(len(result["devices"]), RUNNER.MAX_DEVICES)
            self.assertLessEqual(
                len(result["devices"][0]["name"].encode("utf-8")),
                RUNNER.MAX_NAME_BYTES,
            )

    def test_query_rejects_an_unsupported_schema(self):
        with tempfile.TemporaryDirectory() as directory:
            executable = self.executable(
                directory,
                "#!/usr/bin/python3\nprint('[]')\n",
            )

            result = RUNNER.query_devices(executable)

            self.assertEqual(result["code"], "unsupported_schema")

    def test_query_keeps_bounded_blockers(self):
        with tempfile.TemporaryDirectory() as directory:
            document = {
                "schema": 1,
                "devices": [
                    {
                        "name": "desk-b",
                        "status": "blocked",
                        "blockers": [
                            {"code": "needs_access", "side": "local", "fix": "x" * 1024}
                        ]
                        * 10,
                    }
                ],
            }
            executable = self.executable(
                directory,
                "#!/usr/bin/python3\nprint(" + repr(json.dumps(document)) + ")\n",
            )

            result = RUNNER.query_devices(executable)

            blockers = result["devices"][0]["blockers"]
            self.assertEqual(len(blockers), RUNNER.MAX_BLOCKERS)
            self.assertLessEqual(len(blockers[0]["fix"].encode("utf-8")), RUNNER.MAX_BLOCKER_FIX_BYTES)

    def test_text_loses_control_and_bidirectional_characters(self):
        cleaned = RUNNER.bounded_text("desk\u202e\u0007\x1b[2J-b\u200b", 256)

        self.assertEqual(cleaned, "desk[2J-b")

    def test_only_tailscale_addresses_are_accepted(self):
        self.assertIsNotNone(RUNNER.tailscale_address("100.64.0.7"))
        self.assertIsNotNone(RUNNER.tailscale_address("fd7a:115c:a1e0::1"))

        for value in ["192.168.0.10", "127.0.0.1", "desk-b", "--help", "", None, "100.64.0.7 ; x"]:
            self.assertIsNone(RUNNER.tailscale_address(value), value)

    def test_device_without_a_tailscale_address_has_no_address(self):
        device = RUNNER.normalize_device({"name": "desk-b", "address": "10.0.0.2"})

        self.assertEqual(device["address"], "")

    def test_connect_passes_the_address_after_an_option_terminator(self):
        captured = []

        class FakePopen:
            def __init__(self, command, **_):
                captured.append(command)

        original_popen = RUNNER.subprocess.Popen
        original_launcher = RUNNER.trusted_launcher
        RUNNER.subprocess.Popen = FakePopen
        RUNNER.trusted_launcher = lambda: Path("/usr/share/omarchy/bin/omarchy-launch-tui")

        try:
            result = RUNNER.launch(Path("/usr/bin/omdesky"), RUNNER.tailscale_address("100.64.0.7"))
        finally:
            RUNNER.subprocess.Popen = original_popen
            RUNNER.trusted_launcher = original_launcher

        self.assertTrue(result["ok"])
        self.assertEqual(
            captured[0][-5:],
            ["connect", "--input", "remote", "--", "100.64.0.7"],
        )

    def test_connect_refuses_a_target_that_is_not_a_tailscale_address(self):
        original = RUNNER.resolve_omdesky
        RUNNER.resolve_omdesky = lambda: Path("/usr/bin/omdesky")
        output = []
        original_emit = RUNNER.emit
        RUNNER.emit = output.append

        try:
            status = RUNNER.main(["omdesky_runner.py", "connect", "--workspace"])
        finally:
            RUNNER.resolve_omdesky = original
            RUNNER.emit = original_emit

        self.assertEqual(status, 1)
        self.assertEqual(output[0]["code"], "invalid_target")

    def test_closed_environment_does_not_inherit_unknown_values(self):
        os.environ["OMDESKY_TEST_SECRET"] = "secret"

        environment = RUNNER.closed_environment()

        self.assertNotIn("OMDESKY_TEST_SECRET", environment)
        self.assertEqual(environment["PATH"], "/usr/local/bin:/usr/bin")


if __name__ == "__main__":
    unittest.main()
