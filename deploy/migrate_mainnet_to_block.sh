#!/usr/bin/env bash
# Stop dogecoind, rsync live mainnet datadir onto NVMe block volume, retarget systemd.
# Keeps the old tree as ${OLD_DATADIR}.pre-block-migrate until you delete it.
set -euo pipefail

OLD_DATADIR="${OLD_DATADIR:-/var/lib/dogecoin-mainnet}"
MNT="${MNT:-/mnt/gpedogecloud}"
NEW_DATADIR="${NEW_DATADIR:-${MNT}/dogecoin}"
DOGE_USER="${DOGE_USER:-dogecoin}"
SERVICE="${SERVICE:-dogecoind}"

if ! mountpoint -q "${MNT}"; then
  echo "ERROR: ${MNT} is not a mountpoint — run mount_nvme_block_storage.sh first"
  exit 1
fi
if [[ ! -d "${OLD_DATADIR}" ]]; then
  echo "ERROR: missing ${OLD_DATADIR}"
  exit 1
fi
if [[ ! -f "${OLD_DATADIR}/dogecoin.conf" ]]; then
  echo "ERROR: no dogecoin.conf in ${OLD_DATADIR}"
  exit 1
fi

echo "==> stop ${SERVICE}"
systemctl stop "${SERVICE}" || true
# wait for clean exit
for i in $(seq 1 60); do
  if ! pgrep -x dogecoind >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
if pgrep -x dogecoind >/dev/null 2>&1; then
  echo "ERROR: dogecoind still running"
  exit 1
fi

echo "==> rsync ${OLD_DATADIR}/ -> ${NEW_DATADIR}/"
mkdir -p "${NEW_DATADIR}"
rsync -aHAX --info=progress2 "${OLD_DATADIR}/" "${NEW_DATADIR}/"
chown -R "${DOGE_USER}:${DOGE_USER}" "${NEW_DATADIR}"
chmod 700 "${NEW_DATADIR}"
chmod 600 "${NEW_DATADIR}/dogecoin.conf"

mkdir -p /etc/dogecoin
echo "${NEW_DATADIR}" > /etc/dogecoin/datadir.path
ln -sfn "${NEW_DATADIR}" /etc/dogecoin/datadir

cat >/etc/systemd/system/dogecoind.service <<EOF
[Unit]
Description=Dogecoin Core mainnet settlement node (GPE)
After=network-online.target
Wants=network-online.target
# Datadir on NVMe block volume
RequiresMountsFor=${MNT}

[Service]
Type=simple
User=${DOGE_USER}
Group=${DOGE_USER}
ExecStart=/usr/local/bin/dogecoind -datadir=${NEW_DATADIR} -pid=/run/dogecoin/dogecoind.pid
ExecStop=/usr/local/bin/dogecoin-cli -datadir=${NEW_DATADIR} stop
RuntimeDirectory=dogecoin
RuntimeDirectoryMode=0755
Restart=on-failure
RestartSec=15
LimitNOFILE=16384
MemoryMax=1600M

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable "${SERVICE}"
echo "==> start ${SERVICE}"
systemctl start "${SERVICE}"
sleep 3
systemctl --no-pager -l status "${SERVICE}" || true

echo "==> verify"
sudo -u "${DOGE_USER}" dogecoin-cli -datadir="${NEW_DATADIR}" getblockchaininfo | \
  python3 -c "import sys,json; d=json.load(sys.stdin); print('chain',d.get('chain'),'blocks',d.get('blocks'),'ibd',d.get('initialblockdownload'),'progress',round(d.get('verificationprogress',0)*100,2))"

echo "==> migrate done"
echo "NEW_DATADIR=${NEW_DATADIR}"
df -h "${MNT}"
echo "Old tree still at ${OLD_DATADIR} — after you confirm health for a day:"
echo "  mv ${OLD_DATADIR} ${OLD_DATADIR}.pre-block-migrate"
