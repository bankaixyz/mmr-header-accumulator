#!/bin/bash

PROGRAM_PATH=${1:-"src/beacon/main.cairo"}  # Default to main.cairo if no argument provided
OUTPUT_NAME=$(basename "$PROGRAM_PATH" .cairo)  # Extract filename without path and extension

echo "Compiling Cairo Program: $PROGRAM_PATH"
cairo-compile "$PROGRAM_PATH" --output "build/${OUTPUT_NAME}.json" --no_debug_info

if [ $? -eq 0 ]; then
    echo "Compilation Successful!"
fi