setup:
	./scripts/setup.sh

activate:
	@echo "Please source the virtual environment activation script:"
	@echo "  source scripts/activate.sh"

build-stone:
	./scripts/cairo-compile.sh src/beacon/main_stone.cairo

build-beacon:
	./scripts/cairo-compile.sh src/beacon/beacon_stwo.cairo

build-execution:
	./scripts/cairo-compile.sh src/execution/execution_stwo.cairo

build-bankai:
	./scripts/cairo-compile.sh src/bankai/bankai_stwo.cairo

format:
	./scripts/format.sh

get-program-hash:
	# @make build
	@echo "BeaconProgramHash:"
	@cairo-hash-program --program build/epoch.json