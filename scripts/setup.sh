#!/bin/bash
# Check if python3.10 is installed
if ! command -v python3.10 >/dev/null; then
    echo "python3.10 is not installed. Please install Python 3.10 and try again."
    case "$OSTYPE" in
        linux-gnu*)
            echo "On Debian/Ubuntu, you can install it with: sudo apt-get install python3.10"
            echo "On Fedora, you can install it with: sudo dnf install python3.10"
            ;;
        darwin*)
            echo "On macOS, you can install it with Homebrew: brew install python@3.10"
            ;;
        *)
            echo "Please refer to your operating system's documentation for installing Python 3.10."
            ;;
    esac
    exit 1
fi

# Check if venv module is available
if ! python3.10 -m venv --help >/dev/null 2>&1; then
    echo "The venv module is not available in your Python 3.10 installation."
    case "$OSTYPE" in
        linux-gnu*)
            echo "On Debian/Ubuntu, you can install it with: sudo apt-get install python3.10-venv"
            echo "On Fedora, you can install it with: sudo dnf install python3.10-venv"
            ;;
        darwin*)
            echo "On macOS, ensure your Python 3.10 installation includes the venv module."
            ;;
        *)
            echo "Please refer to your operating system's documentation for installing the venv module."
            ;;
    esac
    exit 1
fi

mkdir -p cairo/build

# Create virtual environment
if ! python3.10 -m venv venv; then
    echo "Failed to create virtual environment with python3.10"
    exit 1
fi

source venv/bin/activate

pip install uv
uv pip install -r scripts/requirements.txt

deactivate

echo "Setup Complete!"