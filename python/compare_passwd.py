#!/usr/bin/env python3
"""
uid_conflict_check.py

Compares UIDs across one or more /etc/passwd-style files and reports any
UID that appears more than once (whether within a single file or across
multiple files). Designed for RHEL/CentOS default python3.

Usage:
    ./uid_conflict_check.py                     # uses hardcoded DEFAULT_FILES
    ./uid_conflict_check.py file1 file2 file3    # uses given files instead
"""

import sys
from collections import defaultdict

# Hardcoded fallback file list, used only when no CLI arguments are given.
DEFAULT_FILES = [
    "./passwd",
    "./passwd_usde14",
    "./passwd_master",
]


def parse_passwd_line(line, filename, line_num):
    """
    Parse a single passwd-style line.
    Returns (uid, username) tuple, or None if the line should be skipped.
    Prints a warning to stderr for any skipped line.
    """
    stripped = line.strip()

    if not stripped:
        print(f"Warning: skipping blank line in {filename}:{line_num}", file=sys.stderr)
        return None

    if stripped.startswith("#"):
        print(f"Warning: skipping comment line in {filename}:{line_num}", file=sys.stderr)
        return None

    if stripped.startswith("+") or stripped.startswith("-"):
        print(f"Warning: skipping NIS include/exclude line in {filename}:{line_num}", file=sys.stderr)
        return None

    fields = stripped.split(":")

    if len(fields) < 3:
        print(f"Warning: skipping malformed line (too few fields) in {filename}:{line_num}", file=sys.stderr)
        return None

    username = fields[0]
    uid_str = fields[2]

    try:
        uid = int(uid_str)
    except ValueError:
        print(f"Warning: skipping malformed line (non-numeric UID) in {filename}:{line_num}", file=sys.stderr)
        return None

    return (uid, username)


def read_passwd_file(filepath):
    """
    Read a passwd-style file and return a list of (uid, username, filepath) tuples.
    Returns an empty list (with a stderr warning) if the file can't be opened.
    """
    records = []
    try:
        with open(filepath, "r") as f:
            for line_num, line in enumerate(f, start=1):
                result = parse_passwd_line(line, filepath, line_num)
                if result is not None:
                    uid, username = result
                    records.append((uid, username, filepath))
    except OSError as e:
        print(f"Warning: cannot open {filepath} ({e}), skipping", file=sys.stderr)
        return []

    return records


def main():
    file_list = sys.argv[1:] if len(sys.argv) > 1 else DEFAULT_FILES

    all_records = []
    for filepath in file_list:
        all_records.extend(read_passwd_file(filepath))

    # Group all records by UID, preserving encounter order.
    uid_groups = defaultdict(list)  # uid -> list of (username, filepath)
    for uid, username, filepath in all_records:
        uid_groups[uid].append((username, filepath))

    # Group all records by username, preserving encounter order.
    username_groups = defaultdict(list)  # username -> list of (uid, filepath)
    for uid, username, filepath in all_records:
        username_groups[username].append((uid, filepath))

    # Precompute, per UID group with a conflict, whether all usernames match.
    uid_group_same_user = {}  # uid -> True (Same User) / False (Different User)
    for uid, entries in uid_groups.items():
        if len(entries) > 1:
            usernames = {username for username, _ in entries}
            uid_group_same_user[uid] = (len(usernames) == 1)

    # Precompute, per username group with a conflict, whether all UIDs match.
    username_group_same_uid = {}  # username -> True (Same UID) / False (Different UID)
    for username, entries in username_groups.items():
        if len(entries) > 1:
            uids = {uid for uid, _ in entries}
            username_group_same_uid[username] = (len(uids) == 1)

    # Build combined conflict rows: include a record if it has a UID conflict
    # OR a username conflict (union), with four checkmark columns.
    conflict_rows = []  # (uid, username, filepath, same_user, diff_user, same_uid_flag, diff_uid_flag)
    for uid, username, filepath in all_records:
        has_uid_conflict = uid in uid_group_same_user
        has_username_conflict = username in username_group_same_uid

        if not has_uid_conflict and not has_username_conflict:
            continue

        same_user = has_uid_conflict and uid_group_same_user[uid]
        diff_user = has_uid_conflict and not uid_group_same_user[uid]
        same_uid_flag = has_username_conflict and username_group_same_uid[username]
        diff_uid_flag = has_username_conflict and not username_group_same_uid[username]

        conflict_rows.append((uid, username, filepath, same_user, diff_user, same_uid_flag, diff_uid_flag))

    output_lines = []

    if not conflict_rows:
        output_lines.append("No conflicting UIDs or usernames found.")
    else:
        # Sort by UID, then Username.
        conflict_rows.sort(key=lambda row: (row[0], row[1]))

        def mark(flag):
            return "\u2713" if flag else ""

        # Build Markdown table.
        output_lines.append("| UID | Username | File | Same User | Different User | Same UID | Different UID |")
        output_lines.append("|-----|----------|------|-----------|-----------------|----------|----------------|")
        for uid, username, filepath, same_user, diff_user, same_uid_flag, diff_uid_flag in conflict_rows:
            output_lines.append(
                f"| {uid} | {username} | {filepath} "
                f"| {mark(same_user)} | {mark(diff_user)} | {mark(same_uid_flag)} | {mark(diff_uid_flag)} |"
            )

    report = "\n".join(output_lines)

    # Print to stdout.
    print(report)

    # Also write to conflict_uid.md.
    output_filename = "conflict_uid.md"
    try:
        with open(output_filename, "w") as f:
            f.write(report + "\n")
    except OSError as e:
        print(f"Warning: could not write to {output_filename} ({e})", file=sys.stderr)


if __name__ == "__main__":
    main()
