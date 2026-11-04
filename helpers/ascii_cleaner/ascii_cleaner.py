#!/usr/bin/env python3

# This script converts all files with a given extension in a folder to ASCII for legacy import tools.
# Tries iconv UTF8 to ASCII with transliteration. If iconv warns or fails, tries iconv with ignore.
# If that fails or the chosen strategy requires it, falls back to Python cleaning with German transliteration
# (Ä to Ae, Ö to Oe, Ü to Ue, ä to ae, ö to oe, ü to ue, ß to ss).
# Writes cleaned files to ascii_cleaned and file specific logs to ascii_cleaned/logs when issues occur.
# Logs include exact line and column numbers of each non ASCII character, a short context excerpt, and iconv stderr.

import sys, argparse, pathlib, subprocess, unicodedata, datetime
from collections import Counter

GERMAN_MAP = {
    "Ä": "Ae", "Ö": "Oe", "Ü": "Ue",
    "ä": "ae", "ö": "oe", "ü": "ue",
    "ß": "ss",
}

def now_iso():
    return datetime.datetime.now().isoformat(timespec="seconds")

def ascii_transliterate_with_de_map(text: str) -> str:
    # Apply explicit German mapping first
    for k, v in GERMAN_MAP.items():
        text = text.replace(k, v)
    # Decompose & drop combining marks
    decomp = unicodedata.normalize("NFKD", text)
    no_marks = "".join(ch for ch in decomp if not unicodedata.combining(ch))
    # Keep ASCII only (drop anything left)
    return no_marks.encode("ascii", "ignore").decode("ascii")

def try_iconv(infile: pathlib.Path, mode: str):
    """
    mode: 'translit' | 'ignore' | 'strict'
    Returns (ok, stdout, stderr)
    """
    tflag = "ascii"
    if mode == "translit":
        tflag += "//translit"
    elif mode == "ignore":
        tflag += "//ignore"
    cmd = ["iconv", "-f", "utf-8", "-t", tflag, str(infile)]
    try:
        r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        return r.returncode == 0, r.stdout, r.stderr.strip()
    except FileNotFoundError:
        return False, "", "iconv not found"

def scan_non_ascii_positions(text: str, context_chars=30):
    """
    Return dict with:
      - positions: list of dicts {line, col, char, codepoint, name, context}
      - counts: Counter of chars
      - lines_set: set of line numbers
    """
    positions = []
    counts = Counter()
    lines_set = set()

    line = 1
    col = 1
    for i, ch in enumerate(text):
        if ch == "\n":
            line += 1
            col = 1
            continue
        if ord(ch) > 127 or ch == "\uFFFD":
            cp = f"U+{ord(ch):04X}"
            try:
                name = unicodedata.name(ch)
            except ValueError:
                name = "<unnamed>"
            # Build context
            start = max(0, i - context_chars)
            end = min(len(text), i + context_chars)
            excerpt = text[start:end].replace("\n", "\\n")
            positions.append({
                "line": line, "col": col, "char": ch, "cp": cp, "name": name,
                "context": excerpt
            })
            counts[ch] += 1
            lines_set.add(line)
        col += 1

    return {"positions": positions, "counts": counts, "lines_set": lines_set}

def write_issue_log(logfile: pathlib.Path, infile: pathlib.Path, outcome: str,
                    iconv_err_primary: str, iconv_err_ignore: str, original_text: str):
    """
    Write a file-specific log with full diagnostics.
    """
    scan = scan_non_ascii_positions(original_text)
    positions = scan["positions"]
    counts = scan["counts"]
    lines = sorted(scan["lines_set"])

    with logfile.open("w", encoding="utf-8") as f:
        f.write(f"# ASCII conversion log\n")
        f.write(f"file: {infile}\n")
        f.write(f"time: {now_iso()}\n")
        f.write(f"outcome: {outcome}\n")
        if iconv_err_primary:
            f.write("\n## iconv (primary) stderr\n")
            f.write(iconv_err_primary + "\n")
        if iconv_err_ignore:
            f.write("\n## iconv (ignore) stderr\n")
            f.write(iconv_err_ignore + "\n")

        f.write("\n## Non-ASCII analysis (original content)\n")
        if not positions:
            f.write("No non-ASCII characters detected in decoded text.\n")
        else:
            total = sum(counts.values())
            f.write(f"total_non_ascii: {total}\n")
            f.write(f"unique_non_ascii: {len(counts)}\n")
            f.write("top_non_ascii:\n")
            for ch, cnt in counts.most_common(20):
                try:
                    name = unicodedata.name(ch)
                except ValueError:
                    name = "<unnamed>"
                mapped = GERMAN_MAP.get(ch, "")
                map_str = f"  -> mapped_to: '{mapped}'" if mapped else ""
                f.write(f"  {repr(ch)} U+{ord(ch):04X} {name} x{cnt}{map_str}\n")

            f.write("\nexact_line_numbers:\n")
            # Print as a compact, comma-separated list
            f.write(", ".join(str(n) for n in lines) + "\n")

            f.write("\nfirst_occurrences (up to 50):\n")
            for idx, pos in enumerate(positions[:50], 1):
                mapped = GERMAN_MAP.get(pos["char"], "")
                map_str = f" | mapped_to='{mapped}'" if mapped else ""
                f.write(
                    f"{idx:02d}) line {pos['line']} col {pos['col']} "
                    f"{repr(pos['char'])} {pos['cp']} {pos['name']}{map_str}\n"
                    f"    context: ...{pos['context']}...\n"
                )

