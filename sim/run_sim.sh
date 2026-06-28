#!/usr/bin/env bash
# SPHINCSLET behavioral simulation (Vivado xsim). Config: rtl/sphincslet/setting.v
# Usage: run_sim.sh [build|run|wave|view|clean]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RTL="$ROOT/rtl"
BUILD="$ROOT/build"
RUNDIR="$BUILD/sim/d1/d2/d3"   # 4 levels under BUILD so tb.v's "../../../../" -> BUILD
SNAP="tb_snap"
PROJECT_NAME="TECS_v8"         # must match PROJECT_NAME in tb.v

if ! command -v xvlog >/dev/null 2>&1; then
    VIV="$(ls -d /opt/Xilinx/Vivado/*/settings64.sh /tools/Xilinx/Vivado/*/settings64.sh 2>/dev/null | sort -V | tail -1 || true)"
    [[ -n "${VIV:-}" ]] && source "$VIV" || { echo "ERROR: Vivado xsim not found." >&2; exit 1; }
fi

HDRS=( "$RTL/imports/global_include/clog2.v" "$RTL/imports/global_include/keccak_math.v" "$RTL/sphincslet/setting.v" )
INCDIRS=(-i "$RTL/sphincslet" -i "$RTL/imports/global_include")

collect_sources() {
    # `default_nettype none` files go last so the directive can't leak forward.
    local none rest
    none="$(grep -rl 'default_nettype[[:space:]]*none' "$RTL" --include='*.v' | sort)"
    rest="$(find "$RTL" -name '*.v' ! -name clog2.v ! -name keccak_math.v ! -name setting.v ! -name tb.v \
                | sort | grep -vxF "$none" || true)"
    printf '%s\n' $rest "$RTL/sphincslet/tb.v" $none
}

stage_data() {
    # Copy (not symlink) so tb.v's SIG_file0_*_w.hex output stays under build/.
    local dst="$BUILD/$PROJECT_NAME.srcs/sources_1/imports"
    mkdir -p "$dst"
    cp -ru "$RTL/imports/data_shake" "$dst/"
    cp -ru "$RTL/imports/data_sha2"  "$dst/"
}

do_build() {
    local wave="${1:-0}"
    mkdir -p "$RUNDIR"; stage_data
    local srcs; mapfile -t srcs < <(collect_sources)
    ( cd "$RUNDIR" && xvlog --relax "${INCDIRS[@]}" "${HDRS[@]}" "${srcs[@]}" )
    if [[ "$wave" == "1" ]]; then
        ( cd "$RUNDIR" && xelab --relax -debug all work.tb -s "$SNAP" )
    else
        ( cd "$RUNDIR" && xelab --relax -debug typical work.tb -s "$SNAP" )
    fi
}

case "${1:-run}" in
    build) do_build 0 ;;
    run)   do_build 0; ( cd "$RUNDIR" && xsim "$SNAP" -runall ) ;;
    wave)  do_build 1
           printf 'log_wave -recursive *\nrun -all\nquit\n' > "$RUNDIR/dump.tcl"
           ( cd "$RUNDIR" && xsim "$SNAP" -wdb "$SNAP.wdb" -tclbatch dump.tcl )
           echo "waveform: $RUNDIR/$SNAP.wdb" ;;
    view)  [[ -f "$RUNDIR/$SNAP.wdb" ]] || { echo "no waveform; run: $0 wave" >&2; exit 1; }
           ( cd "$RUNDIR" && xsim --gui "$SNAP.wdb" ) ;;
    clean) rm -rf "$BUILD"; echo "removed $BUILD" ;;
    *) echo "usage: $0 [build|run|wave|view|clean]" >&2; exit 1 ;;
esac
