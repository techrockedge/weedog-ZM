#!/bin/sh
# Build_weedog_initramfs05_s203 to create WeeDog Linux initramfs Model05
# (s203 means [s]witch_root revision 2.0.3) 
# Copyright wiak (William McEwan) 30 May 2019+; Licence MIT (aka X11 license)
# Revision Date: 23 Sep 2019
# This script tested with Void Linux vmlinuz via commandline arg kernel=void (and also with kernel=debian ...)
# It should alternatively work as a hybrid system with, e.g., BionicPup vmlinuz and processed zdrv.

#### variables-used-in-script:
# script commandline arguments $1 $2 $3 $4
# "$1" is distro (e.g. void); "$2" is optional mksquashfs compression (or "default");
# "$3" is optional "huge" initramfs (or "default); $4 is optional busybox url to use

kernel="$1"
case "$1" in
	'-v'|'--version') echo "Build WeeDog initramfs05 [s]witch_root Revision 2.0.3";exit;;
	'-h'|'--help'|'-?') printf '
Usage:
./build_weedog_initramfs05_sNNN.sh [OPTIONS]

-v --version    	display version information and exit
-h --help -?    	display this help and exit
distro_name		(i.e. void, ubuntu, debian, or devuan)
			auto-insert Linux distro modules/firmware into
			initramfs and output associated Linux kernel;
			all of which must be pre-installed into
			firstrib_rootfs build.

Optional second argument is mksquashfs compression (or "default")
Optional third argument is "huge" (or "default") initramfs
"huge" includes 01firstrib_rootfs.sfs inside initramfs/boot/initramfsNN
Optional fourth argument is busybox_url (in case, e.g. arm64 required)
fourth argument can optionally also be "default"

EXAMPLES: 
./build_weedog_initramfs05_sNNN.sh void  # or debian, ubuntu, devuan etc
./build_weedog_initramfs05_sNNN.sh void "-comp lz4 -Xhc"
./build_weedog_initramfs05_sNNN.sh void default huge

Once booted, set up shadow passwords with pwconv and grpconv and
REMEMBER to set: passwd root

For more details read the attached README and/or
visit: https://github.com/firstrib/firstrib
';exit;;
esac

# If using $1 option distro_name (e.g. void), ensure kernel exists in firstrib_rootfs
if [ ! "$kernel" == "" ]; then
	kernel1="`ls firstrib_rootfs/boot/vmlinuz*`"
	kcount=`echo "$kernel1" | wc -w`
	if [ $kcount -gt 1 ];then
		printf '
firstrib_rootfs contains more than one kernel and more than
one xxx/modules/kernel_version. Please remove all except the
one you want to use and try again
'
		exit
	fi
	[ ! -f "$kernel1" ] && printf "\nfirstrib_rootfs needs to at least include xbps-install:\nlinuxX.XX, ncurses-base, and linux-firmware-network,\nand optional small extra wifi-firmware.\nOr simply install ncurses-base, and template: linux\n(which also brings nvidia, amd, i915 and more graphics drivers)\n" && exit
fi

case "$2" in
	'default'|'') comp="";;  # use default compression for mksquashfs of firstrib_rootfs
	*) comp="$2";;
esac
case "$3" in
	'default'|'') huge="false";;
	'huge') huge="true";;  # 01firstrib_rootfs.sfs gets copied to initramfs/boot/initramfsNN
esac
case "$4" in
	'default'|'') busybox_url="https://busybox.net/downloads/binaries/1.30.0-i686/busybox";;
	*) busybox_url="$4";;
esac
# ----------------------------------------------------- end-of-variables-used-in-build-script

