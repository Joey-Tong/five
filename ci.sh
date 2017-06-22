#!/bin/bash

root_dir=$PWD
RELEASE_FOLDER_ROOT=/home/gssing/develop/bin/aiolia

. ./dingtalk.sh

# build(is_release)


check_folder()
{
	folder=$1

	if ! [ -d $folder ]; then
		return 1
	fi

	folder_size=$(du -s $folder | awk '{print $1}')

	if [ $folder_size -lt 10 ]; then
		return 1
	fi

}

build()
{
	# config
	release=$1
	[ "$release" = "" ] && release=0
	if [ $release -eq 1 ]; then
		config_file=ar71xx_aiolia.config
		output_folder_name=release	
	else	
		config_file=ar71xx_aiolia_debug.config
		output_folder_name=debug
	fi

	if [ -d build/aiolia ]; then
		rm -rf build/aiolia
	fi

	check_folder "$root_dir/zb_update_image"
	if [ $? -ne 0 ]; then
		echo "Zigbee update image was not found."
		return 1
	fi

	check_folder "$root_dir/zb_image"
	if [ $? -ne 0 ]; then
		echo "Zigbee image was not found."
		return 1
	fi

	git clone git@192.168.0.2:aiolia build/aiolia
	cd build/aiolia

	# get specific tag
	version=$2
	if [ "$version" != "" ]; then
		echo "checkout $version..."
		git checkout $version
		if [ $? -ne 0 ]; then
			echo "Invalid version."
			return 1
		fi
	fi

	cp $root_dir/zb_update_image aiolia/src/regu/zb_preprocess -fr
	cp "qca/configs/qca955x.ln/$config_file" .config
	make package/symlinks
	make defconfig
	time -p make -j8
	if [ $? -ne 0 ]; then
		return 1
	fi
	cp "$root_dir/zb_image" bin/ar71xx -fr

	# copy build result
	rm -rf "$root_dir/aiolia_ci_output/$output_folder_name"
	mkdir -p "$root_dir/aiolia_ci_output/$output_folder_name"
	cp bin/ar71xx/* "$root_dir/aiolia_ci_output/$output_folder_name" -fr
	cp staging_dir/host/bin/ksios-server "$root_dir/aiolia_ci_output/$output_folder_name"
	cp staging_dir/host/bin/ksios-client "$root_dir/aiolia_ci_output/$output_folder_name"

	cd "$root_dir"
}

release()
{
	if [ $1 -eq 0 ]; then
		type="debug"
	else
		type="release"
	fi

	dest_dir=$RELEASE_FOLDER_ROOT/$2/$type
	mkdir -p $dest_dir
	
	cp $root_dir/aiolia_ci_output/$type/zb_image $dest_dir -fr
	cp $root_dir/aiolia_ci_output/$type/zb_update_image $dest_dir -fr
	cp $root_dir/aiolia_ci_output/$type/*.sig $dest_dir -f
	cp $root_dir/aiolia_ci_output/$type/userdata.img $dest_dir -f
	cp $root_dir/aiolia_ci_output/$type/update-description.txt $dest_dir -f
	cp $root_dir/aiolia_ci_output/$type/factory.bin $dest_dir -f
	cp $root_dir/aiolia_ci_output/$type/openwrt-ar71xx-ap135-qca-legacy-uboot.bin $dest_dir -f
	cp $root_dir/aiolia_ci_output/$type/openwrt-ar71xx-ap135-qca-legacy-ubootenv.bin $dest_dir -f
	cp $root_dir/aiolia_ci_output/$type/openwrt-ar71xx-generic-aiolia-a0-kernel.bin $dest_dir -f
	cp $root_dir/aiolia_ci_output/$type/openwrt-ar71xx-generic-aiolia-a0-rootfs-squashfs.bin $dest_dir -f
	cp $root_dir/aiolia_ci_output/$type/openwrt-ar71xx-generic-aiolia-a0-squashfs-sysupgrade.bin $dest_dir -f
}

get_username()
{
	grep -P "^$(whoami):" /etc/passwd | awk -F ':' '{print $5}' | sed 's/\(.[^,]*\).*/\1/'
}

build_release()
{
	tag=$1
	ding_print "Building release version $tag from $(get_username)..."
	err=$(build 1 $tag)
	if [ $? -ne 0 ]; then
		ding_print "Build failed. Message: $err"
	else
		ding_print "Build SUCCEED!"
	fi
}

build_debug()
{
	tag=$1
	ding_print "Building debug version $tag from $(get_username)..."
	err=$(build 0 $tag)
	if [ $? -ne 0 ]; then
		ding_print "Build failed. Message: $err"
	else
		ding_print "Build SUCCEED!"
	fi
}

trap "ding_print \"Canceled by Linux.\"; exit" SIGTERM SIGHUP SIGINT

if [ "$1" = "release" ]; then
	build_release "$2"
elif [ "$1" = "debug" ]; then
	build_debug "$2"
else
	build_release $1
	build_debug $1

	release 0 $1
	release 1 $1
fi
