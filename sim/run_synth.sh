#!/usr/bin/env bash
# SPHINCSLET synthesis + hierarchical resource report (Vivado synth_design).
# Config: rtl/sphincslet/setting.v   Override part/top: PART=xc7a200t... TOP=top
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RTL="$ROOT/rtl"
OUT="$ROOT/build/synth"
PART="${PART:-xc7a100tcsg324-1}"
TOP="${TOP:-top}"

if ! command -v vivado >/dev/null 2>&1; then
    VIV="$(ls -d /opt/Xilinx/Vivado/*/settings64.sh /tools/Xilinx/Vivado/*/settings64.sh 2>/dev/null | sort -V | tail -1 || true)"
    [[ -n "${VIV:-}" ]] && source "$VIV" || { echo "ERROR: Vivado not found." >&2; exit 1; }
fi

mkdir -p "$OUT"
none="$(grep -rl 'default_nettype[[:space:]]*none' "$RTL" --include='*.v' | sort)"
hdrs="$RTL/imports/global_include/clog2.v $RTL/imports/global_include/keccak_math.v $RTL/sphincslet/setting.v"
rest="$(find "$RTL" -name '*.v' ! -name clog2.v ! -name keccak_math.v ! -name setting.v ! -name tb.v \
            | sort | grep -vxF "$none" || true)"
files="$hdrs $rest $none"

tcl="$OUT/synth.tcl"
{
    echo "read_verilog [list \\"
    for f in $files; do echo "  $f \\"; done
    echo "]"
    echo "synth_design -top $TOP -part $PART \\"
    echo "  -include_dirs {$RTL/sphincslet $RTL/imports/global_include}"
    echo "report_utilization -hierarchical -file $OUT/util_hier.rpt"
    echo "report_utilization -file $OUT/util_flat.rpt"
    echo "write_checkpoint -force $OUT/${TOP}_synth.dcp"
} > "$tcl"

vivado -mode batch -nojournal -log "$OUT/vivado.log" -source "$tcl"
echo "reports: $OUT/util_hier.rpt (per hierarchy), $OUT/util_flat.rpt"
