#!/usr/bin/env bash
# Mount Vultr File System and migrate dogecoin datadir onto it.
set -euo pipefail

TAG="${1:-103415128}"
ALT_TAG="${2:-97133493}"
MNT="/mnt/gpenodestore"
DOGE_USER="dogecoin"
OLD_DATADIR="/var/lib/dogecoin"
NEW_DATADIR="${MNT}/dogecoin"

echo "==> mount tag=${TAG} (fallback ${ALT_TAG}) -> ${MNT}"
mkdir -p "${MNT}"

if ! mountpoint -q "${MNT}"; then
  if ! mount -t virtiofs "${TAG}" "${MNT}" 2>/tmp/mount_err.txt; then
    echo "primary tag failed: $(cat /tmp/mount_err.txt)"
    mount -t virtiofs "${ALT_TAG}" "${MNT}"
  fi
fi

if ! mountpoint -q "${MNT}"; then
  echo "ERROR: ${MNT} not a mountpoint"
  exit 1
fi

echo "MOUNTED_OK"
df -h "${MNT}"
ls -la "${MNT}"

# fstab for reboot
if ! grep -q "${MNT}" /etc/fstab 2>/dev/null; then
  # detect which tag actually mounted
  USED_TAG="${TAG}"
  if ! grep -qs "virtiofs.*${MNT}" /proc/mounts; then
    USED_TAG="${TAG}"
  fi
  # parse actual source from findmnt if available
  if command -v findmnt >/dev/null; then
    SRC=$(findmnt -n -o SOURCE "${MNT}" || true)
    if [[ -n "${SRC}" ]]; then
      USED_TAG="${SRC}"
    fi
  fi
  echo "${USED_TAG} ${MNT} virtiofs defaults,_netdev 0 0" >> /etc/fstab
  echo "fstab: $(tail -1 /etc/fstab)"
fi

echo "==> prepare datadir ${NEW_DATADIR}"
mkdir -p "${NEW_DATADIR}"

# stop dogecoind if running
systemctl stop dogecoind 2>/dev/null || true

# migrate conf / empty tree from local if present
if [[ -d "${OLD_DATADIR}" ]]; then
  if [[ -f "${OLD_DATADIR}/dogecoin.conf" && ! -f "${NEW_DATADIR}/dogecoin.conf" ]]; then
    cp -a "${OLD_DATADIR}/dogecoin.conf" "${NEW_DATADIR}/dogecoin.conf"
    echo "copied dogecoin.conf"
  fi
  # move any chain data if IBD was started locally
  for d in blocks chainstate indexes wallets; do
    if [[ -e "${OLD_DATADIR}/${d}" && ! -e "${NEW_DATADIR}/${d}" ]]; then
      mv "${OLD_DATADIR}/${d}" "${NEW_DATADIR}/"
      echo "moved ${d}"
    fi
  done
fi

if [[ ! -f "${NEW_DATADIR}/dogecoin.conf" ]]; then
  echo "ERROR: no dogecoin.conf in ${NEW_DATADIR}"
  exit 1
fi

# ensure prune settings for 2GB host
if ! grep -q '^prune=' "${NEW_DATADIR}/dogecoin.conf"; then
  echo "prune=550" >> "${NEW_DATADIR}/dogecoin.conf"
fi

chown -R "${DOGE_USER}:${DOGE_USER}" "${MNT}"
chmod 700 "${NEW_DATADIR}"
chmod 600 "${NEW_DATADIR}/dogecoin.conf"

echo "${NEW_DATADIR}" > /etc/dogecoin/datadir.path
ln -sfn "${NEW_DATADIR}" /etc/dogecoin/datadir

# rewrite systemd unit with cloud datadir
cat >/etc/systemd/system/dogecoind.service <<EOF
[Unit]
Description=Dogecoin Core settlement node (GPE)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${DOGE_USER}
Group=${DOGE_USER}
ExecStart=/usr/local/bin/dogecoind -datadir=${NEW_DATADIR} -pid=/run/dogecoin/dogecoind.pid
ExecStop=/usr/local/bin/dogecoin-cli -datadir=${NEW_DATADIR} stop
RuntimeDirectory=dogecoin
RuntimeDirectoryMode=0755
Restart=on-failure
RestartSec=10
LimitNOFILE=8192
MemoryMax=1500M

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable dogecoind

echo "==> datadir on cloud FS ready"
echo "DATADIR=${NEW_DATADIR}"
df -h "${MNT}"
ls -la "${NEW_DATADIR}"
echo "Start later with: systemctl start dogecoind"
