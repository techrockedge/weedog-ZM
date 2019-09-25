#!/bin/sh
# Build script to create FirstRib rootfs (structure and contents); Flavour Choice
# Uses busybox static plus relevant native package manager or debootstrap code
# Revision 1.0.3 Date: 23 Sep 2019
# Copyright wiak 23 May 2019+; Licence MIT (aka X11 license)

##### Just run this script from an empty directory to create firstrib_rootfs
# NOTE: You should run this from appropriate Linux host architecture relevant to the build required
# It uses 32-bit busybox static for all system architectures
# ----------------------------------------------------------

trap _trapcleanup INT TERM ERR

#### variables-used-in-script:
# script commandline arguments $1 $2 $3 $4
distro="$1"; release="$2"; arch="$3"	
export release arch

# where distro is currently one of void, ubuntu, debian or devuan
# where release is one of oldstable, stable, testing, or unstable
# where arch is currently one of i386, amd64, or arm64

firstribplugin="firstrib00.plug"	# contains extra commandlines to execute in chroot during build
									# e.g. xbps-install -y package_whatever (for Void flavour)
									# e.g. apt install -y package_whatever (for deb-based flavour)
[ "$4" ] && firstribplugin="$4"		# optional first parameter specifies alternative firstrib plugin name
#### ----------------- end of variables used

#### functions-used-in-script:
_trapcleanup (){
	# Just a quick attempt to clean up some possible chroot-related mounts
	umount -l firstrib_rootfs/proc && umount -l firstrib_rootfs/sys && umount -l firstrib_rootfs/dev/pts && umount -l firstrib_rootfs/dev
	exit
}

_usage (){
	case "$1" in
		'-v'|'--version') echo "Build FirstRib firstrib_rootfs Revision 1.0.3";exit;;

		'-h'|'--help'|'-?') printf '
