#!/bin/bash
RELEASE_FOLDER_ROOT=/home/gssing/develop/bin/plasma

# description file
zbUpdateDescFile=update-description.txt

# basic info
gssingManu=0000

parse_ver_inner_code() {
	local inner=$1
	max_inner_num=11
	inner_list="AL B1 B2 B3 B4 B5 B6 B7 B8 B9 B10"

	if [ $inner -eq 0 ]; then
		echo ""
	elif [ "$inner" -le $max_inner_num ]; then
		item=$(echo "$inner_list" | cut -d ' ' -f $inner)
		echo "$item"
	else
		echo "error inner code: $inner"
	fi
}

get_version() {
	# generate bin
	imageName=$(find "$1"/*.zigbee | sed 's/^.*\///' | sed 's/.zigbee//')

	verstr=${imageName//*-/}
	major=$(echo "$verstr" | cut -b 1-2)
	minor=$(echo "$verstr" | cut -b 3-4)
	build=$(echo "$verstr" | cut -b 5-7)
	hex_inner=$(echo "$verstr" | cut -b 8)
	inner=$(printf "%d" 0x$hex_inner)

	if [ "$inner" -eq "0" ]; then
		verfloat=$(echo "$((16#${major})) $((16#${minor})) $((16#${build}))" | awk '{printf("%d.%d.%d",$1,$2,$3)}')
	else
		inner_code=$(parse_ver_inner_code $inner)
		verfloat=$(echo "$((16#${major})) $((16#${minor})) $((16#${build})) $inner_code" | awk '{printf("%d.%d.%d_%s",$1,$2,$3,$4)}')
	fi
	
	echo $verfloat
}

generate_description_file() {
	# generate bin
	imageName=$(find "$1"/*.zigbee | sed 's/^.*\///' | sed 's/.zigbee//')
	mv "$1/${imageName}.zigbee" "$1/${imageName}.bin"

	# generate description file
	touch "$1/$zbUpdateDescFile"

	# get version info
	verfloat=$2

	# write info to desc. file
	(echo "Filename: $imageName.bin";\
	 echo "Manufacturer: ${imageName//-*/}";\
	 echo "Type: ${imageName#*-}" | sed 's/-.*//';\
	 echo "Version: $verfloat";\
	 echo "Size: $(wc -c < "$1/${imageName}.bin")";\
	 echo "MD5Sum: $(md5sum "$1/${imageName}.bin" | sed 's/\(.*\) .*/\1/')";)\
	 > "$1/$zbUpdateDescFile"
}

file_sign() {
	# image sign
	imageBin=$(find "$1"/*.bin | sed 's/^.*\///')
	gpg --output "$1/${imageBin}.sig" --detach-sign "$1/$imageBin"

	# description file sign
	gpg --output "$1/${zbUpdateDescFile}.sig" --detach-sign "$1/$zbUpdateDescFile"
}

ZB_IMAGE_PATH=
##
if [ "$1" != "" ]; then
	ZB_IMAGE_PATH=$1
else
	# default path
	ZB_IMAGE_PATH=./plasma/zb_update_image
fi

# check the image path is exist or not
if [ ! -e $ZB_IMAGE_PATH ]
then
	echo "zigbee update path not find!"
	exit
fi

# path
ImagePathCoor=coordinator
ImagePathSwitch=switch
ImagePathSensor=sensor
ImagePathPlug=plug
ImagePathArray=($ZB_IMAGE_PATH/$ImagePathCoor $ZB_IMAGE_PATH/$ImagePathSwitch $ZB_IMAGE_PATH/$ImagePathSensor $ZB_IMAGE_PATH/$ImagePathPlug)

version=$(get_version $ZB_IMAGE_PATH/$ImagePathCoor)

##
# search all image path and do something
for ImagePath in ${ImagePathArray[*]}
do
	# debug
	echo $ImagePath

	if [ -e $ImagePath ]&&[ ! "$(ls -A $ImagePath/)" = "" ]
	then
		if [ $? -eq 0 ]
		then
			generate_description_file $ImagePath $version
			file_sign $ImagePath
		fi
	fi
done

dest_dir=$RELEASE_FOLDER_ROOT/$version
mkdir -p $dest_dir/update
cp -fr ./plasma/zb_image/* $dest_dir
cp -fr $ZB_IMAGE_PATH $dest_dir/update
