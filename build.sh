#!/usr/bin/env bash

# ==============================================================================
# build.sh - Build & Release Automation for Squishy (Silverstone Labs)
# Automatically updates version numbers, manages Sparkle appcast,
# and builds Debug, Release, and Universal (arm64 + x86_64) .app bundles.
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
APP_NAME="Squishy"
PROJECT_FILE="${PROJECT_ROOT}/${PROJECT_NAME}.xcodeproj"
BUILD_DIR="${PROJECT_ROOT}/build"
DERIVED_DATA_DIR="${PROJECT_ROOT}/build/DerivedData"
VERSION_FILE="${PROJECT_ROOT}/VERSION"
APPCAST_FILE="${PROJECT_ROOT}/appcast.xml"

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

# Version and Git helpers
get_version() {
    if [[ -f "${VERSION_FILE}" ]]; then
        cat "${VERSION_FILE}" | tr -d '[:space:]'
    else
        echo "1.0.0"
    fi
}

get_build_number() {
    git -C "${PROJECT_ROOT}" rev-list --count HEAD 2>/dev/null || echo "1"
}

get_feed_url() {
    local remote_url
    remote_url=$(git -C "${PROJECT_ROOT}" config --get remote.origin.url 2>/dev/null || echo "")
    if [[ "${remote_url}" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)? ]]; then
        local owner="${BASH_REMATCH[1]}"
        local repo="${BASH_REMATCH[2]}"
        local branch
        branch=$(git -C "${PROJECT_ROOT}" branch --show-current 2>/dev/null || echo "master")
        echo "https://raw.githubusercontent.com/${owner}/${repo}/${branch}/appcast.xml"
    else
        echo "https://raw.githubusercontent.com/bhooshanb/squishy-macos-app/master/appcast.xml"
    fi
}

