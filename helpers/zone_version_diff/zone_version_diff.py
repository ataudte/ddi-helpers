#!/usr/bin/env python3

# This script scans a directory for normalized DNS zone files (via a global glob), groups versions by filename prefix,
# and performs pairwise diffs within each zone. Parses with dnspython, normalizes owners to absolute
# lowercase FQDNs, ignores TTLs, and skips RR types defined in a global ignore set. The zone apex is
# inferred solely from the filename prefix (optionally stripping a leading "db.").
# A global flag excludes “\_msdcs.\*” zones by default. Results go to a fixed report directory: a full
# file list, a unique lowercase zone list, per-zone “only-in” files for each version pair, per-zone
# pairwise-summary CSVs, and a global pairwise-summary CSV.


import argparse
import csv
import glob
import os
import sys
from itertools import combinations
from collections import defaultdict

# =========================
# Global configuration
# =========================
GLOB_PATTERN = "*_*_canon*"                    # e.g., db.example.com_1_canon
IGNORE_TYPES = {"SOA"}                         # add "RRSIG" if DNSSEC sigs are noise
EXCLUDE_MSDCS = True                           # exclude zones like _msdcs.example.com

# Directory constants
OUTPUT_DIR_NAME = "dns_diff_report"
ZONE_DIR_TEMPLATE = "{zone}"                   # subfolder name per zone (safe chars: dots allowed)

# File name constants
FILELIST_NAME = "filelist.txt"                 # list of all matched files (unfiltered)
ZONELIST_NAME = "zonelist.txt"                 # unique list of zones (lowercase; respects EXCLUDE_MSDCS)
GLOBAL_SUMMARY_NAME = "GLOBAL_pairwise_summary.csv"
ERRORS_NAME = "errors.txt"
NOTE_NAME = "note.txt"

# Per-zone file name templates
PAIRWISE_SUMMARY_TEMPLATE = "{zone}_pairwise_summary.csv"
ONLY_IN_TEMPLATE = "{zone}_v{va}-vs-v{vb}_only-in-v{which}.txt"

# =========================
# Dependencies
# =========================
try:
    import dns.zone
    import dns.name
    import dns.rdatatype
except ImportError:
    sys.stderr.write("This script requires dnspython. Install with:\n  pip install dnspython\n")
    sys.exit(1)


# =========================
# Helpers
# =========================
def extract_prefix_ver(fname: str):
    """
    Accepts names like:
      db.example.com_12_canon
      db.example.com_12_canon.txt
    Returns (prefix, version_int) or None if not parseable.
    """
    base = os.path.basename(fname)
    pos = base.rfind("_canon")
    if pos == -1:
        return None
    head = base[:pos]  # "db.example.com_12"
    try:
        prefix, ver_s = head.rsplit("_", 1)  # split on the LAST underscore
    except ValueError:
        return None
    if not ver_s.isdigit():
        return None
    return prefix, int(ver_s)


def collect_groups(root: str) -> dict[str, dict[int, str]]:
    """
    Return dict: {group_key(prefix): {version_number: file_path}},
    where group_key is the part before "_<n>_canon".
    """
    groups: dict[str, dict[int, str]] = defaultdict(dict)
    for p in glob.glob(os.path.join(root, GLOB_PATTERN)):
        res = extract_prefix_ver(os.path.basename(p))
        if not res:
            continue
        prefix, ver = res
        groups[prefix][ver] = p
    return groups


def infer_origin_from_prefix(prefix: str) -> str:
    """
    From a filename prefix like 'db.example.com' or 'example.com' infer the zone origin 'example.com'.
    We strip leading 'db.' if present.
    """
    base = os.path.basename(prefix)
    if base.startswith("db."):
        base = base[3:]
    return base


def parse_zone_records(file_path: str, origin_text: str) -> set[str]:
    """
    Parse zone with dnspython and return a set of canonical record strings:
      "<owner_fqdn> <TYPE> <rdata_text>"
    - TTLs are ignored (not included)
    - Records in IGNORE_TYPES are skipped
    - Owner names are absolute and lowercased
    """
    import dns.zone, dns.name, dns.rdatatype  # local import for clarity
    origin = dns.name.from_text(origin_text if origin_text.endswith(".") else origin_text + ".")
    try:
        z = dns.zone.from_file(
            file_path,
            origin=origin,
            relativize=False,
            allow_include=True,
        )
    except Exception as e:
        raise RuntimeError(f"parse error (origin={origin_text}): {e}")

    recs: set[str] = set()
    for (name, node) in z.nodes.items():
        owner = name.to_text().lower()
        if not owner.endswith("."):
            owner = dns.name.from_text(owner).derelativize(origin).to_text().lower()
        for rdataset in node.rdatasets:
            rtype = dns.rdatatype.to_text(rdataset.rdtype).upper()
            if rtype in IGNORE_TYPES:
                continue
            for rdata in rdataset:
                recs.add(f"{owner} {rtype} {rdata.to_text()}")  # TTL intentionally omitted
    return recs


