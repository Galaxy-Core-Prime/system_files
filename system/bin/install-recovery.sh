#!/system/bin/sh
if ! applypatch -c EMMC:/dev/block/bootdevice/by-name/recovery:10955008:72e1279f0c3f19616a631eb8186c0aa795a94dbf; then
  applypatch EMMC:/dev/block/bootdevice/by-name/boot:10273024:6f65e87bc1f5c2efb29c4ff6194e4d557e5c8409 EMMC:/dev/block/bootdevice/by-name/recovery 72e1279f0c3f19616a631eb8186c0aa795a94dbf 10955008 6f65e87bc1f5c2efb29c4ff6194e4d557e5c8409:/system/recovery-from-boot.p && log -t recovery "Installing new recovery image: succeeded" || log -t recovery "Installing new recovery image: failed"
else
  log -t recovery "Recovery image already installed"
fi