#### functions-used-in-build-script:
_modprobe_modules (){
	# appending modprobe code for initramfsXX/init
	cat >> firstrib_rootfs_for_initramfs_sNNN/init << "CODE_FOR_INITRAMFS_INITb"
# Modules need loaded by initramfs when using kernel from Void Linux
for m in mbcache aufs exportfs ext4 fat vfat fuse isofs nls_cp437 nls_iso8859-1 nls_utf8 reiserfs squashfs xfs libata ahci libahci sata_sil24 pdc_adma sata_qstor sata_sx4 ata_piix sata_mv sata_nv sata_promise sata_sil sata_sis sata_svw sata_uli sata_via sata_vsc pata_ali pata_amd pata_artop pata_atiixp pata_atp867x pata_cmd64x pata_cs5520 pata_cs5530 pata_cs5535 pata_cs5536 pata_efar pata_hpt366 pata_hpt37x pata_it8213 pata_it821x pata_jmicron pata_marvell pata_netcell pata_ns87415 pata_oldpiix pata_pdc2027x pata_pdc202xx_old pata_rdc pata_sc1200 pata_sch pata_serverworks pata_sil680 pata_sis pata_triflex pata_via pata_isapnp pata_mpiix pata_ns87410 pata_opti pata_rz1000 ata_generic loop cdrom hid hid_generic usbhid mptscsih mptspi mptsas tifm_core cb710 mmc_block mmc_core sdhci sdhci-pci wbsd tifm_sd cb710-mmc via-sdmmc vub300 sdhci-pltfm scsi_mod scsi_transport_spi scsi_transport_sas sd_mod sr_mod usb-common usbcore ehci-hcd ehci-pci ohci-hcd uhci-hcd xhci-pci xhci-hcd usb-storage xts uas;do
	modprobe $m 2>/dev/null
done
CODE_FOR_INITRAMFS_INITb
}

# Stage1: Create root filesystem for inside the initramfs:

mkdir -p firstrib_rootfs_for_initramfs_sNNN
cd firstrib_rootfs_for_initramfs_sNNN
mkdir -p boot/kernel dev/pts etc/skel etc/udhcpc etc/xbps.d home/void media mnt opt proc root run sys tmp usr/bin usr/lib usr/include usr/lib32 usr/libexec usr/local/bin usr/local/include usr/local/lib usr/local/sbin usr/local/share usr/share/udhcpc usr/share/xbps.d usr/src var/log var/lock

# The following is per Void Linux structure. e.g. puts most all binaries in /bin and most all libs in /usr/lib:
ln -s usr/bin bin; ln -s usr/lib lib; ln -s usr/sbin sbin
ln -s bin usr/sbin; ln -s usr/lib lib64

# Using i686 32-bit busybox, even in x86_64 build
wget -c -nc "$busybox_url" -P usr/bin && chmod +x usr/bin/busybox

# Make the command applet hardlinks for busybox
cd usr/bin; for i in `./busybox --list`; do ln busybox $i; done; cd ../..

# cd to where we started this build (i.e. immediately outside of firstrib_rootfs):
cd ..

# Stage2: Create the initramfsXX/init, and main root filesystem inittab and /etc/rc.d/rc.sysinit scripts:

# Create /init script for inside main firstrib_rootfs build (can modify to simple call /sbin/init)
# using a cat heredocument to redirect the code lines into init:
cat > firstrib_rootfs_for_initramfs_sNNN/init << "CODE_FOR_INITRAMFS_INITa"
#!/bin/sh
# initramfs/init(05): simple switch_root init with overlay filesystem set up.
# Copyright William McEwan (wiak) 26 July 2019+; Licence MIT (aka X11 license)
# Revision 2.0.3  Date: 23 Sep 2019

# prevent all messages on console, except emergency (panic) messages
dmesg -n 1

# mount kernel required virtual filesystems and populate /dev
mount -t proc -o nodev,noexec,nosuid proc /proc
mount -t sysfs -o nodev,noexec,nosuid sysfs /sys
mount -t devtmpfs -o mode=0755 none /dev

# Familiar yourself with the following key variables used prior to reading this script:

layers_base=/mnt/layers  # making this a variable in case useful to move somewhere else
mkdir -p ${layers_base}/RAM  # for (upper_)changes=RAM and copy2ram storage in tmpfs

# kernel=distro; vmlinuz and modules/firmware that will be used
# bootfrom  : vmlinuz/initramfs.gz location
# altNN : alternative/additional location for NNfiles for mounting to the NN overlay layers
mountfrom="${bootfrom}" # where layers are mounted from. e.g. bootfrom dir or layers_base/RAM
bootpartition=`echo "$bootfrom" | cut -d/ -f3` # extract partition name

# usbwait  # usbwait for slow devices
# changes  # none, RAM, readonly, path2dir

# inram_sz=NNN[%]  # (from: man mount - tmpfs option size=): Override default maximum size of the filesystem. The size is given in bytes, and rounded up to entire pages. The default is half of the memory. The size parameter also accepts a suffix % to limit this tmpfs instance to that percentage of your physical RAM: the default, when neither size nor nr_blocks is specified, is size=50%

