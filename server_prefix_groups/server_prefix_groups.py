#!/usr/bin/env python3

# This script list zones where server names fall into different naming groups.
# A "group" is defined by the alpha-prefix (letters up to the first digit).
# The input is a CSV file in which the headers are optional. By default, column B contains the server name,
# column D contains the DNS zone, and column E contains the zone type.
# Before processing, the data is filtered. Only zones whose type is either “Primary” or “master” (case-insensitive) are included.
# Zones whose names match any pattern from the IGNORE_ZONE_PATTERNS list are excluded, with matching done case-insensitively and supporting fnmatch wildcards.
# Zones that have fewer rows than the MIN_ROWS_PER_ZONE threshold after filtering are also dropped.
# All comparisons are performed in lowercase to ensure consistent matching, but the original strings from the file are preserved for the output.

import argparse
import sys
import os
import re
import fnmatch
import pandas as pd

# Patterns for zones to ignore (edit as needed)
IGNORE_ZONE_PATTERNS = [
    "*.in-addr.arpa",
    "*.ip6.arpa",
    "_msdcs.*",
    "_sites.*",
    "_tcp.*",
    "_udp.*",
    "forestdnszones.*",
    "domaindnszones.*",
    "_domainkey.*",
    "localhost",
    "trustanchors",
]

# Minimum rows required per zone after filtering to consider it
MIN_ROWS_PER_ZONE = 2

ALPHA_PREFIX_RE = re.compile(r'^([A-Za-z]+)')

def alpha_prefix(s: str) -> str:
    m = ALPHA_PREFIX_RE.match(s)
    return m.group(1).lower() if m else ""

def pick_column(cols, candidates, default_idx):
    for name in candidates:
        for c in cols:
            if str(c).strip().lower() == name:
                return c
    if default_idx < len(cols):
        return cols[default_idx]
    return cols[-1]

def is_ignored_zone(zone: str) -> bool:
    z = (zone or "").lower().strip()
    for pat in IGNORE_ZONE_PATTERNS:
        if fnmatch.fnmatch(z, pat.lower()):
            return True
    return False

def main():
    parser = argparse.ArgumentParser(
        description="List zones (Primary/master) whose server names belong to different naming groups."
    )
    parser.add_argument("input_path", help="Input .csv file")
    args = parser.parse_args()

    input_path = args.input_path
    if not os.path.exists(input_path):
        print(f"Input file not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    if not input_path.lower().endswith(".csv"):
        print("Only .csv is supported.", file=sys.stderr)
        sys.exit(1)

    df = pd.read_csv(input_path)

    # Column mapping (allow header or use positional defaults)
    cols = list(df.columns)
    server_col = pick_column(cols, ['server', 'servername', 'host', 'host_name', 'hostname', 'column_b'], 1)
    zone_col   = pick_column(cols, ['zone', 'dns_zone', 'zonename', 'zone_name', 'column_d'], 3)
    zt_col     = pick_column(cols, ['zone_type', 'type', 'zonetype', 'column_e'], 4)

    # Build working frame: keep originals for output, lowercase for logic
    work = pd.DataFrame({
        'server_orig': df[server_col].astype(str).str.strip(),
        'zone_orig':   df[zone_col].astype(str).str.strip(),
        'zone_type':   df[zt_col].astype(str).str.strip(),
    })
    work['server_lc'] = work['server_orig'].str.lower()
    work['zone_lc']   = work['zone_orig'].str.lower()
    work['zt_lc']     = work['zone_type'].str.lower()

    # Keep only primary/master
    work = work[work['zt_lc'].isin({'primary','master'})]

    # Drop ignored zones
    work = work[~work['zone_lc'].apply(is_ignored_zone)]

    # Drop zones with too few rows to judge
    counts = work['zone_lc'].value_counts()
    keep_zones = set(counts[counts >= MIN_ROWS_PER_ZONE].index)
    work = work[work['zone_lc'].isin(keep_zones)]

    if work.empty:
        # Still write an empty output with headers for consistency
        out_df = pd.DataFrame(columns=['primary_zone','server_names'])
        base, _ = os.path.splitext(input_path)
        out_path = f"{base}_flagged-zones.csv"
        out_df.to_csv(out_path, index=False)
        print(f"No zones to report. Wrote empty {out_path}")
        sys.exit(0)

    # Grouping logic: alpha-prefix (letters up to first digit)
    work['alpha_prefix'] = work['server_lc'].apply(alpha_prefix)

    flagged_rows = []
    for zone_lc, g in work.groupby('zone_lc'):
        unique_prefixes = sorted(set(g['alpha_prefix'].tolist()))
        # If zero or one non-empty group -> consistent, skip
        non_empty = [p for p in unique_prefixes if p != ""]
        if len(set(non_empty)) <= 1:
            continue

        # Collect original server names for output (preserve original casing)
        server_names = sorted(set(g['server_orig'].tolist()), key=lambda x: x.lower())
        # Choose a representative zone string: the most common original case from input
        zorig = g['zone_orig'].mode().iat[0] if not g['zone_orig'].mode().empty else g['zone_orig'].iloc[0]
        flagged_rows.append({'primary_zone': zorig, 'server_names': ", ".join(server_names)})

    out_df = pd.DataFrame(flagged_rows).sort_values('primary_zone') if flagged_rows else pd.DataFrame(columns=['primary_zone','server_names'])

    base, _ = os.path.splitext(input_path)
    out_path = f"{base}_flagged-zones.csv"
    out_df.to_csv(out_path, index=False)
    print(f"Wrote {out_path} ({len(out_df)} zones)")


if __name__ == "__main__":
    main()
