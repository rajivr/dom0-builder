#!/bin/sh

cleanup() {
	sudo rm -rf "$tmp"
}

tmp="$(mktemp -d /tmp/genrootfs_qemu_aarch64-dom0.XXXXXX)"
trap cleanup EXIT

ovl_dir="$(realpath $(dirname $0))/genrootfs_qemu_aarch64-dom0-ovl"

while getopts "a:k:o:r:v:" opt; do
	case $opt in
	a) arch="$OPTARG";;
	k) keys_dir="$OPTARG";;
	o) out_dir="$OPTARG";;
	r) repositories_file="$OPTARG";;
	v) rel_ver="$OPTARG";;
	esac
done
shift $(( $OPTIND - 1))

if [ -z "$arch" ] || [ -z "$keys_dir" ] || [ -z "$out_dir" ] || [ -z "$repositories_file" ] || [ -z "$rel_ver" ]; \
then
	echo "-a, -k, -o, -r, -v options needed"
	exit 1
fi

apk_pkgs="
	alpine-baselayout
	apk-tools
	musl
	openrc

	busybox
	busybox-initscripts

	sudo
	shadow@apkrepo-dom0-qemu_aarch64

	dbus

	bash
	python2
	gettext
	zlib
	ncurses
	texinfo
	yajl
	libaio
	xz-dev
	util-linux
	argp-standalone
	libfdt
	glib
	pixman
	curl
	jq
	busybox-static
	ca-certificates
	"
apks=""
for i in $apk_pkgs; do
	apks="$apks $i"
done

tmprootfs="$tmp/rootfs"

abuild-apk add --arch "$arch" --keys-dir "$keys_dir" --no-cache \
	--repositories-file "$repositories_file" \
	--root "$tmprootfs" --initdb

mkdir -p "$tmprootfs/usr/bin"
cp /usr/bin/qemu-aarch64 "$tmprootfs/usr/bin"


# dbus post-install script requires /dev/urandom
sudo mknod -m 644 "$tmprootfs/dev/urandom" c 1 9

abuild-apk add --arch "$arch" --keys-dir "$keys_dir" --no-cache \
	--repositories-file "$repositories_file" \
	--root "$tmprootfs" $apks

sudo rm -f  "$tmprootfs/dev/urandom"

# NOTE: Install rkt and xen after `abuild-apk add`. Otherwise,
# `alpine-baselayout` package installation causes the following error
# ```
# Executing alpine-baselayout-3.0.5-r2.pre-install
# ERROR: alpine-baselayout-3.0.5-r2: failed to rename var/.apk.f752bb51c942c7b3b4e0cf24875e21be9cdcd4595d8db384 to var/run.
# ```
# install xen
sudo sh -c "cd $tmprootfs; tar xvzf /home/builder/output-viryaos-xen-aarch64/viryaos-xen.tar.gz"

# install rkt
sudo sh -c "cd $tmprootfs; tar xvzf /home/builder/viryaos-rkt.tar.gz"

# setup openrc
runlevel_sysinit="
	devfs
	dmesg
	mdev
	"
for i in $runlevel_sysinit; do
	sudo sh -c "ln -sf /etc/init.d/$i $tmprootfs/etc/runlevels/sysinit/$i"
done

sudo sh -c "echo viryaos-qemu_aarch64-dom0 >> $tmprootfs/etc/hostname"

runlevel_boot="
	sysctl
	hostname
	bootmisc
	syslog
	urandom
	networking
	"
for i in $runlevel_boot; do
	sudo sh -c "ln -sf /etc/init.d/$i $tmprootfs/etc/runlevels/boot/$i"
done

runlevel_default="
	acpid
	crond
	dbus
	local
	xenconsoled
	xenstored
	"
for i in $runlevel_default; do
	sudo sh -c "ln -sf /etc/init.d/$i $tmprootfs/etc/runlevels/default/$i"
done

runlevel_shutdown="
	killprocs
	mount-ro
	savecache
	"
for i in $runlevel_shutdown; do
	sudo sh -c "ln -sf /etc/init.d/$i $tmprootfs/etc/runlevels/shutdown/$i"
done

# Disable `vos-user` account creation
# # setup vos-user account
# # echo "vos-user" | openssl passwd -1 -stdin
# # $1$xTMmPsRW$rzaGmlHqkmaOwGMQW9tl6/
# # NOTE: There is a `\` before the `$` in the hashed password. This is so that
# # shell escapes are correctly handled
# #
# # NOTE: We use `groupadd`  and `useradd` with `-R` option because,
# # double-chrooting seems crash qemu-user.
# /usr/sbin/groupadd -R $tmprootfs -g 500 vos-user
# 
# # Looks like sync is needed here, otherwise `useradd` throws a qemu error
# sync
# 
# /usr/sbin/useradd -R $tmprootfs -d /home/vos-user -g vos-user -s /bin/ash -G wheel -m -N -u 500 vos-user -p '\$1\$xTMmPsRW\$rzaGmlHqkmaOwGMQW9tl6/'

# # setup /etc/sudoers.d/vos-user
# sudo sh -c "cp $ovl_dir/etc-sudoers.d-vos-user $tmprootfs/etc/sudoers.d/vos-user"
# sudo sh -c "chown root:root $tmprootfs/etc/sudoers.d/vos-user"
# sudo sh -c "chmod 440 $tmprootfs/etc/sudoers.d/vos-user"

# disable root password
sudo sh -c "sed -i -e 's/^root.*$/root:*LOCK*:14600::::::/' $tmprootfs/etc/shadow"
sudo sh -c "sed -i -e 's/^root:x:0:0/root::0:0/' $tmprootfs/etc/passwd"

# update /etc/motd
sudo sh -c "cat $ovl_dir/etc-motd > $tmprootfs/etc/motd"
sudo sh -c "sed -i -e s/RELEASE_VERSION/${rel_ver}/ $tmprootfs/etc/motd"

# update /etc/os-release
sudo sh -c "cat $ovl_dir/etc-os-release > $tmprootfs/etc/os-release"
sudo sh -c "sed -i -e s/RELEASE_VERSION/${rel_ver}/ $tmprootfs/etc/os-release"

# setup networking
sudo sh -c "cp $ovl_dir/etc-network-interfaces $tmprootfs/etc/network/interfaces"
sudo sh -c "chown root:root $tmprootfs/etc/network/interfaces"
sudo sh -c "chmod 644 $tmprootfs/etc/network/interfaces"

# setup inittab
sudo sh -c "cp $ovl_dir/etc-inittab $tmprootfs/etc/inittab"
sudo sh -c "chown root:root $tmprootfs/etc/inittab"
sudo sh -c "chmod 644 $tmprootfs/etc/inittab"

# add entries to fstab
# OpenRC localmount service will then take care mounting
mkdir -p $tmprootfs/var/lib/rkt
echo "/dev/vda3	/var/lib/rkt	ext4	defaults,noatime 0 0" >> $tmprootfs/etc/fstab

# setup openrc local scripts
local_scripts="
	01-clean-var-lib-rkt.start
"
for i in $local_scripts; do
	sudo sh -c "cp $ovl_dir/etc-local.d-${i} $tmprootfs/etc/local.d/${i}"
	sudo sh -c "chown root:root $tmprootfs/etc/local.d/${i}"
	sudo sh -c "chmod 755 $tmprootfs/etc/local.d/${i}"
done

rm -f "$tmprootfs/usr/bin/qemu-aarch64"

sudo sh -c "cd $tmprootfs; find . | cpio -H newc -o > $tmp/rootfs.cpio"

cp $tmp/rootfs.cpio $out_dir/rootfs.cpio
