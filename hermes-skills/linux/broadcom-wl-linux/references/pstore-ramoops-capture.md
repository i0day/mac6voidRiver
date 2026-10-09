# pstore/ramoops crash capture that actually persists

For hard freezes where the machine dies before logs flush. Three gotchas each silently void the capture — verify all three.

## Gotcha 1: boot parameters reject K/M suffixes
`ramoops.mem_size=2M` fails with `ramoops: '2M' invalid for parameter 'mem_size'`. Boot params must be **plain byte counts**: `ramoops.mem_address=0x8cb00000 ramoops.mem_size=2097152 ramoops.record_size=524288 console_size=262144 pmsg_size=65536`. (Runtime `modprobe` with module params accepts the same plain values.)

## Gotcha 2: runtime modprobe does not reserve memory
Loading ramoops at runtime reports `using 0x200000@0x0` with nothing in `/proc/iomem` — the region isn't reserved and capture is unreliable. Put the params on the **kernel command line** (GRUB) or in `/etc/modprobe.d/ramoops.conf` + `/etc/modules-load.d/ramoops.conf` so it registers early. Pick `mem_address` from the top of a usable e820 region minus the size: read `sudo dmesg | grep BIOS-e820 | grep usable`, take the top of the largest low region, round down 2M (e.g. usable top 0x8cd13fff → 0x8cb00000).

## Gotcha 3: CONFIG_PSTORE_CONSOLE / CONFIG_PSTORE_PMSG must be enabled
`CONFIG_PSTORE_RAM=m` alone registers the backend but **console and pmsg recording are separate options**. If `CONFIG_PSTORE_CONSOLE is not set` and `CONFIG_PSTORE_PMSG is not set` (Void kernels: they are NOT set, in every series), then:
- writes to `/dev/pmsg0` succeed but produce no pstore record
- crashes produce no `console-ramoops-*` file
- the whole capture is void regardless of correct addressing
Check `grep PSTORE /boot/config-$(uname -r)` BEFORE relying on pstore. If the distro kernel lacks them, the only options are rebuilding the kernel with `PSTORE_CONSOLE=y PSTORE_PMSG=y` or using an external capture channel (serial/netconsole).

## Supporting panic settings (runtime-settable)
`sudo sysctl kernel.softlockup_panic=1 kernel.hardlockup_panic=1 kernel.panic=15` — converts soft lockups to panics and auto-reboots after 15s so the ramoops region survives. Also `sudo dmesg -n 8` so console messages aren't suppressed. Note: a true hard bus hang (machine check / SError) bypasses panic entirely — no pstore record even with everything configured.

## Reading after reboot
`sudo mount -t pstore pstore /sys/fs/pstore && sudo ls -la /sys/fs/pstore` — expect `console-ramoops-0` (last console ring), `dmesg-ramoops-0` (panic dump), `pmsg-ramoops-0`. Empty dir after a crash = one of the three gotchas above, not 'nothing crashed'.
