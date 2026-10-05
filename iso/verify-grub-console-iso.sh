#!/usr/bin/env bash
set -euo pipefail
ISO="${1:?Pass ISO path}"
TMP="$(mktemp -d "${HOME}/.cache/atlasos/verify-grub.XXXXXXXX")"
trap 'chmod -R u+rwX -- "${TMP}" 2>/dev/null || true; rm -rf -- "${TMP}"' EXIT

(cd "$(dirname "${ISO}")" && sha256sum -c "$(basename "${ISO}").sha256")
xorriso -indev "${ISO}" -report_el_torito plain -report_system_area plain \
  > "${TMP}/boot-records.txt" 2>&1
grep -q 'El Torito boot img :   1  BIOS' "${TMP}/boot-records.txt"
grep -q 'El Torito boot img :   2  UEFI' "${TMP}/boot-records.txt"

for item in EFI/BOOT/BOOTX64.EFI boot/grub/efi.img casper/vmlinuz casper/initrd.img casper/filesystem.squashfs; do
  xorriso -osirrox on -indev "${ISO}" -extract "/${item}" "${TMP}/$(basename "${item}")" \
    > /dev/null 2>> "${TMP}/extract.log"
done
mcopy -i "${TMP}/efi.img" ::/EFI/BOOT/BOOTX64.EFI "${TMP}/efi-copy.EFI"
cmp "${TMP}/BOOTX64.EFI" "${TMP}/efi-copy.EFI"
echo 'UEFI copies match'

printf '%s  %s\n' \
  '9f55ef7253055a9cf68f8a04323c93dead2fca617386d842fbde9ca7b178b27e' "${TMP}/vmlinuz" \
  'c41f3f0f757599c11fa8442aad7e71d0ed314abdeda84d4f430b0f3d15ebbec5' "${TMP}/initrd.img" \
  'f0307d96e8f5f8760534bc62472f309e3882d92b24704a49069659f59d7dd586' "${TMP}/filesystem.squashfs" \
  | sha256sum -c -

strings "${TMP}/BOOTX64.EFI" | grep -F 'ATLAS OS 0.6.3  |  Live oturumu baslat' >/dev/null
strings "${TMP}/BOOTX64.EFI" | grep -F 'terminal_output console' >/dev/null
strings "${TMP}/BOOTX64.EFI" | grep -F 'set gfxpayload=keep' >/dev/null
echo 'Atlas console menu embedded'
echo 'BIOS and UEFI boot entries present'