[ ! "$inram_sz" == "" ] && inram_sz=",size=${inram_sz}" || inram_sz=",size=100%"  # size of tmpfs inram for layers_base/RAM
mount -o mode=1777,nosuid,nodev${inram_sz} -n -t tmpfs inram ${layers_base}/RAM  # for changes=RAM;copy2ram

grep -q copy2ram /proc/cmdline 2>/dev/null; copy2ram=$?  # copy2ram is boolean 0(true) or 1(false)

# functions: 

# process any grub linux/kernel line rdshN argument to active plugin or debug sh
_rdsh (){
	if `grep -q $1 /proc/cmdline`; then
		# if plugin exists and isn't empty then source it
		if [ -s "${mountfrom}"/${1}.plug ]; then
			. "${mountfrom}"/${1}.plug
		else
			# Start a busybox job control debug shell at initramfs/init rdshN code line
			echo "In initramfs/init at $1. Enter exit to continue boot:"
			setsid cttyhack sh
		fi
	fi
}

# mount any NNsfs files or NNdir(s) to layers_base/NN layer
# and add to overlay "lower" list
_addlayer (){
  for addlayer in *; do
	NN="${addlayer:0:2}" # gets first two characters and below checks they are numeric (-gt 00)
	if [ "$NN" -gt 0 ] 2>/dev/null; then
		if [ "${addlayer##*.}" == "sfs" ]; then
			# layer to mount is an sfs file
			lower="${NN} ${lower}"
			mkdir -p "${layers_base}/$NN"
			# umount any previous lower precedence mount
			mountpoint -q "${layers_base}/$NN" && umount "${layers_base}/$NN"
			mount "${addlayer}" "${layers_base}/$NN"
		elif [ -d "$addlayer" ]; then
			# layer to mount is an uncompressed directory
			lower="${NN} ${lower}"
			mkdir -p "${layers_base}/$NN"
			# umount any previous lower precedence mount
			mountpoint -q "${layers_base}/$NN" && umount "${layers_base}/$NN"
			mount --bind "${addlayer}" "${layers_base}/$NN"
		fi
	fi
  done
  sync
  echo -e "\e[95mCurrent directory is `pwd`\e[0m" >/dev/console
  echo -e "\e[95mlower_accumulated is ${lower:-empty list}\e[0m" >/dev/console
}

CODE_FOR_INITRAMFS_INITa

# Modules need to be loaded by initramfs/init if distro_name kernel being used
case "$kernel" in
	void)
		# Copy in Void Linux kernel modules and firmware from firstrib_rootfs,
		# and copy out Void kernel vmlinuz for later copying to /mnt/bootpartition/bootdir
		echo "Copying Void Linux modules to initramfs build. Please wait patiently..."
		cp -af firstrib_rootfs/usr/lib/modules firstrib_rootfs_for_initramfs_sNNN/usr/lib/
		cp -a firstrib_rootfs/boot/vmlinuz* .

		# initramfs/init needs to load sufficient modules to boot system
		_modprobe_modules
	  ;;
	ubuntu|debian|devuan)
		# Copy in deb-based Linux kernel modules and firmware from firstrib_rootfs,
		# and copy out deb-based kernel vmlinuz for later copying to /mnt/bootpartition/bootdir
		echo "Copying Void Linux modules to initramfs build. Please wait patiently..."
		cp -af firstrib_rootfs/lib/modules firstrib_rootfs_for_initramfs_sNNN/usr/lib/
		cp -a firstrib_rootfs/boot/vmlinuz* .

		# initramfs/init needs to load sufficient modules to boot system
		_modprobe_modules
	  ;;
esac

# appending further code for initramfsXX/init
cat >> firstrib_rootfs_for_initramfs_sNNN/init << "CODE_FOR_INITRAMFS_INITc"
echo -e "\e[33musbwait $usbwait for slow devices. Please wait patiently...\e[0m" >/dev/console
[ "$usbwait" ] && sleep $usbwait

# Mount partition being booted from
mkdir -p /mnt/${bootpartition} && mount /dev/${bootpartition} /mnt/${bootpartition}

# If grub kernel-line rdsh0 specified then source rdsh0.plug code else start busybox job control shell
_rdsh rdsh0

if [ -s "${mountfrom}"/"inram.plug" ];then  # inram plugin, for example to set up swap space or zram
	. "${mountfrom}"/"inram.plug"
