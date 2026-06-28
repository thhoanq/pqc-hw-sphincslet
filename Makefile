# SPHINCSLET. Config (param set + hash): rtl/sphincslet/setting.v
#   make / make run   - simulate (xsim)
#   make build        - compile + elaborate only
#   make wave / view  - sim with waveform / open it
#   make synth        - synthesis + hierarchical resource report
#   make clean        - remove build/
# Synthesis/simulation are slow; PART=<part> overrides the synth target.

.PHONY: all run build wave view synth clean
all: run

run:   ; @sim/run_sim.sh run
build: ; @sim/run_sim.sh build
wave:  ; @sim/run_sim.sh wave
view:  ; @sim/run_sim.sh view
synth: ; @sim/run_synth.sh
clean: ; @sim/run_sim.sh clean
