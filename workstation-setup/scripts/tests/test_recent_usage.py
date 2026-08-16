import datetime as dt
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "recent_usage.py"
START = 1_780_000_000
END = 1_780_086_400


def history_record(epoch: int, command: str) -> str:
    return f": {epoch}:0;{command}\n"


class RecentUsageTest(unittest.TestCase):
    def run_normalizer(self, history: Path, start: int = START, end: int = END):
        return subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--history",
                str(history),
                "--start-epoch",
                str(start),
                "--end-epoch",
                str(end),
            ],
            capture_output=True,
            text=True,
            check=False,
        )

    def test_normalizes_bounded_usage_without_private_payloads(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            history = Path(temp_dir) / "history"
            history.write_text(
                "".join(
                    [
                        history_record(START - 1, "older-tool should-not-appear"),
                        history_record(START, "devbox run"),
                        history_record(START + 10, "herdr --token=super-secret-token"),
                        history_record(START + 20, "idea ."),
                        history_record(START + 30, "open sandbox.example.internal"),
                        history_record(START + 40, "sudo kubectl get pods"),
                        history_record(START + 50, "/opt/tools/nvim --flag"),
                        history_record(START + 60, "devbox setup"),
                        history_record(START + 70, "unterminated 'secret malformed text"),
                        history_record(END, "upper-bound should-not-appear"),
                        "malformed history record with private payload\n",
                    ]
                ),
                encoding="utf-8",
            )

            result = self.run_normalizer(history)

        self.assertEqual(result.returncode, 0, result.stderr)
        rows = [line.split("\t") for line in result.stdout.splitlines()]
        self.assertTrue(rows)
        self.assertTrue(all(len(row) == 3 for row in rows))
        self.assertEqual(rows, sorted(rows, key=lambda row: (row[0], row[1])))

        expected_date = dt.datetime.fromtimestamp(
            START, tz=dt.timezone.utc
        ).strftime("%Y-%m-%d")
        counts = {(date, name): int(count) for date, name, count in rows}
        for name in ("devbox", "herdr", "idea", "open", "kubectl", "nvim"):
            self.assertIn((expected_date, name), counts)
        self.assertEqual(counts[(expected_date, "devbox")], 2)
        self.assertEqual(counts[(expected_date, "unclassified")], 1)

        combined = result.stdout + result.stderr
        for private_value in (
            "super-secret-token",
            "sandbox.example.internal",
            "--token",
            "get pods",
            "--flag",
            "/opt/tools/nvim",
            "unterminated",
            "private payload",
            "older-tool",
            "upper-bound",
        ):
            self.assertNotIn(private_value, combined)

    def test_consumes_wrapper_options_and_multiline_records(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            history = Path(temp_dir) / "history"
            history.write_text(
                "".join(
                    [
                        history_record(START, "sudo -u root kubectl get pods"),
                        history_record(
                            START + 10, "sudo --user root kubectl get secrets"
                        ),
                        history_record(START + 11, "sudo -A kubectl get config"),
                        history_record(START + 12, "sudo -uroot kubectl get jobs"),
                        history_record(START + 20, "env -i devbox run"),
                        history_record(START + 30, "/usr/bin/env devbox setup"),
                        history_record(START + 40, "command -p nvim --clean"),
                        history_record(
                            START + 41, "/usr/bin/time -l nvim private-state"
                        ),
                        history_record(START + 50, "builtin -- printf secret"),
                        history_record(
                            START + 60, "time -p command -p vim private-file"
                        ),
                        history_record(START + 70, "sudo -u"),
                        f": {START + 80}:0;devbox \\\n",
                        "--credential multiline-secret.internal\n",
                        history_record(START + 90, "idea ."),
                        "malformed standalone 'private payload\n",
                        history_record(START + 100, "open safe-argument"),
                        history_record(
                            START + 101,
                            "sudo --edit /private/customer-secret",
                        ),
                        history_record(
                            START + 102, "command -v secret-command"
                        ),
                        history_record(
                            START + 103, "builtin -d secret-builtin"
                        ),
                        history_record(
                            START + 104, "sudo -K private-customer-name"
                        ),
                        history_record(
                            START + 105,
                            "env -S 'printf %s' private-env-argument",
                        ),
                        f": {START + 110}:0;devbox \\\n",
                    ]
                ),
                encoding="utf-8",
            )

            result = self.run_normalizer(history)

        self.assertEqual(result.returncode, 0, result.stderr)
        rows = [line.split("\t") for line in result.stdout.splitlines()]
        counts = {name: int(count) for _, name, count in rows}
        self.assertEqual(counts["kubectl"], 4)
        self.assertEqual(counts["devbox"], 3)
        self.assertEqual(counts["nvim"], 2)
        for name in ("printf", "vim", "idea", "open"):
            self.assertEqual(counts[name], 1)
        self.assertEqual(counts["unclassified"], 7)
        combined = result.stdout + result.stderr
        for private_value in (
            "root",
            "get secrets",
            "get config",
            "get jobs",
            "--clean",
            "private-state",
            "private-file",
            "--credential",
            "multiline-secret.internal",
            "malformed standalone",
            "private payload",
            "safe-argument",
            "/usr/bin/env",
            "/usr/bin/time",
            "/private/customer-secret",
            "customer-secret",
            "secret-command",
            "secret-builtin",
            "private-customer-name",
            "private-env-argument",
        ):
            self.assertNotIn(private_value, combined)

    def test_invalid_integer_argument_is_redacted(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            history = Path(temp_dir) / "history"
            history.write_text("", encoding="utf-8")
            result = self.run_normalizer(
                history, start="super-secret-bound", end=END
            )

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stderr.strip(), "error: invalid arguments")
        self.assertNotIn("super-secret-bound", result.stderr)
        self.assertNotIn(str(history), result.stderr)

    def test_rejects_invalid_bounds_without_echoing_arguments(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            history = Path(temp_dir) / "sensitive-name-history"
            history.write_text("", encoding="utf-8")
            result = self.run_normalizer(history, start=END, end=START)

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("start epoch must be less than end epoch", result.stderr)
        self.assertNotIn("sensitive-name-history", result.stderr)

    def test_unreadable_input_does_not_echo_sensitive_path(self):
        sensitive_path = Path("/path-that-does-not-exist/private-host-token")
        result = self.run_normalizer(sensitive_path)

        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stderr.strip(), "error: history file is unreadable")
        self.assertNotIn(str(sensitive_path), result.stderr)


if __name__ == "__main__":
    unittest.main()
