#!/bin/bash

set -e

INPUT_ROM="base.sfc"
OUTPUT_ROM="out/sm-coop.sfc"
OUTPUT_IPS="out/sm-coop.ips"
REFERENCE_IPS="base.ips"

# flips
case "$(uname -s)" in
    MINGW*|MSYS*|CYGWIN*) BUNDLED_FLIPS=tools/flips.exe ;;
    *) BUNDLED_FLIPS=tools/flips-linux ;;
esac
FLIPS="$(command -v flips || echo "$BUNDLED_FLIPS")"
# filter out noisy gtk messages from flips
flips() { "$FLIPS" "$@" 2> >(grep -v Gtk-Message >&2); }

# create output rom
mkdir -p out
cp "$INPUT_ROM" "$OUTPUT_ROM"
chmod u+w "$OUTPUT_ROM"

# assemble patches
asar --fix-checksum=off --symbols=wla sm-coop.asm "$OUTPUT_ROM"
python3 tools/checksum.py "$OUTPUT_ROM"

# create .ips
flips --create --ips "$INPUT_ROM" "$OUTPUT_ROM" "$OUTPUT_IPS"

echo "Build complete! Output written to $OUTPUT_ROM and $OUTPUT_IPS"

# verify against the reference patch
if [ -f "$REFERENCE_IPS" ]; then
    flips --apply "$REFERENCE_IPS" "$INPUT_ROM" out/expected.sfc
    if cmp -s out/expected.sfc "$OUTPUT_ROM"; then
        echo "OK: rom matches $INPUT_ROM + $REFERENCE_IPS"
    else
        echo "MISMATCH vs $INPUT_ROM + $REFERENCE_IPS:"
        cmp -l out/expected.sfc "$OUTPUT_ROM" | head -20
        exit 1
    fi
fi
