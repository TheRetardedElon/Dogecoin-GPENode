#!/usr/bin/env bash
# Build Core Pro Headless Windows binaries in an ISOLATED tree.
# Does not modify C:\dogedev source or its in-tree objects.
#
# Uses:
#   SRC:     /mnt/c/dogedev (read-only rsync source)
#   BUILD:   $HOME/dogedev-winbuild-headless  (isolated)
#   DEPENDS: reuses $HOME/dogedev-winbuild/depends/x86_64-w64-mingw32 if present
#
# Output:
#   $HOME/dogedev-winbuild-headless/src/dogecoind.exe
#   $HOME/dogedev-winbuild-headless/src/dogecoin-cli.exe
#   Copied to /mnt/c/dogedevGPEnode/deploy/windows/bin/
#   Packaged under /mnt/c/dogedevGPEnode/out/windows-headless/
set -euo pipefail

export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

SRC_WIN="${SRC_WIN:-/mnt/c/dogedev}"
BUILD_ROOT="${BUILD_ROOT:-$HOME/dogedev-winbuild-headless}"
DEPS_DONOR="${DEPS_DONOR:-$HOME/dogedev-winbuild}"
HOST="x86_64-w64-mingw32"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 2)}"
OUT_WIN="${OUT_WIN:-/mnt/c/dogedevGPEnode/deploy/windows/bin}"
PKG_WIN="${PKG_WIN:-/mnt/c/dogedevGPEnode/out/windows-headless}"
VER="${VER:-1.14.102-gpenode-headless}"
STAGE="${1:-all}"  # all | sync | configure | build | package

log() { echo "[win-headless $(date +%H:%M:%S)] $*"; }

need_posix_mingw() {
  local gxx
  gxx="$(readlink -f "$(command -v x86_64-w64-mingw32-g++)")"
  if [[ "$gxx" != *posix* ]]; then
    log "ERROR: need posix mingw ($gxx)"
    exit 1
  fi
  log "mingw: $gxx"
}

# Avoid WSL trying to run PE configure tests
disable_binfmt() {
  if [[ -w /proc/sys/fs/binfmt_misc/status ]]; then
    echo 0 > /proc/sys/fs/binfmt_misc/status || true
  elif command -v sudo >/dev/null 2>&1; then
    sudo -n bash -c 'echo 0 > /proc/sys/fs/binfmt_misc/status' 2>/dev/null || true
  fi
}

sync_tree() {
  log "Sync source $SRC_WIN -> $BUILD_ROOT (isolated; excludes .git/release/html objects)"
  mkdir -p "$BUILD_ROOT"
  rsync -a \
    --delete \
    --exclude='.git' \
    --exclude='html' \
    --exclude='release' \
    --exclude='smoke-run' \
    --exclude='node_modules' \
    --exclude='*.o' \
    --exclude='*.lo' \
    --exclude='*.a' \
    --exclude='*.exe' \
    --exclude='.deps' \
    --exclude='depends/built' \
    --exclude='depends/work' \
    --exclude='depends/sources' \
    --exclude='depends/x86_64-w64-mingw32' \
    --exclude='depends/x86_64-unknown-linux-gnu' \
    --exclude='autom4te.cache' \
    "$SRC_WIN/" "$BUILD_ROOT/"

  # Reuse prebuilt MinGW depends from donor tree (do not rebuild Qt if present)
  if [[ -f "$DEPS_DONOR/depends/$HOST/share/config.site" ]]; then
    log "Linking depends prefix from $DEPS_DONOR (shared read-only build artifacts)"
    mkdir -p "$BUILD_ROOT/depends"
    rm -rf "$BUILD_ROOT/depends/$HOST"
    # hard copy is safer than symlink across partial updates
    rsync -a "$DEPS_DONOR/depends/$HOST/" "$BUILD_ROOT/depends/$HOST/"
    # optional: share sources cache
    if [[ -d "$DEPS_DONOR/depends/sources" ]]; then
      mkdir -p "$BUILD_ROOT/depends/sources"
      rsync -a "$DEPS_DONOR/depends/sources/" "$BUILD_ROOT/depends/sources/" || true
    fi
  else
    log "ERROR: no depends at $DEPS_DONOR/depends/$HOST — run scripts/run-win-depends.sh first"
    exit 1
  fi
  log "Sync done"
}

configure_headless() {
  need_posix_mingw
  disable_binfmt
  cd "$BUILD_ROOT"
  if [[ ! -x configure ]]; then
    log "autogen.sh"
    ./autogen.sh
  fi
  # Clean prior configure of this isolated tree only
  if [[ -f Makefile ]]; then
    log "distclean isolated tree (does not touch $SRC_WIN)"
    make distclean >/dev/null 2>&1 || true
  fi
  log "configure --without-gui (headless; wallet ON for settlement profile)"
  CONFIG_SITE="$PWD/depends/$HOST/share/config.site" ./configure \
    --prefix=/ \
    --host="$HOST" \
    --disable-ccache \
    --disable-maintainer-mode \
    --disable-dependency-tracking \
    --disable-tests \
    --disable-bench \
    --without-gui \
    --with-incompatible-bdb \
    --enable-reduce-exports \
    ${CONFIGURE_EXTRA:-}
  log "configure OK"
}

