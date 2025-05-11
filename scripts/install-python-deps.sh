#!/bin/bash
set -e

# Script to install Python dependencies

# Error handling function
handle_error() {
    echo "ERROR: $1"
    exit 1
}

# Check if pip is installed
if ! command -v pip3 &> /dev/null; then
    echo "pip3 not found. Installing pip..."

    # Check if Python is installed
    if ! command -v python3 &> /dev/null; then
        handle_error "Python 3 not found. Please install Python 3 first."
    fi

    # Install pip using easy_install or curl
    if command -v easy_install-3 &> /dev/null; then
        echo "Installing pip using easy_install..."
        easy_install-3 pip
    else
        echo "Installing pip using curl..."
        curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
        python3 get-pip.py
        rm get-pip.py
    fi
fi

# Check if requirements.txt exists
if [ ! -f "requirements.txt" ]; then
    # Create a minimal requirements.txt if it doesn't exist
    echo "kafka-python>=2.0.0" > requirements.txt
    echo "Created minimal requirements.txt with kafka-python dependency"
fi

# Install dependencies
echo "Installing Python dependencies..."
if ! pip3 install -r requirements.txt; then
    handle_error "Failed to install Python dependencies"
fi

echo "Python dependencies installed successfully!"
