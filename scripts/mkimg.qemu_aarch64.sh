profile_qemu_aarch64() {
	viryaos_grub_mod="part_gpt fat ext2 iso9660 gzio linux acpi normal cpio crypto disk boot crc64 gpt search_disk_uuid tftp verify xzio xfs video gfxterm efi_gop xen_boot"

	arch="aarch64"
	output_format="qemu_aarch64_img"

	kernel_flavors="qemu_aarch64-dom0"

	# --extra-repository '@apkrepo-dom0-qemu_aarch64 ...' in `README.md`
	kernel_flavors_repo="@apkrepo-dom0-qemu_aarch64"

	kernel_cmdline="console=ttyS0"

	initfs_features="ata base bootchart cdrom squashfs ext2 ext3 ext4 scsi"
	initfs_cmdline="modules=loop,squashfs rootfs_cpio"

	viryaos_rel_ver="2018.09.0"
}

create_image_qemu_aarch64_img() {
	set -e

	# Set the CONTAINER_OUTPUT directory
	local CONTAINER_OUTPUT="/tmp/output-dom0-builder-qemu_aarch64/"

	local _vmlinuz=$(basename ${WORKDIR}/kernel_*/boot/vmlinuz-*)
	local _fullkver=${_vmlinuz#vmlinuz-}

	cp ${DESTDIR}/boot/vmlinuz-${_fullkver}   ${CONTAINER_OUTPUT}
	cp ${DESTDIR}/boot/initramfs-${_fullkver} ${CONTAINER_OUTPUT}
	cp ${DESTDIR}/boot/modloop-${_fullkver}   ${CONTAINER_OUTPUT}

	cp ${DESTDIR}/rootfs.cpio                 ${CONTAINER_OUTPUT}
}

section_rootfs_qemu_aarch64() {
	build_section rootfs_qemu_aarch64 $(echo "rootfs_qemu_aarch64" | checksum)
}

build_rootfs_qemu_aarch64() {
	local _script="${PWD}/genrootfs_qemu_aarch64-dom0.sh"
	$_script -a aarch64 -r "$APKROOT/etc/apk/repositories" -k /etc/apk/keys -o "$DESTDIR" -v "$viryaos_rel_ver"
}

# adapted from upstream `grub_gen_config()`
viryaos_grub_gen_config() {
	local _vmlinuz=$(basename ${WORKDIR}/kernel_*/boot/vmlinuz-*)
	local _fullkver=${_vmlinuz#vmlinuz-}

	cat <<- EOF

	set timeout=1
	set gfxpayload=text

	menuentry "Linux $_fullkver" {
		insmod part_gpt
		insmod ext2

		set root=(hd0,gpt2)

		linux   /vmlinuz-$_fullkver $initfs_cmdline $kernel_cmdline
		initrd  /initramfs-$_fullkver
	}
	EOF
}

# adapted from upstream `build_grub_cfg()`
build_viryaos_grub_cfg() {
	local grub_cfg="$1"
	mkdir -p "${DESTDIR}/$(dirname $grub_cfg)"
	viryaos_grub_gen_config > "${DESTDIR}"/$grub_cfg
}

# adapted from upstream `build_grub_efi()`
build_viryaos_grub_efi() {
	local _format="$1"
	local _efi="$2"

	# Prepare grub-efi bootloader
	mkdir -p "$DESTDIR/viryaos-grub-efi"

	/usr/local/viryaos-grub/cross-aarch64/bin/grub-mkimage \
		--format="$_format" \
		--output="$DESTDIR/viryaos-grub-efi/$_efi" \
		--prefix="/EFI/ViryaOS" \
		$viryaos_grub_mod
}

# adapted from upstream `section_grub_efi()`
section_viryaos_grub_efi() {
	[ -n "$viryaos_grub_mod" ] || return 0

	local _format _efi
	case "$arch" in
	aarch64)_format="arm64-efi";  _efi="grubaa64.efi" ;;
	x86_64)	_format="x86_64-efi"; _efi="grubx64.efi"  ;;
	*)	return 0 ;;
	esac

	build_section viryaos_grub_cfg viryaos-grub-cfg/grub.cfg $(viryaos_grub_gen_config | checksum)
	build_section viryaos_grub_efi $_format $_efi $(echo "viryaos_grub_efi" | checksum)
}