Usage:
./build_firstrib_rootfs_XXX.sh distro release arch [filename.plug] or
./build_firstrib_rootfs_XXX.sh distro release arch [filename.plug.tgz]
NOTE WELL that primary plugin (e.g. firstrib00.plug) is not a script,
it is simply a list of commandlines without any hash bang shell header.
Also NOTE that a tgz (or tar.gz) form of plugin must contain the primary
plugin. It can also contain a plugins directory, which itself contains
other plugins and/or executable scripts. These get copied into 
firstrib_rootfs/tmp so that primary plugin can subsequently source or
execute the plugins dir contents from /tmp/plugins/*
A primaryplug.tar.gz plugin should contain two first level items in its
archive: primaryplug.plug plugins/
For example, firstrib00.plug.tar.gz should contain firstrib00.plug
alongside directory plugins/

-v --version    display version information and exit
-h --help -?    display this help and exit

For more details read the attached README and/or
visit: https://github.com/firstrib/firstrib
';exit;;
		"-*") echo "option $1 not available";exit;;
	esac
}

_void_amd64 (){
	repo="https://alpha.de.repo.voidlinux.org"  # default build repo
	if [ -s "./firstrib.repo" ];then . "./firstrib.repo"; fi
	# i.e. If firstrib.repo exists then source it to change build repo from above default
	# For example, for "us" repo, firstrib.repo text file should just contain the single commandline
	#              repo="http://alpha.us.repo.voidlinux.org"

	# build firstrib_rootfs
	mkdir -p firstrib_rootfs
	cd firstrib_rootfs
	# make rootfilesystem directory structure
	mkdir -p boot/kernel dev/pts etc/skel etc/udhcpc etc/xbps.d home/void media mnt opt proc root run sys tmp usr/bin usr/include usr/lib32 usr/libexec usr/local/bin usr/local/include usr/local/lib usr/local/sbin usr/local/share usr/share/udhcpc usr/share/xbps.d usr/src var/log

	# The following is per Void Linux structure. e.g. puts most all binaries in /bin and most all libs in /usr/lib:
	ln -s usr/bin bin; ln -s usr/lib lib; ln -s usr/sbin sbin; ln -s bin usr/sbin; ln -s usr/lib lib64
	ln -s usr/lib32 lib32         # In i686 version /usr/lib32 is just a symlink to /lib and there is no /lib32
	# ln -s usr/lib usr/local/lib # Seems required in i686 32bit version but not I think in this one

	# Using i686 32-bit busybox to begin with, even in x86_64 build (user can install coreutils later if so wanted)
	wget -c https://busybox.net/downloads/binaries/1.30.0-i686/busybox -O usr/bin/busybox && chmod +x usr/bin/busybox

	# Make the command applet symlinks for busybox
	cd usr/bin; for i in `./busybox --list`; do ln -s busybox $i; done; mv getty gettyDISABLED; cd ../..

	# Fetch busybox udhcpc example simple.script renamed to etc/udhcpc/default.script 
	# For ethernet connection simply then need enter command: udhcpc -i <interface_name> 
	# You can find interface names with command: ip link, or ip address (for example eth0, eno1, ... etc, for ethernet)
	# Note that for wifi (interface_name: wlan0, wls1, etc), prior to obtaining dhcp lease you 
	# need to install, configure and run wpa_supplicant using following two wpa commands:
	# wpa_passphrase <wifiSSID> <wifiPassword> >> /etc/wpa_supplicant/wpa_supplicant.conf
	# wpa_supplicant -B -i <device> -c /etc/wpa_supplicant/wpa_supplicant.conf (option -B means run daemon in Background)
	wget -c https://git.busybox.net/busybox/plain/examples/udhcp/simple.script -O etc/udhcpc/default.script && chmod +x etc/udhcpc/default.script
	sed -i 's/\$((metric++))/\$metric; metric=\$((metric+1))/' etc/udhcpc/default.script  # thanks rockedge for url of fix
	# But this static busybox udhcpc needs default.script in /usr/share/udhcpc (unlike debian shared busybox):
	mkdir -p usr/share/udhcpc && cp etc/udhcpc/default.script usr/share/udhcpc/default.script

	# The following puts xbps static binaries in firstrib_rootfs/usr/bin
	wget -c ${repo}/static/xbps-static-latest.x86_64-musl.tar.xz
	tar xJvf xbps-static-latest.x86_64-musl.tar.xz && rm xbps-static-latest.x86_64-musl.tar.xz

	# Default void repos use usr/share/xbps.d https repos, so ssl certs needed for these:
	echo "repository=${repo}/current" > usr/share/xbps.d/00-repository-main.conf
	echo "repository=${repo}/current/nonfree" > usr/share/xbps.d/10-repository-nonfree.conf
	# If no sslcertificates available can use insecure temporary /etc/xbps.d non-https repos:
	# echo "repository=http://alpha.us.repo.voidlinux.org/current" > etc/xbps.d/00-repository-main.conf
	# echo "repository=http://alpha.us.repo.voidlinux.org/current/nonfree" > etc/xbps.d/10-repository-nonfree.conf

	# But here we download/install sslcerts instead, from wiak github repo, for higher build security:
	wget -c https://raw.githubusercontent.com/firstrib/firstrib/master/sslcerts.tar.xz
	tar xJf sslcerts.tar.xz && rm sslcerts.tar.xz

	# cd to where we started this build (i.e. immediately outside of firstrib_rootfs):
	cd ..

	# if plugin file exists this script copies it (or, if a tar.gz or tgz file, untars its contents) 
	# into firstrib_rootfs/tmp to be used (e.g. sourced) in chroot build part
	# The plugin file should contain any extra commandlines you want executed in chroot during build
	# e.g. xbps-install -y package_whatever
	# NOTE WELL the -y above, since chroot needs answer supplied
	# also note that the primary plugin is not a script, simply a list
	# of commandlines without any hash bang shell header
	if [ -s "${firstribplugin}" ];then
		if [ "${firstribplugin: -2}" == "gz" ];then
			tar xzvf "${firstribplugin}" -C firstrib_rootfs/tmp
			firstribplugin=`echo "${firstribplugin}" | sed 's%.tar.gz$%%;s%.tgz$%%'`
		else
			cp "${firstribplugin}" firstrib_rootfs/tmp
		fi
	fi

	# Next part of script does required bind mounts for chroot and installs extras required
	mount --bind /proc firstrib_rootfs/proc && mount --bind /sys firstrib_rootfs/sys && mount --bind /dev firstrib_rootfs/dev && mount -t devpts devpts firstrib_rootfs/dev/pts && cp /etc/resolv.conf firstrib_rootfs/etc/resolv.conf

	# The following commands gets done inside firstrib_rootfs (via here_document pipe to chroot):
cat << INSIDE_CHROOT | chroot firstrib_rootfs sh
xbps-install -Suy xbps-triggers base-files xbps
# make sure xbps continues to use desired main and non-free repos
sleep 1  # to give time for xbps static to complete above installs
echo "repository=${repo}/current" > usr/share/xbps.d/00-repository-main.conf
echo "repository=${repo}/current/nonfree" > usr/share/xbps.d/10-repository-nonfree.conf
rm /usr/bin/xbps*.static  # Since dynamic xbps now installed
sleep 1  # to give time to make sure shared lib xbps will be used
xbps-install -y eudev	# You can comment this line out if not using eudev to hotplug detect devices/firmware
						# For example, not required when using firstrib_rootfs in Linux host chroot scenario
xbps-install -y wpa_supplicant  # You can comment this line out if not using wifi (e.g. as above comment)
# The optional text file named in "$firstribplugin" should simply contain a list of extra commands
if [ -s "/tmp/${firstribplugin}" ];then . "/tmp/${firstribplugin}";fi
exit
INSIDE_CHROOT

	# Finished doing the INSIDE_CHROOT stuff so can now clean up the chroot bind mounts:
	umount firstrib_rootfs/proc && umount firstrib_rootfs/sys && umount firstrib_rootfs/dev/pts && umount firstrib_rootfs/dev
	rm -rf firstrib_rootfs/tmp/*
}

_void_i386 (){
	repo="https://alpha.de.repo.voidlinux.org"  # default build repo
	if [ -s "./firstrib.repo" ];then . "./firstrib.repo"; fi
	# i.e. If firstrib.repo exists then source it to change build repo from above default

	# build firstrib_rootfs
	mkdir -p firstrib_rootfs
	cd firstrib_rootfs
	# make rootfilesystem directory structure
	mkdir -p boot/kernel dev/pts etc/skel etc/udhcpc etc/xbps.d home/void media mnt opt proc root run sys tmp usr/bin usr/include usr/libexec usr/local/bin usr/local/include usr/local/lib usr/local/sbin usr/local/share usr/share/udhcpc usr/share/xbps.d usr/src var/log

	# The following is per Void Linux structure. e.g. puts most all binaries in /bin and most all libs in /usr/lib:
	ln -s usr/bin bin; ln -s usr/lib lib; ln -s usr/sbin sbin; ln -s bin usr/sbin
	# ln -s usr/lib lib64       # Required in x86_64 version but not I think in this one
	ln -s lib usr/lib32         # In x86_64 version /usr/lib32 is an actual directory not a symlink
	ln -s usr/lib usr/local/lib # Seems to be required in i686 version

	# Using i686 32-bit busybox to begin with (user can install coreutils later if so wanted)
	wget -c https://busybox.net/downloads/binaries/1.30.0-i686/busybox -O usr/bin/busybox && chmod +x usr/bin/busybox

	# Make the command applet symlinks for busybox
	cd usr/bin; for i in `./busybox --list`; do ln -s busybox $i; done; mv getty gettyDISABLED; cd ../..

	# Fetch busybox udhcpc example simple.script renamed to etc/udhcpc/default.script 
	wget -c https://git.busybox.net/busybox/plain/examples/udhcp/simple.script -O etc/udhcpc/default.script && chmod +x etc/udhcpc/default.script
	sed -i 's/\$((metric++))/\$metric; metric=\$((metric+1))/' etc/udhcpc/default.script  # thanks rockedge for url of fix
	# But this static busybox udhcpc needs default.script in /usr/share/udhcpc (unlike debian shared busybox):
	mkdir -p usr/share/udhcpc && cp etc/udhcpc/default.script usr/share/udhcpc/default.script

	# The following puts xbps static binaries in firstrib_rootfs/usr/bin
	wget -c ${repo}/static/xbps-static-latest.i686-musl.tar.xz
	tar xJvf xbps-static-latest.i686-musl.tar.xz && rm xbps-static-latest.i686-musl.tar.xz

	# Default void repos use usr/share/xbps.d https repos, so ssl certs needed for these:
	echo "repository=${repo}/current" > usr/share/xbps.d/00-repository-main.conf
	echo "repository=${repo}/current/nonfree" > usr/share/xbps.d/10-repository-nonfree.conf
	# If no sslcertificates available can use insecure temporary /etc/xbps.d non-https repos:
	# echo "repository=http://alpha.us.repo.voidlinux.org/current" > etc/xbps.d/00-repository-main.conf
	# echo "repository=http://alpha.us.repo.voidlinux.org/current/nonfree" > etc/xbps.d/10-repository-nonfree.conf

	# But here we download/install sslcerts instead, from wiak github repo, for higher build security:
	wget -c https://raw.githubusercontent.com/firstrib/firstrib/master/sslcerts.tar.xz
	tar xJf sslcerts.tar.xz && rm sslcerts.tar.xz

	# cd to where we started this build (i.e. immediately outside of firstrib_rootfs):
	cd ..

	# if plugin file exists this script copies it (or, if a tar.gz or tgz file, untars its contents) 
	# into firstrib_rootfs/tmp to be used (e.g. sourced) in chroot build part
	if [ -s "${firstribplugin}" ];then
		if [ "${firstribplugin: -2}" == "gz" ];then
			tar xzvf "${firstribplugin}" -C firstrib_rootfs/tmp
			firstribplugin=`echo "${firstribplugin}" | sed 's%.tar.gz$%%;s%.tgz$%%'`
		else
			cp "${firstribplugin}" firstrib_rootfs/tmp
		fi
	fi

	# Next part of script does required bind mounts for chroot and installs extras required
	mount --bind /proc firstrib_rootfs/proc && mount --bind /sys firstrib_rootfs/sys && mount --bind /dev firstrib_rootfs/dev && mount -t devpts devpts firstrib_rootfs/dev/pts && cp /etc/resolv.conf firstrib_rootfs/etc/resolv.conf

	# The following commands gets done inside firstrib_rootfs (via here_document pipe to chroot):
cat << INSIDE_CHROOT | chroot firstrib_rootfs sh
xbps-install -Suy xbps-triggers base-files xbps
# make sure xbps continues to use desired main and non-free repos
sleep 1  # to give time for xbps static to complete above installs
echo "repository=${repo}/current" > usr/share/xbps.d/00-repository-main.conf
echo "repository=${repo}/current/nonfree" > usr/share/xbps.d/10-repository-nonfree.conf
rm /usr/bin/xbps*.static  # Since dynamic xbps now installed
sleep 1  # to give time to make sure shared lib xbps will be used
xbps-install -y eudev	# You can comment this line out if not using eudev to hotplug detect devices/firmware
						# For example, not required when using firstrib_rootfs in Linux host chroot scenario
xbps-install -y wpa_supplicant  # You can comment this line out if not using wifi (e.g. as above comment)
# The optional text file named in "$firstribplugin" should simply contain a list of extra commands
if [ -s "/tmp/${firstribplugin}" ];then . "/tmp/${firstribplugin}";fi
exit
INSIDE_CHROOT

	# Finished doing the INSIDE_CHROOT stuff so can now clean up the chroot bind mounts and clean /tmp:
	umount firstrib_rootfs/proc && umount firstrib_rootfs/sys && umount firstrib_rootfs/dev/pts && umount firstrib_rootfs/dev
	rm -rf firstrib_rootfs/tmp/*
}

_debian (){
	# If you want a variant other than minbase set env variable DBTSTRP_VARIANT to variant you desire
	# For example: export DBTSTRP_VARIANT=buildd (Refer: man debootstrap)
	debootstrap_url="$1"; distro_url="$2"; export distro_url

	# build firstrib_rootfsDBTSTRP
	mkdir -p firstrib_rootfsDBTSTRP
	cd firstrib_rootfsDBTSTRP
	# make rootfilesystem directory structure
	mkdir -p bin boot/kernel dev/pts etc/skel etc/udhcpc etc/xbps.d home/debian lib lib64 media mnt opt proc root run sbin sys tmp usr/bin usr/include usr/lib32 usr/libexec usr/lib/debootstrap usr/local/bin usr/local/include usr/local/lib usr/local/sbin usr/local/share usr/sbin usr/share/udhcpc usr/src var/log

	# Using i686 32-bit busybox to begin with (user can install coreutils later if so wanted)
	wget -c -nc https://busybox.net/downloads/binaries/1.30.0-i686/busybox -P bin && chmod +x bin/busybox	
	# Make the command applet symlinks for busybox
	cd bin; for i in `./busybox --list`; do ln -s busybox $i; done; mv getty gettyDISABLED; cd ..

	# Fetch busybox udhcpc example simple.script renamed to etc/udhcpc/default.script 
	wget -c https://git.busybox.net/busybox/plain/examples/udhcp/simple.script -O etc/udhcpc/default.script && chmod +x etc/udhcpc/default.script
	sed -i 's/\$((metric++))/\$metric; metric=\$((metric+1))/' etc/udhcpc/default.script  # thanks rockedge for url of fix
	# But this static busybox udhcpc needs default.script in /usr/share/udhcpc (unlike debian shared busybox):
	mkdir -p usr/share/udhcpc && cp etc/udhcpc/default.script usr/share/udhcpc/default.script
		
	# Install Debian debootstrap into debian-based-build /usr hierarchy
	mkdir -p work
	cd work
	wget -c "$debootstrap_url"
	ar -x "${debootstrap_url##*/}"  # ar -x filename
	cd ..
	zcat work/data.tar.gz | tar xv && rm -rf work

	# Download pkgdetails from wiak github repo, for debootstrap
	wget -c https://raw.githubusercontent.com/firstrib/firstrib/master/pkgdetails_uclibc_i686_static_wiak -O usr/lib/debootstrap/pkgdetails && chmod +x usr/lib/debootstrap/pkgdetails

	# cd to where we started this build (i.e. immediately outside of firstrib_rootfsDBTSTRP):
	cd ..
	
	# Next part of script does required bind mounts for chroot used for debootstrap build
	mount --bind /proc firstrib_rootfsDBTSTRP/proc && mount --bind /sys firstrib_rootfsDBTSTRP/sys && mount --bind /dev firstrib_rootfsDBTSTRP/dev && mount -t devpts devpts firstrib_rootfsDBTSTRP/dev/pts && cp /etc/resolv.conf firstrib_rootfsDBTSTRP/etc/resolv.conf

	# debootstrap build is created inside firstrib_rootfsDBTSTRP (via here_document pipe to chroot):
	# Host Linux system does not need debootstrap installed (or perl)