fi  # inram.plug
# If grub kernel-line rdsh1 specified then source rdsh1.plug code else start busybox job control shell
_rdsh rdsh1 # rdsh1.plug will be sourced here, so either that or inram.plug could be used, for example,
			# to set up normal or zram swap space
			# rdsh1.plug will only be active if grub kernel line includes rdsh1 argument

cd "${bootfrom}" # where the NN files/dirs and rdshN.plug files are
if	[ $copy2ram -eq 0 ]; then
	echo -e "\e[33mCopying all NNsfs, NNdirs and rdsh plugins to RAM. Please wait patiently...\e[0m" >/dev/console
	mountfrom="${layers_base}/RAM"  # which is tmpfs in RAM
	# copy all NNsfs, NNdirectories and any rdsh plugin files to RAM ready for mounting to layers
	for addlayer in *; do
		NN="${addlayer:0:2}" # gets first two characters and below checks they are numeric (-ge 00)
		if [ "$NN" -ge 0 ] 2>/dev/null; then cp -a "$addlayer" "${mountfrom}"; fi
	done
	cp -a rdsh*.plug "${mountfrom}" 2>/dev/null
	cp -a modules_remove.plug "${mountfrom}" 2>/dev/null
	sync; sync; cd /  # so can umount bootpartion
fi

# Different filesystems use different inode numbers. xino provides translation to fix the issue
# but often doesn't work if changes filesystem different from rootfs (so then need unpreferred xino=off)
#xino=`egrep -o "xino=[^ ]+" /proc/cmdline | cut -d= -f2`  # can force xino value at grub kernel line
[ "$xino" == "" ] || xino=",xino=$xino"

# There are four alternative "changes=" modes: empty arg, changes=RAM, changes=readonly, changes="path2dir"
# 1. No changes argument on grub kernel line: Use upper_changes in /mnt/bootpartition/bootdir
# 2. RAM: All changes go to RAM only (layers_base/RAM/upper_changes). i.e. non-persistent
# 3. readonly: overlay filesystem is rendered read only so it cannot be written to at all
# 4. path2dir: store upper_changes in specified path/directory at upper_changes subdirectory
if [ -z $changes ]; then
	# xino seems to default to off but if desired can later try to force xino=on using grub kernel line
	mkdir -p "${bootfrom}"/upper_changes "${bootfrom}"/work  # for rw persistence
	upper_work="upperdir=""${bootfrom}""/upper_changes,workdir=""${bootfrom}""/work${xino}"
elif [ "$changes" == "RAM" ]; then
	[ $copy2ram -eq 0 ] && umount_bootdevice="allowed"  # since everything in RAM can umount bootdevice
	mkdir -p ${layers_base}/RAM/upper_changes ${layers_base}/RAM/work
	upper_work="upperdir=${layers_base}/RAM/upper_changes,workdir=${layers_base}/RAM/work${xino}"
elif [ "$changes" == "readonly" ]; then
	[ $copy2ram -eq 0 ] && umount_bootdevice="allowed"  # since everything in RAM can umount bootdevice
	upper_work=""
else
	# Mount partition to be used for upper_changes
	changes_partition=`echo "$changes" | cut -d/ -f3` # extract partition name
	mkdir -p /mnt/${changes_partition} && mount /dev/${changes_partition} /mnt/${changes_partition}
	mkdir -p "${changes}"/upper_changes "${changes}"/work
	[ "$xino" == "" ] && xino=",xino=off"  # But can later try to force xino=on, if desired, using grub
	upper_work="upperdir=""${changes}""/upper_changes,workdir=""${changes}""/work${xino}"
	[ $copy2ram -eq 0 ] && umount_bootdevice="allowed"  # as long as changes_partition different to bootpartition can umount bootdevice
fi

# Make sfs mount and layers directories and bind and mount them appropriately as follows:

mkdir -p ${layers_base}/merged  # For the combined overlay result

# make lower overlay a series of mounts of either sfs files or 
# uncompressed directories named in the form NNfilename.sfs or NNdirectoryname
# NN numeric value determines order of overlay loading. 01 is lowest layer.
# 00firstrib_firmware_modules.sfs is handled separately
lower=""  # Initialise overlay 'lower' list

# Mount any NNsfs files in initramfs to appropriate NN overlays
# If there are any they must be stored in initramfs dir /boot/initramfsNN
mkdir -p /boot/initramfsNN; cd /boot/initramfsNN
# mount any NNsfs files or NNdir(s) to layers_base/NN layer
_addlayer	# and add (lowest priority) to overlay "lower" layers list

