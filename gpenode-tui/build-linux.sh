#!/usr/bin/env bash
# Build Linux amd64 gpenode-tui (WSL or Linux).
set -euo pipefail
cd "$(dirname "$0")"
export PATH="/usr/local/go/bin:${HOME}/.local/go/bin:${PATH:-}"

if ! command -v go >/dev/null 2>&1; then
  echo "missing go — install Go 1.22+ or use existing gpenode-ops bootstrap"
  exit 1
fi

go version
export CGO_ENABLED=0
export GOOS=linux
export GOARCH=amd64
go mod tidy
go build -ldflags="-s -w" -o gpenode-tui .
ls -la gpenode-tui
echo "==> BUILD_OK gpenode-tui (linux amd64)"