cat << INSIDE_CHROOT | chroot firstrib_rootfsDBTSTRP sh
variant="minbase"
[ "\$DBTSTRP_VARIANT" ] && variant="\$DBTSTRP_VARIANT"  # man debootstrap to see variants available
# Maybe --include apt-transport-https for older distro apt, but new distros (bionic) baulk since not needed
/usr/sbin/debootstrap --extractor=ar --arch=\$arch --variant=\$variant --include=ca-certificates \$release distro_root "\$distro_url"
exit
INSIDE_CHROOT

	# Finished doing the INSIDE_CHROOT stuff so can now clean up the chroot bind mounts:
	umount firstrib_rootfsDBTSTRP/proc && umount firstrib_rootfsDBTSTRP/sys && umount firstrib_rootfsDBTSTRP/dev/pts && umount firstrib_rootfsDBTSTRP/dev
	# Extract distro_root, the debian-based firstrib_rootfs build out of firstrib_rootfsDBTSTRP
	mv firstrib_rootfsDBTSTRP/distro_root firstrib_rootfs

	# if plugin file exists this script copies it (or, if a tar.gz or tgz file, untars its contents) 
	# into firstrib_rootfs/tmp to be used (e.g. sourced) in chroot build part
	if [ -s "${firstribplugin}" ];then
		if [ "${firstribplugin: -2}" == "gz" ];then
			tar xzvf "${firstribplugin}" -C firstrib_rootfs/tmp
			firstribplugin=`echo "${firstribplugin}" | sed 's%.tar.gz$%%;s%.tgz$%%'`
		else
			cp "${firstribplugin}" firstrib_rootfs/tmp
		fi
	fi

	# Next part of script does required bind mounts for chroot used to
	# directly install extras required or by means of firstrib00.plug
	mount --bind /proc firstrib_rootfs/proc && mount --bind /sys firstrib_rootfs/sys && mount --bind /dev firstrib_rootfs/dev && mount -t devpts devpts firstrib_rootfs/dev/pts && cp /etc/resolv.conf firstrib_rootfs/etc/resolv.conf

	# The following commands gets done inside firstrib_rootfs (via here_document pipe to chroot):
