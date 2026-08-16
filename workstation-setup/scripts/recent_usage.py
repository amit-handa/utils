#!/usr/bin/env python3
"""Bounded recent-tool-usage normalizer for the workstation setup kit.

Reads zsh extended-history records from a single ``--history`` path, keeps only
records whose timestamp falls within ``[start_epoch, end_epoch)``, and emits
deterministic ``YYYY-MM-DD<TAB>name<TAB>count`` rows sorted by UTC date then
normalized name.

Privacy boundary — the script **never** writes raw history lines, command
arguments, paths, hostnames, search text, or credentials.  Only normalized
executable basenames and UTC dates leave the process.  Malformed records are
skipped; commands that cannot be safely classified become the literal token
``unclassified`` without retaining any source text.

Dependency-free: standard library only.
"""

import argparse
import datetime as _dt
import os
import re
import shlex
import sys
from collections import Counter

# zsh extended-history record: ``: <epoch>:<duration>;<command>``.
_HISTORY_RE = re.compile(r"^: (\d+):\d+;(.*)$")

# Acceptable normalized executable name — letters, digits, dot, underscore,
# plus, hyphen only.
_SAFE_NAME_RE = re.compile(r"^[A-Za-z0-9_.+-]+$")

# Leading environment-assignment token, e.g. ``FOO=bar``.
_ENV_ASSIGN_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")

# Simple command wrappers stripped before extracting the first executable.
_WRAPPERS = frozenset({"sudo", "env", "time", "command", "builtin"})
_WRAPPER_FLAGS = {
    "sudo": frozenset({
        "-A", "--askpass", "-B", "--bell", "-E", "--preserve-env",
        "-H", "--set-home", "-i", "--login", "-n", "--non-interactive",
        "-S", "--stdin", "-b", "--background",
        "-k", "--reset-timestamp",
        "-s", "--shell",
    }),
    "env": frozenset({"-i", "--ignore-environment", "-0", "--null"}),
    "time": frozenset({
        "-a", "--append", "-h", "-l", "-p", "--portability",
        "-q", "--quiet", "-v", "--verbose",
    }),
    "command": frozenset({"-p"}),
    "builtin": frozenset(),
}
_WRAPPER_OPTIONS_WITH_VALUE = {
    "sudo": frozenset({
        "-u", "--user", "-g", "--group", "-h", "--host",
        "-p", "--prompt", "-C", "--close-from", "-D", "--chdir",
        "-R", "--chroot", "-T", "--command-timeout",
        "-r", "--role", "-t", "--type",
    }),
    "env": frozenset({
        "-a", "--argv0", "-u", "--unset", "-C", "--chdir",
    }),
    "time": frozenset({"-f", "--format", "-o", "--output"}),
    "command": frozenset(),
    "builtin": frozenset(),
}
_NON_EXECUTING_WRAPPER_OPTIONS = {
    "sudo": frozenset({
        "-e", "--edit", "-l", "--list", "-v", "--validate",
        "-V", "--version", "--help", "-K", "--remove-timestamp",
    }),
    "env": frozenset({"-S", "--split-string"}),
    "time": frozenset(),
    "command": frozenset({"-v", "-V"}),
    "builtin": frozenset({"-s", "-d", "-e", "-n"}),
}
_UNCLASSIFIED = "unclassified"


class _SanitizedArgumentParser(argparse.ArgumentParser):
    """Argument parser whose failures never echo caller-provided values."""

    def error(self, message):
        del message
        self.exit(2, "error: invalid arguments\n")


def _consume_wrapper_options(tokens, index: int, wrapper: str):
    """Return the first token after *wrapper* options, or ``None`` if invalid."""
    flags = _WRAPPER_FLAGS[wrapper]
    with_value = _WRAPPER_OPTIONS_WITH_VALUE[wrapper]
    non_executing = _NON_EXECUTING_WRAPPER_OPTIONS[wrapper]
    while index < len(tokens):
        token = tokens[index]
        if token == "--":
            index += 1
            return index if index < len(tokens) else None
        if not token.startswith("-") or token == "-":
            return index
        if token in non_executing or any(
            option.startswith("--") and token.startswith(option + "=")
            for option in non_executing
        ):
            return None
        if token in flags:
            index += 1
            continue
        if token in with_value:
            index += 2
            if index > len(tokens):
                return None
            continue
        if any(
            option.startswith("--") and token.startswith(option + "=")
            for option in with_value
        ):
            index += 1
            continue
        if any(
            option.startswith("-")
            and not option.startswith("--")
            and token.startswith(option)
            and len(token) > len(option)
            for option in with_value
        ):
            index += 1
            continue
        if (
            token.startswith("-")
            and not token.startswith("--")
            and len(token) > 2
            and all("-" + option in flags for option in token[1:])
        ):
            index += 1
            continue
        return None
    return None