def process_one(infile: pathlib.Path, outdir: pathlib.Path, strategy: str, fallback: bool, logs_dir: pathlib.Path):
    """
    Returns (status, console_message)
    status ∈ {'OK','ISSUE'}
    """
    outfile = outdir / infile.name
    logpath = logs_dir / (infile.stem + ".log")

    # Try iconv (primary)
    ok, data, err1 = try_iconv(infile, "translit" if strategy == "translit" else strategy)
    if ok and not err1:
        outfile.write_text(data, encoding="ascii", errors="strict")
        return "OK", f"OK     {infile.name}"

    # If iconv primary succeeded but had stderr warnings → log as issue anyway
    if ok and err1:
        outfile.write_text(data, encoding="ascii", errors="strict")
        original = infile.read_bytes().decode("utf-8", errors="replace")
        write_issue_log(logpath, infile, "iconv_translit_with_warnings", err1, "", original)
        return "ISSUE", f"ISSUE  {infile.name} → logs/{logpath.name}"

    # Try iconv(ignore)
    ok2, data2, err2 = try_iconv(infile, "ignore")
    if ok2:
        outfile.write_text(data2, encoding="ascii", errors="strict")
        original = infile.read_bytes().decode("utf-8", errors="replace")
        write_issue_log(logpath, infile, "iconv_ignore", err1 or "", err2 or "", original)
        return "ISSUE", f"ISSUE  {infile.name} → logs/{logpath.name}"

    # Fallback
    if not fallback:
        original = infile.read_bytes().decode("utf-8", errors="replace")
        write_issue_log(logpath, infile, "error_no_fallback", err1 or "", err2 or "", original)
        return "ISSUE", f"ISSUE  {infile.name} → logs/{logpath.name}"

    raw = infile.read_bytes()
    try:
        original = raw.decode("utf-8")  # prefer strict decode if possible
    except UnicodeDecodeError:
        original = raw.decode("utf-8", errors="replace")

    cleaned = ascii_transliterate_with_de_map(original)
    outfile.write_text(cleaned, encoding="ascii", errors="strict")
    write_issue_log(logpath, infile, "python_fallback_de_map", err1 or "", err2 or "", original)
    return "ISSUE", f"ISSUE  {infile.name} → logs/{logpath.name}"

def main():
    ap = argparse.ArgumentParser(description="Convert files to ASCII with diagnostics and per-file logs on issues.")
    ap.add_argument("extension", help="e.g. qef (no dot)")
    ap.add_argument("folder", help="base folder")
    ap.add_argument("--strategy", choices=["translit","ignore","strict"], default="translit",
                    help="translit=best effort (default); ignore=drops unmappables; strict=fails if any unmappable (then fallback)")
    ap.add_argument("--recursive", action="store_true", help="recurse into subdirectories")
    ap.add_argument("--no-fallback", action="store_true", help="disable Python fallback")
    args = ap.parse_args()

    base = pathlib.Path(args.folder)
    if not base.is_dir():
        print(f"Error: {base} is not a directory", file=sys.stderr); sys.exit(1)

    outdir = base / "ascii_cleaned"
    logs_dir = outdir / "logs"
    outdir.mkdir(exist_ok=True)
    logs_dir.mkdir(exist_ok=True)

    pattern = f"**/*.{args.extension}" if args.recursive else f"*.{args.extension}"
    files = [p for p in base.glob(pattern) if p.is_file()]
    if not files:
        print(f"No .{args.extension} files found in {base}")
        return

    ok_count = 0
    issue_count = 0
    for f in sorted(files):
        status, msg = process_one(f, outdir, args.strategy, not args.no_fallback, logs_dir)
        print(msg)
        if status == "OK":
            ok_count += 1
        else:
            issue_count += 1

    print(f"\nSummary: OK={ok_count}  ISSUE={issue_count}")

if __name__ == "__main__":
    main()