cat << INSIDE_CHROOT2 | chroot firstrib_rootfs sh
# The optional text file named in "$firstribplugin" should simply contain a list of extra commands
if [ -s "/tmp/${firstribplugin}" ];then . "/tmp/${firstribplugin}";fi

# The following could be placed in firstrib00.plug so that 
# 'build WeeDog initramfsXXX' can find the required kernel/modules:
#
# linux-image-4.9.0-9-amd64 - Linux 4.9 for 64-bit PCs
# or, linux-image-amd64 - Linux for 64-bit PCs (meta-package) 
#
# That is, put following in firstrib00.plug prior to
# running ./build_firstrib_rootfsXX.sh <arguments>
#
# apt update && apt install linux-image-amd64 -y

# For my own system's wifi, I also need: apt install firmware-iwlwifi -y
# However, that is non-free firmware so can't do that in firstrib00.plug
# at the moment, because I first need to add "contrib non-free" repo
# to firstrib_rootfs/etc/apt/sources.list (can do via mount_chroot utility)
# For example, for debian stable:
# echo "deb http://httpredir.debian.org/debian/ stable main contrib non-free" >>/etc/apt/sources.list
# (or depending on release being built, replace 'stable' with oldstable,
#  testing, unstable, or release name like 'stretch')
exit
INSIDE_CHROOT2

	# Finished doing the INSIDE_CHROOT2 stuff so can now clean up the chroot bind mounts:
	umount firstrib_rootfs/proc && umount firstrib_rootfs/sys && umount firstrib_rootfs/dev/pts && umount firstrib_rootfs/dev
	rm -rf firstrib_rootfs/tmp/*
	# Clean up no longer required build assembly
	rm -rf firstrib_rootfsDBTSTRP
}

_arch_amd64 (){ # For FirstRib Arch Linux flavour under dev/test/not-yet-released
	# wiak remove later: The following puts pacman static binary in
	# firstrib_rootfs [ARCH]/usr/bin. I will try this pacman static first since
	# though simple to build Arch rootfs using arch-bootstrap (like debian debootstrap),
	# arch_bootstrap has several dependencies: bash >= 4, coreutils, wget, sed, gawk, tar, gzip, chroot, xz
	:
}

_arch_i386 (){ # wiak remove later: under dev/test/not-yet-released
	:
}
#### ----------------- end of functions used

_usage "$1"  # check if - or --cmdarg (e.g. --version or -h for help)

case "$distro" in
	void)
		case "$arch" in
			amd64)
				_void_amd64  # call build Void amd64 function
			;;
			i386)
				_void_i386  # call build Void i386 function
			;;
			arm64)
				echo "arch $arch is supported by Void but not yet FirstRib";_usage "--help";exit
			;;
			*) # no such arch catered for
				echo "$distro $release $arch not currently available from FirstRib";_usage "--help";exit
			;;
		esac
	;;
	ubuntu)
		case "$release" in
			oldstable|stable|testing|unstable|xenial|bionic|dingo)
				case "$arch" in
					amd64|i386|arm64) # wiak: I have no arm64 hardware, so arm untested and for development only
						debootstrap_url="http://archive.ubuntu.com/ubuntu/pool/main/d/debootstrap/debootstrap_1.0.115ubuntu1_all.deb"
						distro_url="http://archive.ubuntu.com/ubuntu/"
						_debian "$debootstrap_url" "$distro_url"  # call build debian function
					;;
					*) # no such arch catered for
						echo "$distro $release $arch not currently available from FirstRib";_usage "--help";exit
					;;
				esac
			;;
			*) # no such release catered for
				echo "$distro $release not currently available from FirstRib";_usage "--help";exit
			;;
		esac
	;;
	debian)
		case "$release" in
			oldstable|stable|testing|unstable|stretch|buster|sid)
				case "$arch" in
					amd64|i386|arm64) # wiak: I have no arm64 hardware, so arm untested and for development only
						debootstrap_url="http://ftp.debian.org/debian/pool/main/d/debootstrap/debootstrap_1.0.114_all.deb"
						distro_url="http://ftp.us.debian.org/debian/"
						_debian "$debootstrap_url" "$distro_url"  # call build debian function
					;;
					*) # no such arch catered for
						echo "$distro $release $arch not currently available from FirstRib";_usage "--help";exit
					;;
				esac
			;;
			*) # no such release catered for
				echo "$distro $release not currently available from FirstRib";_usage "--help";exit
			;;
		esac
	;;
	devuan)
		case "$release" in
			oldstable|stable|testing|unstable|ascii|beowulf|ceres)
				case "$arch" in
					amd64|i386|arm64) # wiak: I have no arm64 hardware, so arm untested and for development only
						debootstrap_url="http://pkgmaster.devuan.org/devuan/pool/main/d/debootstrap/debootstrap_1.0.114+devuan2_all.deb"
						distro_url="http://pkgmaster.devuan.org/merged/"
						_debian "$debootstrap_url" "$distro_url"  # call build debian function
					;;
					*) # no such arch catered for
						echo "$distro $release $arch not currently available from FirstRib";_usage "--help";exit
					;;
				esac
			;;
			*) # no such release catered for
				echo "$distro $release not currently available from FirstRib";_usage "--help";exit
			;;
		esac
	;;
	arch)  # wiak remove later: Arch Linux - under development - WARNING not ready yet
		case "$arch" in
			amd64)
				_arch_amd64  # call build Arch amd64 function
			;;
			i386)
				_arch_i386  # call build Arch i386 function
			;;
			*) # no such arch catered for
				echo "$distro $release $arch not currently available from FirstRib";_usage "--help";exit
			;;
		esac
	;;
	*) # no such distro catered for
	echo "distro $distro not currently available from FirstRib";_usage "--help";exit
	;;
esac
sync
printf "
firstrib_rootfs flavour $distro $release $arch is now ready.
If you wish, you can now use it via convenience script,
./mount_chrootXXX.sh and after such use, exit, and
run ./umount_chrootXXX.sh
Or, you can 'WeeDog-it' (i.e. make it bootable via WeeDog initramfs)
by running:
./build_weedog_initramfsXX_sXXX.sh <distroname> [OPTIONS], and then
frugal install it by copying the resultant initramfsXX.gz, vmlinuz,
and 01firstrib_rootfs.sfs (or 01firstrib_rootfs directory) into
/mnt/bootpartition/bootdir and configuring grub to boot it from there.
"
exit
