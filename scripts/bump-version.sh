#!/bin/sh
set -eu

source_root=${SRCROOT:-$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)}
version_file="${source_root}/VERSION"
if [ ! -f "$version_file" ]; then
  printf '%s\n' "1.0.0" > "$version_file"
fi

version=$(tr -d '[:space:]' < "$version_file")
case "$version" in
  *.*.*) ;;
  *) echo "Invalid marketing version in VERSION: $version" >&2; exit 1 ;;
esac

major=${version%%.*}
rest=${version#*.}
minor=${rest%%.*}
patch=${rest#*.}
case "$major:$minor:$patch" in
  *[!0-9:]*|'') echo "Invalid semantic version in VERSION: $version" >&2; exit 1 ;;
esac
patch=$((patch + 1))
next_version="$major.$minor.$patch"
temporary_file="${version_file}.tmp.$$"
printf '%s\n' "$next_version" > "$temporary_file"
mv "$temporary_file" "$version_file"
echo "Bumped marketing version: $version -> $next_version"
