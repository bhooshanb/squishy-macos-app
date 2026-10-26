#!/usr/bin/env bash

# ==============================================================================
# build.sh - Build Script for Image Resizer for macOS
# Builds Debug, Release, and Universal (Apple Silicon + Intel) .app bundles.
# ==============================================================================

set -euo pipefail

# ANSI Colors
BOLD="\033[1m"
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[0;33m"
CYAN="\033[0;36m"
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

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
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
  universal       Build a Universal 2 binary (Apple Silicon arm64 + Intel x86_64)
  debug           Build the Debug .app bundle with debug symbols
  all             Build Debug, Release, and Universal .app bundles
  test            Run the complete automated unit test suite
  clean           Clean build artifacts and DerivedData

Options:
  -u, --universal Build as Universal binary (arm64 + x86_64) for any command
  -o, --open      Launch the built .app after successful build
  -h, --help      Show this help message

Examples:
  ./build.sh                     # Build standard Release .app
  ./build.sh universal           # Build Universal 2 Release .app (arm64 + x86_64)
  ./build.sh release --universal # Same as above
  ./build.sh debug               # Build Debug .app
  ./build.sh universal --open    # Build Universal .app and launch it
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
    local is_universal="$2" # true or false
    local label="${config}"
    if [[ "${is_universal}" == true ]]; then
        label="${config}-Universal"
    fi

    local target_output_dir="${BUILD_DIR}/${label}"

    ensure_xcode_project
    print_header "Building ${label} .app bundle..."

    mkdir -p "${target_output_dir}"

    local extra_args=()
    if [[ "${is_universal}" == true ]]; then
        print_info "Targeting Universal architectures: arm64 (Apple Silicon) + x86_64 (Intel)"
        extra_args+=(ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO)
    fi

    xcodebuild \
        -project "${PROJECT_FILE}" \
        -scheme "${PROJECT_NAME}" \
        -configuration "${config}" \
        -derivedDataPath "${DERIVED_DATA_DIR}" \
        "${extra_args[@]}" \
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
    local binary="${final_app}/Contents/MacOS/${PROJECT_NAME}"

    # Sign locally
    codesign --force --deep --sign - "${final_app}" 2>/dev/null || true

    print_success "Built ${label} application at:"
    echo "   ${final_app}"

    if [[ -f "${binary}" ]]; then
        local arch_info
        arch_info=$(lipo -info "${binary}" 2>/dev/null || file "${binary}")
        print_info "${arch_info}"
    fi

    if [[ "${OPEN_AFTER_BUILD}" == true ]]; then
        print_header "Launching ${final_app}..."
        open "${final_app}"
    fi
}

# Parse options and arguments
COMMAND="release"
IS_UNIVERSAL=false
OPEN_AFTER_BUILD=false

for arg in "$@"; do
    case "${arg}" in
        release|Release)
            COMMAND="release"
            ;;
        universal|Universal)
            COMMAND="universal"
            IS_UNIVERSAL=true
            ;;
        debug|Debug)
            COMMAND="debug"
            ;;
        all|All)
            COMMAND="all"
            ;;
        test|Test)
            COMMAND="test"
            ;;
        clean|Clean)
            COMMAND="clean"
            ;;
        -u|--universal)
            IS_UNIVERSAL=true
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
case "${COMMAND}" in
    clean)
        clean_build
        ;;
    test)
        run_tests
        ;;
    debug)
        build_configuration "Debug" "${IS_UNIVERSAL}"
        ;;
    release)
        build_configuration "Release" "${IS_UNIVERSAL}"
        ;;
    universal)
        build_configuration "Release" true
        ;;
    all)
        build_configuration "Debug" false
        build_configuration "Release" false
        build_configuration "Release" true
        print_success "Debug, Release, and Universal builds completed."
        ;;
esac
