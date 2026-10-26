#!/usr/bin/env bash

# ==============================================================================
# build.sh - Build Script for Image Resizer for macOS
# Builds Debug and Release .app bundles, runs tests, and packages outputs.
# ==============================================================================

set -euo pipefail

# ANSI Colors
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
NC="\033[0m"

# Project paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="ImageResizer"
PROJECT_FILE="${PROJECT_ROOT}/${PROJECT_NAME}.xcodeproj"
BUILD_DIR="${PROJECT_ROOT}/build"
DERIVED_DATA_DIR="${PROJECT_ROOT}/build/DerivedData"

print_header() {
    echo -e "${BOLD}${BLUE}==>${NC} ${BOLD}$1${NC}"
}

print_success() {
    echo -e "${BOLD}${GREEN}✔ $1${NC}"
}

print_warning() {
    echo -e "${BOLD}${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${BOLD}${RED}✖ $1${NC}" >&2
}

show_usage() {
    cat <<EOF
Usage: ./build.sh [COMMAND] [OPTIONS]

Commands:
  release         Build the optimized Release .app bundle (default)
  debug           Build the Debug .app bundle with debug symbols
  all             Build both Debug and Release .app bundles
  test            Run the complete automated unit test suite
  clean           Clean build artifacts and DerivedData

Options:
  -o, --open      Launch the built .app after successful build
  -h, --help      Show this help message

Examples:
  ./build.sh                     # Build Release .app
  ./build.sh debug               # Build Debug .app
  ./build.sh release --open      # Build Release .app and launch it
  ./build.sh test                # Run unit tests
EOF
}

ensure_xcode_project() {
    if [[ ! -d "${PROJECT_FILE}" ]]; then
        print_header "Generating Xcode project using xcodegen..."
        if command -v xcodegen &> /dev/null; then
            xcodegen generate --spec "${PROJECT_ROOT}/project.yml"
            print_success "Xcode project generated."
        else
            print_error "Xcode project missing and xcodegen is not installed."
            exit 1
        fi
    fi
}

clean_build() {
    print_header "Cleaning build directory..."
    rm -rf "${BUILD_DIR}"
    print_success "Clean complete."
}

run_tests() {
    ensure_xcode_project
    print_header "Running automated unit tests..."

    xcodebuild \
        -project "${PROJECT_FILE}" \
        -scheme "ImageResizerTests" \
        -derivedDataPath "${DERIVED_DATA_DIR}" \
        test

    print_success "All unit tests passed successfully!"
}

build_configuration() {
    local config="$1" # Debug or Release
    local target_output_dir="${BUILD_DIR}/${config}"

    ensure_xcode_project
    print_header "Building ${config} .app bundle..."

    mkdir -p "${target_output_dir}"

    xcodebuild \
        -project "${PROJECT_FILE}" \
        -scheme "${PROJECT_NAME}" \
        -configuration "${config}" \
        -derivedDataPath "${DERIVED_DATA_DIR}" \
        build

    local built_app="${DERIVED_DATA_DIR}/Build/Products/${config}/${PROJECT_NAME}.app"

    if [[ ! -d "${built_app}" ]]; then
        print_error "Expected app not found at: ${built_app}"
        exit 1
    fi

    # Copy built app to output folder
    rm -rf "${target_output_dir}/${PROJECT_NAME}.app"
    cp -R "${built_app}" "${target_output_dir}/"

    local final_app="${target_output_dir}/${PROJECT_NAME}.app"
    print_success "Built ${config} application at:"
    echo "   ${final_app}"

    # Sign locally
    codesign --force --deep --sign - "${final_app}" 2>/dev/null || true

    if [[ "${OPEN_AFTER_BUILD}" == true ]]; then
        print_header "Launching ${final_app}..."
        open "${final_app}"
    fi
}

# Parse options and arguments
CONFIG="release"
OPEN_AFTER_BUILD=false

for arg in "$@"; do
    case "${arg}" in
        release|Release)
            CONFIG="release"
            ;;
        debug|Debug)
            CONFIG="debug"
            ;;
        all|All)
            CONFIG="all"
            ;;
        test|Test)
            CONFIG="test"
            ;;
        clean|Clean)
            CONFIG="clean"
            ;;
        -o|--open)
            OPEN_AFTER_BUILD=true
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown argument: ${arg}"
            show_usage
            exit 1
            ;;
    esac
done

# Main Execution Flow
case "${CONFIG}" in
    clean)
        clean_build
        ;;
    test)
        run_tests
        ;;
    debug)
        build_configuration "Debug"
        ;;
    release)
        build_configuration "Release"
        ;;
    all)
        build_configuration "Debug"
        build_configuration "Release"
        print_success "Both Debug and Release builds completed."
        ;;
esac
