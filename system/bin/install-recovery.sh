#!/system/bin/sh
if ! applypatch -c EMMC:/dev/block/bootdevice/by-name/recovery:11097388:57019b7f0d23c0f2ac320aa93e96d54fa315b031; then
  applypatch EMMC:/dev/block/bootdevice/by-name/boot:10417448:678f441ca3235abf7d6df445b28550928a9ed1e0 EMMC:/dev/block/bootdevice/by-name/recovery 57019b7f0d23c0f2ac320aa93e96d54fa315b031 11097388 678f441ca3235abf7d6df445b28550928a9ed1e0:/system/recovery-from-boot.p && log -t recovery "Installing new recovery image: succeeded" || log -t recovery "Installing new recovery image: failed"
else
  log -t recovery "Recovery image already installed"
fi
