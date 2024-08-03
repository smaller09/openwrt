. /lib/functions.sh

# Prepare UBI devices for OpenWrt installation
# - rootfs (mtd11)
# - data (mtd12)


ax6_restore_config() {
	local ubidev=$( nand_find_ubi "data" )
	local ubivol="$( nand_find_volume $ubidev rootfs_data )"
	if [ ! "$ubivol" ]; then
		echo "cannot find ubifs data volume"
		return 1
	fi
	mkdir /tmp/new_root
	if ! mount -t ubifs /dev/$ubivol /tmp/new_root; then
		echo "cannot mount ubifs volume $ubivol"
		rmdir /tmp/new_root
		return 1
	fi
	if mv "$1" "/tmp/new_root/$BACKUP_FILE"; then
		if umount /tmp/new_root; then
			echo "configuration saved"
			rmdir /tmp/new_root
			return 0
		fi
	else
		umount /tmp/new_root
	fi
	echo "could not save configuration to ubifs volume $ubivol"
	rmdir /tmp/new_root
	return 1
}

ax6_do_restore_config() {
	local conf_tar="/tmp/sysupgrade.tgz"
	[ ! -f "$conf_tar" ] || ax6_restore_config "$conf_tar"
}

ax6_do_upgrade_success() {
	if ax6_do_restore_config && sync; then
		echo "sysupgrade successful"
		umount -a
		reboot -f
	fi
	nand_do_upgrade_failed
}

ax6_do_upgrade() {
	local file="$1"
	echo "AX6 upgrading ..."
	nand_verify_tar_file "$file" "cat" || nand_do_upgrade_failed
	sync
	ax6_upgrade_tar "$file" && ax6_do_upgrade_success
	nand_do_upgrade_failed
}

ax6_upgrade_tar() {

	local tar_file="$1"
	local kern_ubidev
	local root_ubidev
	local data_ubidev
	# WARNING: This fails if tar contains more than one 'sysupgrade-*' directory.
	local board_dir="$(tar tf "$tar_file" | grep -m 1 '^sysupgrade-.*/$')"
	board_dir="${board_dir%/}"

	local ubi_kernel_length=$( (tar xOf "$tar_file" "$board_dir/kernel" | wc -c) 2> /dev/null)
	[ "$ubi_kernel_length" = 0 ] && ubi_kernel_length=
	local rootfs_length=$( (tar xOf "$tar_file" "$board_dir/root" | wc -c) 2> /dev/null)
	[ "$rootfs_length" = 0 ] && rootfs_length=
	local rootfs_type
	[ "$rootfs_length" ] && rootfs_type="$(identify_tar "$tar_file" "$board_dir/root")"
	[ -n "$rootfs_length" -o -n "$ubi_kernel_length" ] || return 1

	kern_ubidev="$( nand_attach_ubi "rootfs" )"
	[ -n "$kern_ubidev" ] || return 1
	root_ubidev="$kern_ubidev"
	data_ubidev="$( nand_attach_ubi "data" )"
	[ -n "$data_ubidev" ] || return 1

	local kern_ubivol="$( nand_find_volume $kern_ubidev "kernel" )"
	local root_ubivol="$( nand_find_volume $root_ubidev "rootfs" )"
	local data_ubivol="$( nand_find_volume $data_ubidev "rootfs_data" )"
	[ "$root_ubivol" = "$kern_ubivol" ] && root_ubivol=

	# remove ubiblocks
	[ "$kern_ubivol" ] && { nand_remove_ubiblock $kern_ubivol || return 1; }
	[ "$root_ubivol" ] && { nand_remove_ubiblock $root_ubivol || return 1; }
	[ "$data_ubivol" ] && { nand_remove_ubiblock $data_ubivol || return 1; }

	# kill volumes
	[ "$kern_ubivol" ] && ubirmvol /dev/$kern_ubidev -N "kernel" || :
	[ "$root_ubivol" ] && ubirmvol /dev/$root_ubidev -N "rootfs" || :
	[ "$data_ubivol" ] && ubirmvol /dev/$data_ubidev -N rootfs_data || :

	# create kernel vol
	if [ -n "$ubi_kernel_length" ]; then
		if ! ubimkvol /dev/$kern_ubidev -N "kernel" -s $ubi_kernel_length; then
			echo "cannot create kernel volume"
			return 1;
		fi
	fi

	# create rootfs vol
	if [ -n "$rootfs_length" ]; then
		local rootfs_size_param
		if [ "$rootfs_type" = "ubifs" ]; then
			rootfs_size_param="-m"
		else
			rootfs_size_param="-s $rootfs_length"
		fi
		if ! ubimkvol /dev/$root_ubidev -N "rootfs" $rootfs_size_param; then
			echo "cannot create rootfs volume"
			return 1;
		fi
	fi

	# create rootfs_data vol
	local rootfs_data_size_param="-m"
	if ! ubimkvol /dev/$data_ubidev -N rootfs_data $rootfs_data_size_param; then
		echo "cannot initialize rootfs_data volume"
		return 1
	fi

	if [ "$rootfs_length" ]; then
		local ubidev="$( nand_find_ubi "rootfs" )"
		local root_ubivol="$( nand_find_volume $ubidev "rootfs" )"
		tar xOf "$tar_file" "$board_dir/root" | \
			ubiupdatevol /dev/$root_ubivol -s "$rootfs_length" -
	fi

	if [ "$ubi_kernel_length" ]; then
		local ubidev="$( nand_find_ubi "rootfs" )"
		local kern_ubivol="$( nand_find_volume $ubidev "kernel" )"
		tar xO${gz}f "$tar_file" "$board_dir/kernel" | \
			ubiupdatevol /dev/$kern_ubivol -s "$ubi_kernel_length" -
	fi

        return 0
}
