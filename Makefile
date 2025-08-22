setup:
	./scripts/setup.sh

activate:
	@echo "Please source the virtual environment activation script:"
	@echo "  source scripts/activate.sh"

build-cairo:
	./scripts/cairo-compile.sh src/beacon/main.cairo

format:
	./scripts/format.sh

get-program-hash:
	# @make build
	@echo "BeaconProgramHash:"
	@cairo-hash-program --program build/epoch.json