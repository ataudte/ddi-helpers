#!/usr/bin/env python3

# RFC 3397 Domain Search (DHCP Option 119) Encoder
# Generates binary-encoded option data for use in DHCP servers
# Supports compact hex output and Microsoft DHCP "Byte Array" formats

import argparse
import sys
import string

ALLOWED = set(string.ascii_letters + string.digits + "-")

def validate_label(label: str):
    if not label or len(label) > 63:
        raise ValueError(f"Invalid label length: '{label}'")
    if label[0] == "-" or label[-1] == "-":
        raise ValueError(f"Label cannot start or end with '-': '{label}'")
    for ch in label:
        if ch not in ALLOWED:
            raise ValueError(f"Invalid character '{ch}' in label '{label}'")

def encode_domain_search(option_list: str, compress=True) -> bytes:
    """
    RFC1035 label compression within the option
    (offsets are relative to the start of the option value)
    """
    names = [n.strip().strip('.') for n in option_list.split(',') if n.strip()]
    out = bytearray()
    if not compress:
        for name in names:
            labels = name.split('.') if name else []
            for lab in labels:
                validate_label(lab)
                out.append(len(lab))
                out.extend(lab.encode('ascii'))
            out.append(0)
        return bytes(out)

    # Map of suffix tuple -> offset in 'out'
    seen = {}

    def write_name(name: str):
        nonlocal out
        labels = [l for l in name.split('.') if l]
        # Find longest previously-seen suffix
        best_i, best_off = None, None
        for i in range(len(labels)):
            suffix = tuple(labels[i:])
            if suffix in seen:
                best_i, best_off = i, seen[suffix]
                break

        # Emit unmatched prefix; record suffix offsets as we go
        emit = labels[:best_i] if best_i is not None else labels
        for j in range(len(emit)):
            suffix = tuple(labels[j:])
            if suffix not in seen:
                seen[suffix] = len(out)
            lab = emit[j]
            validate_label(lab)
            out.append(len(lab))
            out.extend(lab.encode('ascii'))

        if best_i is not None:
            # compression pointer
            if best_off >= 0x4000:
                raise ValueError("Pointer offset too large for RFC1035 compression")
            ptr = 0xC000 | best_off
            out.extend([(ptr >> 8) & 0xFF, ptr & 0xFF])
        else:
            # terminate name
            if () not in seen:
                seen[()] = len(out)
            out.append(0)

    for n in names:
        write_name(n)

    return bytes(out)

def parse_list(arg: str):
    items = [x.strip().strip(".") for x in arg.split(",")]
    items = [x for x in items if x]
    if not items:
        raise ValueError("No valid domain names provided")
    # validate labels
    for dom in items:
        for p in dom.split("."):
            validate_label(p)
    return items

def hex_bytes(b: bytes, spaced=True):
    h = b.hex()
    return " ".join(h[i:i+2] for i in range(0, len(h), 2)) if spaced else h

def msdhcp_formats(b: bytes):
    # 0xNN per line
    per_line = "\n".join(f"0x{bb:02x}" for bb in b)
    # comma-separated
    csv = ", ".join(f"0x{bb:02x}" for bb in b)
    return per_line, csv

def main():
    p = argparse.ArgumentParser(
        description="Encode a comma-separated domain list for DHCP Option 119 (RFC 3397)."
    )
    p.add_argument("list", help='Quoted comma-separated list, e.g. "corp.example, eng.corp.example"')
    p.add_argument("--no-compress", action="store_true", help="Disable RFC1035 compression")
    p.add_argument("--compact", action="store_true", help="Print compact hex without spaces")
    p.add_argument("--msdhcp", action="store_true",
                   help="Output Microsoft DHCP Byte Array formats (0xNN per line and comma-separated)")
    args = p.parse_args()

    try:
        domains = parse_list(args.list)
        encoded = encode_domain_search(", ".join(domains), compress=not args.no_compress)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(2)

    if args.msdhcp:
        per_line, csv = msdhcp_formats(encoded)
        print("\n# Microsoft DHCP Byte Array (one byte per line)")
        print(per_line)
        print("\n# Microsoft DHCP Byte Array (comma-separated)")
        print(csv)
    else:
        # default: a single hex string; spaced by default, compact if requested
        print(hex_bytes(encoded, spaced=not args.compact))

    # stderr: length hint
    print(f"(length {len(encoded)} bytes)\n", file=sys.stderr)

if __name__ == "__main__":
    main()
