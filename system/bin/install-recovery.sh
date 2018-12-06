#!/system/bin/sh
if ! applypatch -c EMMC:/dev/block/bootdevice/by-name/recovery:11097388:c009d63dfd89956cbd8523f46584f7d2d7221e09; then
  applypatch EMMC:/dev/block/bootdevice/by-name/boot:10417448:3d4feef191bb7c99c9c7ef8937d1e344167ed626 EMMC:/dev/block/bootdevice/by-name/recovery c009d63dfd89956cbd8523f46584f7d2d7221e09 11097388 3d4feef191bb7c99c9c7ef8937d1e344167ed626:/system/recovery-from-boot.p && log -t recovery "Installing new recovery image: succeeded" || log -t recovery "Installing new recovery image: failed"
else
  log -t recovery "Recovery image already installed"
fi
