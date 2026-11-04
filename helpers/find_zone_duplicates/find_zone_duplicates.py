#!/usr/bin/env python3

# This script detects duplicated authoritative zones (Zone Type: Primary/master) defined on multiple servers,
# optionally filters out reverse zones (*.in-addr.arpa, *.ip6.arpa), outputs a sorted CSV with all matching rows grouped by zone and server.

import sys
import pandas as pd
from pathlib import Path

# Global toggle: set to True to exclude reverse DNS zones
IGNORE_REVERSE_ZONES = True

# Ensure input file is provided
if len(sys.argv) < 2:
    print("Usage: ./find_zone_duplicates.py <input_csv_file>")
    sys.exit(1)

input_file = sys.argv[1]
input_path = Path(input_file)
output_file = input_path.with_name(f"{input_path.stem}_duplicates{input_path.suffix}")

# Load CSV
df = pd.read_csv(input_file)

# Clean up column names
df.columns = [col.strip() for col in df.columns]

# Normalize Zone Type and filter for authoritative zones (Primary or master)
auth_types = ["primary", "master"]
df["Zone Type Normalized"] = df["Zone Type"].astype(str).str.strip().str.lower()
auth_zones = df[df["Zone Type Normalized"].isin(auth_types)]

# Optionally filter out reverse DNS zones (case-insensitive)
if IGNORE_REVERSE_ZONES:
    auth_zones = auth_zones[
        ~auth_zones["Zone Name"].astype(str).str.lower().str.endswith(("in-addr.arpa", "ip6.arpa"))
    ]

# Count distinct servers per zone name
zone_server_counts = auth_zones.groupby("Zone Name")["Server Name"].nunique()
duplicated_zone_names = zone_server_counts[zone_server_counts > 1].index.tolist()

# Extract all authoritative rows for duplicated zones
duplicates_detailed = auth_zones[auth_zones["Zone Name"].isin(duplicated_zone_names)]

# Sort output for grouping by Zone Name and Server Name
duplicates_detailed = duplicates_detailed.sort_values(by=["Zone Name", "Server Name"])

# Drop helper column
duplicates_detailed = duplicates_detailed.drop(columns=["Zone Type Normalized"])

# Save output CSV
duplicates_detailed.to_csv(output_file, index=False)

# Print result summary
print("Done.")
print(f"Found {len(duplicated_zone_names)} duplicated authoritative zones.")
print(f"These zones account for {len(duplicates_detailed)} authoritative rows.")
print(f"Output written to: {output_file}")