build_headless() {
  need_posix_mingw
  disable_binfmt
  cd "$BUILD_ROOT"
  log "make dogecoind dogecoin-cli -j${JOBS}"
  make -j"${JOBS}" -C src dogecoind.exe dogecoin-cli.exe 2>&1 || make -j"${JOBS}" -C src dogecoind dogecoin-cli
  # Normalize names
  if [[ -f src/dogecoind ]] && [[ ! -f src/dogecoind.exe ]]; then
    # sometimes named without .exe in make target but PE is dogecoind.exe
    true
  fi
  ls -la src/dogecoind.exe src/dogecoin-cli.exe
  file src/dogecoind.exe
  # PE import check: should not require Qt5
  if x86_64-w64-mingw32-objdump -p src/dogecoind.exe | grep -qiE 'Qt5|qt5core'; then
    log "ERROR: dogecoind.exe still links Qt — not headless"
    exit 1
  fi
  log "No Qt DLLs in dogecoind.exe imports (good)"
  strings src/dogecoind.exe | grep -E 'dumptxoutset|fetchassumeutxo' | head -10 || true
}

package_headless() {
  local name="dogecoin-gpenode-win64-${VER}"
  local stage="${PKG_WIN}/${name}"
  rm -rf "$stage"
  mkdir -p "$stage/bin" "$stage/conf" "$OUT_WIN"

  cp -a "$BUILD_ROOT/src/dogecoind.exe" "$stage/bin/"
  cp -a "$BUILD_ROOT/src/dogecoin-cli.exe" "$stage/bin/"
  cp -a "$BUILD_ROOT/src/dogecoind.exe" "$OUT_WIN/"
  cp -a "$BUILD_ROOT/src/dogecoin-cli.exe" "$OUT_WIN/"

  # Windows service scripts from kit
  local WINKIT="/mnt/c/dogedevGPEnode/deploy/windows"
  # SCM wrapper required for Windows Service
  local OPS_WIN=""
  for c in \
    "$WINKIT/bin/gpenode-ops.exe" \
    "/mnt/c/dogedevGPEnode/gpenode-ops/gpenode-ops.exe" \
    "/mnt/c/dogedevGPEnode/out/gpenode-ops/gpenode-ops-windows-amd64.exe"
  do
    if [[ -f "$c" ]]; then OPS_WIN="$c"; break; fi
  done
  [[ -n "$OPS_WIN" ]] || { log "ERROR: missing gpenode-ops.exe service wrapper"; exit 1; }
  cp -a "$OPS_WIN" "$stage/bin/gpenode-ops.exe"
  cp -a "$OPS_WIN" "$OUT_WIN/gpenode-ops.exe"

  cp -a "$WINKIT/install-service.ps1" "$stage/"
  cp -a "$WINKIT/uninstall-service.ps1" "$stage/"
  cp -a "$WINKIT/status-service.ps1" "$stage/"
  cp -a "$WINKIT/conf/"*.example "$stage/conf/" 2>/dev/null || true
  cp -a "$WINKIT/README.md" "$stage/" 2>/dev/null || true

  cat > "$stage/README.txt" <<EOF
Dogecoin GPENode / Core Pro Headless - Windows x64
Version: ${VER}

Contents
  bin/dogecoind.exe      Headless node (no Qt)
  bin/dogecoin-cli.exe
  bin/gpenode-ops.exe    Ops glue + Windows SCM service host
  conf/*.example         Dump / settlement profiles
  install-service.ps1    Windows Service install (Admin)
  uninstall-service.ps1
  status-service.ps1

Install (elevated PowerShell)
  cd this folder
  powershell -ExecutionPolicy Bypass -File .\\install-service.ps1 -Profile dump -BinDir .\\bin

Service model: gpenode-ops service-run supervises dogecoind (dogecoind is not a native SCM service).
Same Dogecoin mainnet consensus as Core Pro GUI. No GUI product surface.
EOF

  ( cd "$PKG_WIN" && zip -r -9 "${name}.zip" "${name}" )
  ( cd "$PKG_WIN" && sha256sum "${name}.zip" > "${name}.zip.sha256" )
  log "PACKAGE_OK $PKG_WIN/${name}.zip"
  ls -lh "$PKG_WIN/${name}.zip" "$PKG_WIN/${name}.zip.sha256"
  cat "$PKG_WIN/${name}.zip.sha256"
}

case "$STAGE" in
  all)
    need_posix_mingw
    sync_tree
    configure_headless
    build_headless
    package_headless
    ;;
  sync) sync_tree ;;
  configure) configure_headless ;;
  build) build_headless ;;
  package) package_headless ;;
  *)
    echo "Usage: $0 [all|sync|configure|build|package]"
    exit 2
    ;;
esac

log "DONE (isolated tree: $BUILD_ROOT — C:\\dogedev untouched)"
