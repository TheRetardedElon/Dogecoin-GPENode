#!/usr/bin/env bash
# Format + mount Vultr NVMe Block Storage (raw disk) for GPE dogecoin hot state.
# This is NOT Vultr File System (virtiofs). Block storage appears as /dev/vdX.
#
# Default: /dev/vdb -> ext4 LABEL=GPEDogeCloud -> /mnt/gpedogecloud
# Safe: refuses to format if a filesystem UUID already exists (unless FORCE_FORMAT=1).
set -euo pipefail

DEV="${DEV:-/dev/vdb}"
MNT="${MNT:-/mnt/gpedogecloud}"
LABEL="${LABEL:-GPEDogeCloud}"
FORCE_FORMAT="${FORCE_FORMAT:-0}"
DOGE_USER="${DOGE_USER:-dogecoin}"

if [[ ! -b "${DEV}" ]]; then
  echo "ERROR: ${DEV} is not a block device"
  lsblk
  exit 1
fi

echo "==> device ${DEV}"
lsblk -f "${DEV}"
EXISTING_UUID="$(blkid -s UUID -o value "${DEV}" 2>/dev/null || true)"
EXISTING_TYPE="$(blkid -s TYPE -o value "${DEV}" 2>/dev/null || true)"

if [[ -n "${EXISTING_TYPE}" && "${FORCE_FORMAT}" != "1" ]]; then
  echo "Filesystem already present on ${DEV}: TYPE=${EXISTING_TYPE} UUID=${EXISTING_UUID}"
  echo "Skipping mkfs (set FORCE_FORMAT=1 to wipe and reformat — DESTROYS DATA)."
else
  if [[ -n "${EXISTING_TYPE}" && "${FORCE_FORMAT}" == "1" ]]; then
    echo "WARNING: FORCE_FORMAT=1 — wiping ${DEV}"
    wipefs -a "${DEV}"
  fi
  echo "==> mkfs.ext4 -L ${LABEL} ${DEV}"
  mkfs.ext4 -F -L "${LABEL}" "${DEV}"
fi

UUID="$(blkid -s UUID -o value "${DEV}")"
if [[ -z "${UUID}" ]]; then
  echo "ERROR: no UUID after format"
  exit 1
fi
echo "UUID=${UUID}"

mkdir -p "${MNT}"
if mountpoint -q "${MNT}"; then
  echo "Already mounted: $(findmnt -n -o SOURCE,TARGET,FSTYPE,OPTIONS "${MNT}")"
else
  echo "==> mount UUID=${UUID} -> ${MNT}"
  mount -U "${UUID}" "${MNT}"
fi

if ! grep -qE "[[:space:]]${MNT}[[:space:]]" /etc/fstab 2>/dev/null; then
  echo "UUID=${UUID} ${MNT} ext4 defaults,nofail,discard 0 2" >> /etc/fstab
  echo "fstab: $(grep "${MNT}" /etc/fstab)"
else
  echo "fstab already has ${MNT}"
fi

# Layout for hot datadir + optional public snapshot artifacts
mkdir -p "${MNT}/dogecoin" "${MNT}/snapshots" "${MNT}/backups"
if id "${DOGE_USER}" &>/dev/null; then
  chown -R "${DOGE_USER}:${DOGE_USER}" "${MNT}/dogecoin" "${MNT}/snapshots" "${MNT}/backups"
fi
chmod 755 "${MNT}"
chmod 700 "${MNT}/dogecoin" 2>/dev/null || true

echo "==> MOUNTED_OK"
df -h "${MNT}"
ls -la "${MNT}"
echo "Next (optional): migrate live mainnet with migrate_mainnet_to_block.sh"
echo "  DATADIR would become: ${MNT}/dogecoin"
