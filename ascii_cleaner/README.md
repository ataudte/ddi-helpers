# ascii_cleaner.py

## Description
Convert flat export files to ASCII for legacy import tools. Processes all files with a given extension in a target folder, preferring `iconv` UTF‑8→ASCII with transliteration, then `iconv` with `//ignore`, and finally a Python fallback that applies a German transliteration map (Ä→Ae, Ö→Oe, Ü→Ue, ä→ae, ö→oe, ü→ue, ß→ss). Cleaned files go to `ascii_cleaned/`; detailed per‑file logs for issues go to `ascii_cleaned/logs/`.

## Usage
```bash
# Basic (non‑recursive):
python ascii_cleaner.py <extension> <folder>

# Example:
python ascii_cleaner.py qef /path/to/folder

# Recursive mode:
python ascii_cleaner.py qef /path/to/folder --recursive

# Strategy:
#   translit (default): iconv //translit → //ignore → Python fallback (DE map)
#   ignore:            iconv //ignore first → Python fallback if needed
#   strict:            fail iconv then force Python fallback with DE map
python ascii_cleaner.py qef /path/to/folder --strategy translit

# Disable Python fallback (still logs issues):
python ascii_cleaner.py qef /path/to/folder --no-fallback
```

## Options

- `--recursive`  
  Recurse into subdirectories to process matching files.

- `--strategy {translit|ignore|strict}` (default: `translit`)  
  Controls conversion path:
  - **translit**: prefer readable transliteration; ignore only if needed; fallback last
  - **ignore**: drop unmappable chars early via iconv
  - **strict**: treat any unmappable as issue and force Python fallback w/ German mapping

- `--no-fallback`  
  Disable Python fallback; still writes logs so you can fix sources or rerun with a different strategy.


## Requirements

- Python **3.9+** (stdlib only; no extra packages)
- `iconv` available on PATH recommended for best results (GNU libiconv or BSD/macOS `iconv`)


## Notes

- **Output layout**:  
  - Cleaned files → `<folder>/ascii_cleaned/`  
  - Log files (on issues only) → `<folder>/ascii_cleaned/logs/filename.log`

- **Logs include**: exact line and column of each non‑ASCII occurrence, Unicode code point and name, short context excerpt, and `iconv` stderr (if any).

- **German transliteration**: Python fallback applies `Ä→Ae, Ö→Oe, Ü→Ue, ä→ae, ö→oe, ü→ue, ß→ss` before Unicode decomposition and ASCII stripping.

- **Console output** is minimal per file: `OK filename` or `ISSUE filename → logs/<file>.log`.  
  A final summary prints counts of OK/ISSUE.

- **macOS iconv** can be stricter with `//TRANSLIT`; the script handles this via `//ignore` or fallback.


## License
This script is covered under the repository’s main [MIT License](../LICENSE).