# Mount any NNsfs files in mountfrom to appropriate NN overlays
cd "${mountfrom}"  # i.e. bootfrom dir or layers_base/RAM
_addlayer  # add/replace mounts (middle priority) and add to overlay "lower" layers list

# If altNN=path2dir specified on commandline
if [ ! -z $altNN ]; then
	# Mount partition containing altNN location
	altNN_partition=`echo "$altNN" | cut -d/ -f3` # extract partition name
	mkdir -p /mnt/${altNN_partition} && mount /dev/${altNN_partition} /mnt/${altNN_partition}
	cd "$altNN"
	_addlayer  # add/replace mounts (highest priority) and add to overlay "lower" layers list
fi

# If grub kernel-line rdsh2 specified then source rdsh2.plug code else start busybox job control shell
_rdsh rdsh2

# Sort resulting overlay 'lower' layers list
# add new NN item to overlay \$lower list, reverse sort the list, and mount NNfirstrib_rootfs	
lower="`for i in $lower; do echo $i; done | sort -ru`"  # sort the list and remove duplicates

# If using 00firstrib_firmware_modules.sfs do the following
# Otherwise, if using Void Linux kernel, you need to make sure needed /usr/lib/firmware and modules
# are in firstrib_rootfs build via xbps-install linuxX.XX, ncurses-base, linux-firmware-network etc
firmware_modules_sfs=""
if [ -s "${mountfrom}"/00firstrib_firmware_modules.sfs ];then
	firmware_modules_sfs="00firmware_modules:"
	mkdir -p ${layers_base}/00firmware_modules /usr/lib/modules
	mount "${mountfrom}"/00firstrib_firmware_modules.sfs ${layers_base}/00firmware_modules
	sleep 1  # may not be required
	mount --bind 00firmware_modules/usr/lib/modules /usr/lib/modules  # needed for overlayfs module
fi

# Load module to allow overlay filesystem functionality
modprobe overlay && umount /usr/lib/modules 2>/dev/null  # modules to be reloaded during overlay merge 
sync