get_repo_slug() {
    local remote_url
    remote_url=$(git -C "${PROJECT_ROOT}" config --get remote.origin.url 2>/dev/null || echo "")
    if [[ "${remote_url}" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)? ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    else
        echo "bhooshanb/squishy-macos-app"
    fi
}

show_usage() {
    cat <<EOF
Usage: ./build.sh [COMMAND] [OPTIONS]

Commands:
  release         Build the optimized Release .app bundle and update appcast (default)
  universal       Build a Universal 2 binary (arm64 + x86_64) and update appcast
  debug           Build the Debug .app bundle with debug symbols
  all             Build Debug, Release, and Universal .app bundles
  test            Run the complete automated unit test suite
  appcast         Package built app into zip and update Sparkle appcast.xml
  version [v]     Display or bump marketing version (e.g. ./build.sh version 1.0.1)
  clean           Clean build artifacts and DerivedData

Options:
  -u, --universal Build as Universal binary (arm64 + x86_64) for any command
  -o, --open      Launch the built .app after successful build
  -h, --help      Show this help message

Version & Sparkle Info:
  Current Version:  $(get_version) (Build $(get_build_number))
  Sparkle Feed URL: $(get_feed_url)
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

    local version="$(get_version)"
    local build_num="$(get_build_number)"

    xcodebuild \
        -project "${PROJECT_FILE}" \
        -scheme "ImageResizerTests" \
        -derivedDataPath "${DERIVED_DATA_DIR}" \
        MARKETING_VERSION="${version}" \
        CURRENT_PROJECT_VERSION="${build_num}" \
        test

    print_success "All unit tests passed successfully!"
}

update_sparkle_appcast() {
    local target_app="$1"
    local version="$(get_version)"
    local build_num="$(get_build_number)"
    local repo_slug="$(get_repo_slug)"
    local feed_url="$(get_feed_url)"

    if [[ ! -d "${target_app}" ]]; then
        print_error "Cannot update appcast: Application bundle not found at ${target_app}"
        return 1
    fi

    print_header "Updating Sparkle appcast.xml for v${version} (build ${build_num})..."

    local parent_dir="$(dirname "${target_app}")"
    local zip_file="${parent_dir}/${APP_NAME}.zip"

    # Create clean zip for Sparkle distribution
    print_info "Creating distribution archive: ${zip_file}..."
    rm -f "${zip_file}"
    (cd "${parent_dir}" && ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "${zip_file}")

    local file_size
    file_size=$(stat -f%z "${zip_file}" 2>/dev/null || echo "0")
    local pub_date
    pub_date=$(date -Ru 2>/dev/null || date)

    local download_url="https://github.com/${repo_slug}/releases/download/release/${APP_NAME}.zip"

    # Write or update appcast.xml
    cat <<EOF > "${APPCAST_FILE}"
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>Squishy Updates</title>
    <link>${feed_url}</link>
    <description>Most recent updates for Squishy by Silverstone Labs</description>
    <language>en</language>
    <item>
      <title>Squishy ${version}</title>
      <pubDate>${pub_date}</pubDate>
      <sparkle:version>${build_num}</sparkle:version>
      <sparkle:shortVersionString>${version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <description><![CDATA[
        <h2>Squishy ${version}</h2>
        <ul>
          <li>Fast, non-distorting native macOS image resizing utility.</li>
          <li>Social media aspect ratio presets, 1-click ratio inversion, and synchronized tabs.</li>
          <li>Created by Silverstone Labs.</li>
        </ul>
      ]]></description>
      <enclosure
        url="${download_url}"
        sparkle:version="${build_num}"
        sparkle:shortVersionString="${version}"
        length="${file_size}"
        type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF

    print_success "Generated ${APPCAST_FILE} with version ${version} (build ${build_num})"
    print_info "Enclosure download URL: ${download_url} (${file_size} bytes)"
}

build_configuration() {
    local config="$1" # Debug or Release
    local is_universal="$2" # true or false
    local label="${config}"
    if [[ "${is_universal}" == true ]]; then
        label="${config}-Universal"
    fi

    local target_output_dir="${BUILD_DIR}/${label}"
    local version="$(get_version)"
    local build_num="$(get_build_number)"

    ensure_xcode_project
    print_header "Building ${label} ${APP_NAME}.app bundle (v${version}, build ${build_num})..."

    mkdir -p "${target_output_dir}"

    if [[ "${is_universal}" == true ]]; then
        print_info "Targeting Universal architectures: arm64 (Apple Silicon) + x86_64 (Intel)"
        xcodebuild \
            -project "${PROJECT_FILE}" \
            -scheme "${PROJECT_NAME}" \
            -configuration "${config}" \
            -derivedDataPath "${DERIVED_DATA_DIR}" \
            MARKETING_VERSION="${version}" \
            CURRENT_PROJECT_VERSION="${build_num}" \
            "ARCHS=arm64 x86_64" \
            ONLY_ACTIVE_ARCH=NO \
            build
    else
        xcodebuild \
            -project "${PROJECT_FILE}" \
            -scheme "${PROJECT_NAME}" \
            -configuration "${config}" \
            -derivedDataPath "${DERIVED_DATA_DIR}" \
            MARKETING_VERSION="${version}" \
            CURRENT_PROJECT_VERSION="${build_num}" \
            build
    fi

    local built_app="${DERIVED_DATA_DIR}/Build/Products/${config}/${APP_NAME}.app"
    if [[ ! -d "${built_app}" ]]; then
        built_app="${DERIVED_DATA_DIR}/Build/Products/${config}/${PROJECT_NAME}.app"
    fi

    if [[ ! -d "${built_app}" ]]; then
        print_error "Expected app not found at: ${built_app}"
        exit 1
    fi

    # Copy built app to output folder
    rm -rf "${target_output_dir}/${APP_NAME}.app"
    cp -R "${built_app}" "${target_output_dir}/"

    local final_app="${target_output_dir}/${APP_NAME}.app"
    local binary="${final_app}/Contents/MacOS/${APP_NAME}"
    if [[ ! -f "${binary}" ]]; then
        binary="${final_app}/Contents/MacOS/${PROJECT_NAME}"
    fi

    # Sign locally
    codesign --force --deep --sign - "${final_app}" 2>/dev/null || true

    print_success "Built ${label} application at:"
    echo "   ${final_app}"

    if [[ -f "${binary}" ]]; then
        local arch_info
        arch_info=$(lipo -info "${binary}" 2>/dev/null || file "${binary}")
        print_info "${arch_info}"
    fi

    # For Release and Universal builds, update Sparkle appcast automatically
    if [[ "${config}" == "Release" ]]; then
        update_sparkle_appcast "${final_app}"
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
NEW_VERSION_ARG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        release|Release)
            COMMAND="release"
            shift
            ;;
        universal|Universal)
            COMMAND="universal"
            IS_UNIVERSAL=true
            shift
            ;;
        debug|Debug)
            COMMAND="debug"
            shift
            ;;
        all|All)
            COMMAND="all"
            shift
            ;;
        test|Test)
            COMMAND="test"
            shift
            ;;
        clean|Clean)
            COMMAND="clean"
            shift
            ;;
        appcast|Appcast)
            COMMAND="appcast"
            shift
            ;;
        version|Version)
            COMMAND="version"
            shift
            if [[ $# -gt 0 && ! "$1" =~ ^- ]]; then
                NEW_VERSION_ARG="$1"
                shift
            fi
            ;;
        -u|--universal)
            IS_UNIVERSAL=true
            shift
            ;;
        -o|--open)
            OPEN_AFTER_BUILD=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown argument: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main Execution Flow
case "${COMMAND}" in
    version)
        if [[ -n "${NEW_VERSION_ARG}" ]]; then
            echo "${NEW_VERSION_ARG}" > "${VERSION_FILE}"
            print_success "Updated VERSION to ${NEW_VERSION_ARG}"
            if command -v xcodegen &> /dev/null; then
                xcodegen generate --spec "${PROJECT_ROOT}/project.yml" >/dev/null 2>&1 || true
            fi
        else
            echo "Version: $(get_version)"
            echo "Build:   $(get_build_number)"
            echo "Feed:    $(get_feed_url)"
        fi
        ;;
    clean)
        clean_build
        ;;
    test)
        run_tests
        ;;
    appcast)
        target_app=""
        if [[ -d "${BUILD_DIR}/Release-Universal/${APP_NAME}.app" ]]; then
            target_app="${BUILD_DIR}/Release-Universal/${APP_NAME}.app"
        elif [[ -d "${BUILD_DIR}/Release/${APP_NAME}.app" ]]; then
            target_app="${BUILD_DIR}/Release/${APP_NAME}.app"
        else
            print_warning "No built release app found. Building Release first..."
            build_configuration "Release" false
            target_app="${BUILD_DIR}/Release/${APP_NAME}.app"
        fi
        update_sparkle_appcast "${target_app}"
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
