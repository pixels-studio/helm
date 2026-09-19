#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
configuration="${1:-debug}"

case "$configuration" in
  debug|release) ;;
  *)
    echo "Usage: $0 [debug|release]" >&2
    exit 2
    ;;
esac

cd "$repo_dir/native"
./Scripts/package-app.sh "$configuration"
open .build/Helm.app