# compress whitespace and remove leading/trailing and put required colons into ${lower} layers list
lower="`echo $lower | awk '{$1=$1;print}'`"; lower=${lower// /:} # ${var//spacePattern/colonReplacement}

echo -e "\e[95mbootfrom is ${bootfrom:-ERROR}\e[0m" >/dev/console
echo -e "\e[95mmountfrom is ${mountfrom:-ERROR}\e[0m" >/dev/console
echo -e "\e[95maltNN is ${altNN:-not defined on grub kernel line}\e[0m" >/dev/console
echo -e "\e[95mlower (sorted/unique) is ${lower:-ERROR}\e[0m" >/dev/console
echo -e "\e[95mupper_work is ${upper_work:-readonly}\e[0m" >/dev/console

# If grub kernel-line rdsh3 specified then source rdsh3.plug code else start busybox job control shell
_rdsh rdsh3

cd ${layers_base}	# Since this is where the overlay mountpoints are
# Combine the overlays with result in ${layers_base}/merged
mount -t overlay -o lowerdir=${firmware_modules_sfs}${lower},"${upper_work}" overlay_result merged

# If grub kernel-line rdsh4 specified then source rdsh4.plug code else start busybox job control shell
_rdsh rdsh4

# Prior to switch_root need to --move main mounts to new rootfs merged:
mkdir -p merged/mnt/${bootpartition} merged${layers_base}/RAM
mountpoint -q /mnt/${bootpartition} && mount --move /mnt/${bootpartition} merged/mnt/${bootpartition}
if [ ! -z "$changes_partition" ];then mkdir -p merged/mnt/${changes_partition} && mount --move /mnt/${changes_partition} merged/mnt/${changes_partition};fi

# Make tmpfs RAM available in overlay merged
mount --move ${layers_base}/RAM merged${layers_base}/RAM

if [ -f merged"${mountfrom}"/modules_remove.plug ]; then  # source modules_remove plugin
	. merged"${mountfrom}"/modules_remove.plug
else
	# Remove unused modules to save memory
	modprobe -r `lsmod | cut -d' ' -f1 | grep -Ev 'ehci|xhci|sdhci|uas|usbhid'` 2>/dev/null  # keep ehci,xhci,sdhci,uas,usbhid
fi

# If grub kernel-line rdsh5 specified then start busybox job control shell
_rdsh rdsh5

[ "$umount_bootdevice" == "allowed" ] && echo -e "\e[96mYou can now umount bootdevice if you wish\e[0m" >/dev/console

# if pre_switch_root.plug exists in bootfrom directory source it
[ -s merged"${mountfrom}"/pre_switch_root.plug ] && . merged"${mountfrom}"/pre_switch_root.plug

# Unmount virtual filesystems prior to making switch_root to main merged root filesystem
umount /dev && umount /sys && umount /proc && sync
exec switch_root merged /sbin/init
CODE_FOR_INITRAMFS_INITc
# make firstrib_rootfs_for_initramfsXX/init script executable:
chmod +x firstrib_rootfs_for_initramfs_sNNN/init

if [ "$kernel" == "void" ]; then # do this section only if kernel=void
	# Create inittab file for inside main firstrib_rootfs build
	cat > firstrib_rootfs/etc/inittab << "CODE_FOR_ROOTFS_INITTAB"
::sysinit:/etc/rc.d/rc.sysinit
::ctrlaltdel:/sbin/reboot -f
CODE_FOR_ROOTFS_INITTAB
	# Note that inittab causes the switch_root called busybox (sysv)init to
	# run script /etc/rc.d/rc.sysinit, which is coded below

	# Create rc.sysinit script for inside main firstrib_rootfs build
	mkdir -p firstrib_rootfs/etc/rc.d
	cat > firstrib_rootfs/etc/rc.d/rc.sysinit << "CODE_FOR_ROOTFS_RC_SYSINIT"
#!/bin/sh
# rc.sysinit: Copyright William McEwan (wiak) 16 July 2019; Licence MIT (aka X11 license)
# Revision 1.0.2 17 Aug 2019

# In simplest FirstRib initramfs05 this rc.sysinit script is called
# via /sbin/init being, via /usr/bin/init, a symlink to /usr/bin/busybox (sysv)init,
# which automatically reads /etc/inittab file whose first line says to run this script.
# Should runit-void package be installed, /usr/bin/init should be modified
# to become instead a symlink to /usr/bin/runit-init. Then /etc/runit
# scripts will be used automatically by runit services instead,
# and this script will not be used.
# If you want to run without any init, just modify /usr/bin/init to be a symlink to /etc/rc.d/rc.sysinit

# The first part of the following is modified/skeleton extract from
# Void Linux /etc/runit/core-services/00-pseudofs.sh
# so we partly know what to expect should we later move to runit-init system

#msg "Mounting pseudo-filesystems..."
mountpoint -q /proc || mount -o nosuid,noexec,nodev -t proc proc /proc
mountpoint -q /sys || mount -o nosuid,noexec,nodev -t sysfs sys /sys
mountpoint -q /run || mount -o mode=0755,nosuid,nodev,size=$((`free | grep 'Mem: ' | tr -s ' ' | cut -f 4 -d ' '`/4))k -t tmpfs run /run  # this version needs entry in /etc/fstab like in Void Linux
mountpoint -q /dev || mount -o mode=0755,nosuid -t devtmpfs dev /dev
mkdir -p -m0755 /run/runit /run/lvm /run/user /run/lock /run/log /dev/pts /dev/shm
mountpoint -q /dev/pts || mount -o mode=0620,gid=5,nosuid,noexec -n -t devpts devpts /dev/pts
mountpoint -q /dev/shm || mount -o mode=1777,nosuid,nodev,size=$((`free | grep 'Mem: ' | tr -s ' ' | cut -f 4 -d ' '`/4))k -n -t tmpfs shm /dev/shm
mountpoint -q /tmp || mount -t tmpfs -o mode=1777,nosuid,nodev,size=$((`free | grep 'Mem: ' | tr -s ' ' | cut -f 4 -d ' '`/4))k tmpfs /tmp
mountpoint -q /sys/kernel/security || mount -n -t securityfs securityfs /sys/kernel/security
# end of modified/skeleton extract from Void /etc/runit/core-services/00-pseudofs.sh

[ -x /etc/rc.local ] && /etc/rc.local	# If /etc/rc.local script exists and is executable, run it
										# User can add custom commands into that script
echo "Starting udev and waiting for devices to settle..." >/dev/console
udevd --daemon
udevadm trigger --action=add --type=subsystems
udevadm trigger --action=add --type=devices
udevadm settle

printf "\e[44mWelcome to this FirstRib WeeDog (Void Linux flavour)\e[0m
\e[34mhttps://github.com/firstrib/firstrib
http://weedog.com\e[0m
" >/dev/console
										
# Don't really need busybox (sysv)init in this version
# since just running a simple shell in endless loop
while true # Do forever loop
do
	# this while loop means exit of shell always restarts new shell
	setsid sh -c 'exec sh </dev/tty1 >/dev/tty1 2>&1'
done
# Never reaches here:
exit
CODE_FOR_ROOTFS_RC_SYSINIT
	# make firstrib_rootfs/etc/rc.d/rc.sysinit script executable:
	chmod +x firstrib_rootfs/etc/rc.d/rc.sysinit
fi  # end of kernel=void only code section

#Stage3: create 01firstrib_rootfs.sfs and initramfsXX.gz:

# Squash up filesystem firstrib_rootfs
# For high compression can use args: -comp xz -b 524288 -Xdict-size 524288 -Xbcj x86
# Some alternative mksquashfs compression possibilities:
# comp="-noX -noI -noD -noF"  # or simply use uncompressed NNdirectory
# comp="-comp lzo"
# comp="-comp lz4 -Xhc"
# comp="-comp xz -b 524288 -Xdict-size 524288 -Xbcj x86"
mksquashfs firstrib_rootfs 01firstrib_rootfs.sfs -noappend $comp
if [ "$huge" == "true" ];then  # initramfs to include 01firstrib_rootfs.sfs
	mkdir -p firstrib_rootfs_for_initramfs_sNNN/boot/initramfsNN
	cp -a 01firstrib_rootfs.sfs firstrib_rootfs_for_initramfs_sNNN/boot/initramfsNN
fi
# If you want to copy extra sfs into initramfs, or to simply do or
# create anything extra at this stage, you can code/source plugin below
if [ -s ./"weedog_extra_sfs.plug" ];then . ./"weedog_extra_sfs.plug";fi
# Next is simple mkinitramfs code
# which does the actual creation of the initramfs required for booting
cd firstrib_rootfs_for_initramfs_sNNN
# make a gz compressed cpio archive of firstrib_rootfs naming it initramfs05.gz
if [ "$huge" == "true" ];then
	echo "Creating uncompressed initramfs. Please wait patiently..."
	find . | cpio -oH newc > ../initramfs05  # uncompressed if huge initramfs
else
	echo "Creating compressed initramfs. Please wait patiently..."
	find . | cpio -oH newc 2>/dev/null | gzip > ../initramfs05.gz
fi
cd ..  # cd to immediately outside firstrib_rootfs directory
sync
printf '
initramfs05.gz is now ready along with 01firstrib_rootfs.sfs and, if 
$1 is distro_name, a copy of the vmlinuz kernel of that distro.
Copy these to your chosen boot partition/directory.
If using vmlinuz from kernel is distro_name (preferred) you must 
(e.g. for Void) build_firstrib_rootfs to at least install linuxX.XX,
ncurses-base, linux-firmware-network (and optional: wifi-firmware).
Could also build hybrid system using vmlinuz from 32bit or
64bit BionicPup, in which case you also need its zdrvXXX.sfs but
converted to 00firstrib_firmware_modules.sfs using:
./zdrv_convert.sh <filename of Puppy zdrv>
You need either NNfirstrib_rootfs.sfs, renamed from the automatically
created 01firstrib_rootfs.sfs, OR:
a copy of the uncompressed firstrib_rootfs directory renamed to
NNfirstrib_rootfs, where NN should usually be 01 (lowest layer) but can
be 01 up to 99 (depending on layer position required).
You can also copy additional sfs files named NNsomething.sfs (or an 
unsquashed directory, of any such sfs, named NNsomething).
Finally create appropriate grub.cfg or grub4dos menu.lst boot entry
using kernel-line bootparam: bootfrom=/mnt/partition/directory,
optional usbwait=duration (for slow boot devices),
optional rdsh0, rdsh1, rdsh2, rdsh3, rdsh4 to load rdshN.plug|debug sh,
optional pre_switch_root.plug, which will be sourced by initramfs/init,
optional copy2ram, which copies all NNsfs, NNdirs, rdshN.plug to RAM,
optional changes=[option] where option can be:
RAM for no persistence, readonly for no writes, or /mnt/partition/dir
for dir location where upper_changes subdir will be stored.
optional altNN=path2dir for alternative location for NNsfs/dirs.  
'
exit
