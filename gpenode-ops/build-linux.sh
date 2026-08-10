#!/usr/bin/env bash
# Build static-ish Linux gpenode-ops (run under WSL or Linux).
set -euo pipefail
cd "$(dirname "$0")"

export PATH="/usr/local/go/bin:${PATH:-}"

# Prefer existing go, else user-local install (no sudo)
if ! command -v go >/dev/null 2>&1; then
  GOROOT_USER="${HOME}/.local/go"
  if [[ ! -x "${GOROOT_USER}/bin/go" ]]; then
    echo "==> installing Go 1.22.12 to ${GOROOT_USER} (no sudo)"
    mkdir -p "${HOME}/.local"
    curl -fsSL -o /tmp/go.tgz https://go.dev/dl/go1.22.12.linux-amd64.tar.gz
    rm -rf "${GOROOT_USER}"
    tar -C "${HOME}/.local" -xzf /tmp/go.tgz
    # tarball extracts as "go/"
    mv "${HOME}/.local/go" "${GOROOT_USER}" 2>/dev/null || true
    # if already named go under .local, leave it
    if [[ -x "${HOME}/.local/go/bin/go" && ! -x "${GOROOT_USER}/bin/go" ]]; then
      GOROOT_USER="${HOME}/.local/go"
    fi
  fi
  export PATH="${GOROOT_USER}/bin:${PATH}"
  export GOROOT="${GOROOT_USER}"
fi

go version
echo "==> build gpenode-ops (linux amd64, cgo off)"
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w" -o gpenode-ops .
ls -la gpenode-ops
./gpenode-ops version
./gpenode-ops help || true
echo "==> BUILD_OK"