def ensure_dir(path: str):
    os.makedirs(path, exist_ok=True)


def write_list(path: str, lines: list[str]):
    with open(path, "w", encoding="utf-8") as f:
        for s in lines:
            f.write(s + "\n")


# =========================
# Main
# =========================
def main():
    ap = argparse.ArgumentParser(description="Pairwise diff of multi-version DNS zones (simplified)")
    ap.add_argument("root", help="Directory containing normalized zone files")
    args = ap.parse_args()

    out_root = os.path.join(args.root, OUTPUT_DIR_NAME)
    ensure_dir(out_root)

    # "ls" style listing of all matched files (unfiltered by EXCLUDE_MSDCS)
    matched = sorted(glob.glob(os.path.join(args.root, GLOB_PATTERN)))
    write_list(os.path.join(out_root, FILELIST_NAME), [os.path.relpath(p, args.root) for p in matched])

    groups = collect_groups(args.root)
    if not groups:
        sys.stderr.write("No files matched GLOB_PATTERN; adjust GLOB_PATTERN or check directory.\n")
        sys.exit(2)

    summary_rows = []          # (zone_prefix, va, vb, only_a_count, only_b_count)
    zonenames_lower = set()    # for zonelist.txt

    # Iterate per zone prefix
    for group_key, versions in sorted(groups.items()):
        zone_name = infer_origin_from_prefix(group_key).lower()

        # Optional exclusion of _msdcs.* zones
        if EXCLUDE_MSDCS and zone_name.startswith("_msdcs."):
            continue

        zonenames_lower.add(zone_name)

        zone_dir = os.path.join(out_root, ZONE_DIR_TEMPLATE.format(zone=zone_name))
        ensure_dir(zone_dir)

        recs_by_ver: dict[int, set[str]] = {}
        errors: list[str] = []

        # Parse each version
        for ver, file_path in sorted(versions.items()):
            try:
                recs_by_ver[ver] = parse_zone_records(file_path, zone_name)
            except Exception as e:
                errors.append(f"[v{ver}] {os.path.basename(file_path)}: {e}")

        if errors:
            write_list(os.path.join(zone_dir, ERRORS_NAME), errors)

        if len(recs_by_ver) < 2:
            write_list(os.path.join(zone_dir, NOTE_NAME),
                       [f"Found {len(recs_by_ver)} parsable version(s); need >=2 for diffs."])
            continue

        # Pairwise diffs only
        pair_summary = []
        for (va, vb) in combinations(sorted(recs_by_ver.keys()), 2):
            a = recs_by_ver[va]
            b = recs_by_ver[vb]
            only_a = sorted(a - b)
            only_b = sorted(b - a)

            # Per pair "only-in" files WITH zone name
            only_a_path = os.path.join(
                zone_dir,
                ONLY_IN_TEMPLATE.format(zone=zone_name, va=va, vb=vb, which=va)
            )
            only_b_path = os.path.join(
                zone_dir,
                ONLY_IN_TEMPLATE.format(zone=zone_name, va=va, vb=vb, which=vb)
            )
            write_list(only_a_path, only_a)
            write_list(only_b_path, only_b)

            pair_summary.append((va, vb, len(only_a), len(only_b)))
            summary_rows.append((zone_name, va, vb, len(only_a), len(only_b)))

        # Per-zone summary CSV WITH zone name in filename
        per_zone_summary = os.path.join(zone_dir, PAIRWISE_SUMMARY_TEMPLATE.format(zone=zone_name))
        with open(per_zone_summary, "w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow(["zone", "version_a", "version_b", "only_in_a_count", "only_in_b_count"])
            for (va, vb, ca, cb) in pair_summary:
                w.writerow([zone_name, va, vb, ca, cb])

    # Global zonelist (unique zones, lowercase; respects EXCLUDE_MSDCS)
    write_list(os.path.join(out_root, ZONELIST_NAME), sorted(zonenames_lower))

    # Global summary CSV across zones
    with open(os.path.join(out_root, GLOBAL_SUMMARY_NAME), "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow(["zone", "version_a", "version_b", "only_in_a_count", "only_in_b_count"])
        for row in summary_rows:
            w.writerow(row)

    print(f"Done. Report written to: {os.path.abspath(out_root)}")


if __name__ == "__main__":
    main()