def normalize_command(command: str) -> str:
    """Return a safe normalized executable name, or ``unclassified``.

    The *command* string is split with :func:`shlex.split`.  A parse error or
    an unsafe first executable yields ``unclassified`` — the original text is
    never retained.
    """
    try:
        tokens = shlex.split(command)
    except ValueError:
        return _UNCLASSIFIED

    index = 0
    while index < len(tokens):
        token = tokens[index]
        if _ENV_ASSIGN_RE.match(token):
            index += 1
            continue
        wrapper = os.path.basename(token)
        if wrapper not in _WRAPPERS:
            break
        index = _consume_wrapper_options(tokens, index + 1, wrapper)
        if index is None:
            return _UNCLASSIFIED

    if index >= len(tokens):
        return _UNCLASSIFIED

    name = os.path.basename(tokens[index])
    if _SAFE_NAME_RE.match(name):
        return name
    return _UNCLASSIFIED


def parse_history_line(line: str):
    """Return ``(epoch, command)`` for a zsh extended-history line, or ``None``."""
    match = _HISTORY_RE.match(line)
    if match is None:
        return None
    return int(match.group(1)), match.group(2)


def iter_history_records(handle):
    """Yield complete zsh records and skip unrelated malformed lines."""
    current_epoch = None
    command_parts = []
    for raw_line in handle:
        line = raw_line.rstrip("\n")
        parsed = parse_history_line(line)
        if parsed is not None:
            if current_epoch is not None:
                yield current_epoch, _complete_command(command_parts)
            current_epoch, command = parsed
            command_parts = [command]
            continue
        if current_epoch is None:
            continue
        if command_parts[-1].endswith("\\"):
            command_parts.append(line)
            continue
        yield current_epoch, _complete_command(command_parts)
        current_epoch = None
        command_parts = []
    if current_epoch is not None:
        yield current_epoch, _complete_command(command_parts)


def _complete_command(parts):
    """Return a complete logical command, or ``None`` when truncated."""
    if parts[-1].endswith("\\"):
        return None
    return _join_command(parts)


def _join_command(parts) -> str:
    """Join a logical command without preserving continuation newlines."""
    return " ".join(part[:-1] if part.endswith("\\") else part for part in parts)


def collect_usage(history_path, start_epoch: int, end_epoch: int) -> Counter:
    """Return a ``Counter`` keyed by ``(date_string, normalized_name)``.

    Lines that do not match the zsh extended-history format or whose timestamp
    falls outside ``[start_epoch, end_epoch)`` are silently skipped.
    """
    counts: Counter = Counter()
    with open(history_path, "r", encoding="utf-8", errors="replace") as handle:
        for epoch, command in iter_history_records(handle):
            if not (start_epoch <= epoch < end_epoch):
                continue
            name = (
                _UNCLASSIFIED
                if command is None
                else normalize_command(command)
            )
            date = _dt.datetime.fromtimestamp(
                epoch, tz=_dt.timezone.utc
            ).strftime("%Y-%m-%d")
            counts[(date, name)] += 1
    return counts


def format_output(counts: Counter) -> list:
    """Return sorted ``YYYY-MM-DD<TAB>name<TAB>count`` lines."""
    return [
        f"{date}\t{name}\t{count}"
        for (date, name), count in sorted(counts.items())
    ]


def main(argv=None) -> int:
    """Entry point — parse args, collect usage, print normalized rows."""
    parser = _SanitizedArgumentParser(
        description="Normalize bounded recent tool usage from zsh history.",
    )
    parser.add_argument(
        "--history", required=True, help="path to a zsh history file"
    )
    parser.add_argument(
        "--start-epoch", type=int, required=True,
        help="inclusive lower epoch bound",
    )
    parser.add_argument(
        "--end-epoch", type=int, required=True,
        help="exclusive upper epoch bound",
    )
    args = parser.parse_args(argv)

    if args.start_epoch >= args.end_epoch:
        print("error: start epoch must be less than end epoch", file=sys.stderr)
        return 2

    try:
        counts = collect_usage(args.history, args.start_epoch, args.end_epoch)
    except OSError:
        print("error: history file is unreadable", file=sys.stderr)
        return 1

    for line in format_output(counts):
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
