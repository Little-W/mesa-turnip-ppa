#!/bin/bash -e
green='\033[0;32m'
red='\033[0;31m'
nocolor='\033[0m'

deps="meson ninja patchelf unzip curl pip flex bison zip git"
workdir="$(pwd)/turnip_workdir"
packagedir="$workdir/turnip_module"
mesasrc="https://gitlab.freedesktop.org/mesa/mesa.git"

#array of string => commit/branch;patch args
patches=(
	"fix-for-anon-file;../../turnip-patches/fix-for-anon-file.patch;"
	"fix-for-getprogname;../../turnip-patches/fix-for-getprogname.patch;"
	"zink_fixes;../../turnip-patches/zink_fixes.patch;"
	"dri3;../../turnip-patches/dri3.patch;"
	#"descr-prefetching-optimization-a7xx;merge_requests/29873;"
	#"make-gmem-work-with-preemption;merge_requests/29871;"
	#"VK_EXT_fragment_density_map;merge_requests/29938;"
)
commit=""
commit_short=""
mesa_version=""
vulkan_version=""
clear

run_all(){
	check_deps
	prepare_source
	build_lib "aarch64"
	build_lib "arm"

	if (( ${#patches[@]} )); then
		prepare_source "patched"
		build_lib "aarch64"
		build_lib "arm"
		port_lib "patched" "aarch64"
		port_lib "patched" "arm"
	fi
}

check_deps(){
	echo "Checking system for required dependencies ..."
	for deps_chk in $deps;
	do
		sleep 0.25
		if command -v "$deps_chk" >/dev/null 2>&1 ; then
			echo -e "$green - $deps_chk found $nocolor"
		else
			echo -e "$red - $deps_chk not found, can't continue. $nocolor"
			deps_missing=1
		fi;
	done

	if [ "$deps_missing" == "1" ]
		then echo "Please install missing dependencies" && exit 1
	fi
}

prepare_source(){
	echo "Creating and entering to work directory ..." $'\n'
	mkdir -p "$workdir" && cd "$_"

	if [ -z "$1" ]; then
		if [ -d mesa ]; then
			echo "Removing old mesa ..." $'\n'
			rm -rf mesa
		fi
		
		echo "Cloning mesa ..." $'\n'
		git clone --depth=1 "$mesasrc"  &> /dev/null

		cd mesa
		commit_short=$(git rev-parse --short HEAD)
		commit=$(git rev-parse HEAD)
		mesa_version=$(cat VERSION | xargs)
		version=$(awk -F'COMPLETE VK_MAKE_API_VERSION(|)' '{print $2}' <<< $(cat include/vulkan/vulkan_core.h) | xargs)
		major=$(echo $version | cut -d "," -f 2 | xargs)
		minor=$(echo $version | cut -d "," -f 3 | xargs)
		patch=$(awk -F'VK_HEADER_VERSION |\n#define' '{print $2}' <<< $(cat include/vulkan/vulkan_core.h) | xargs)
		vulkan_version="$major.$minor.$patch"
	else		
		cd mesa

		if [ $1 == "patched" ]; then 
			for patch in ${patches[@]}; do
				echo "Applying patch $patch"
				patch_source="$(echo $patch | cut -d ";" -f 2 | xargs)"
				if [[ $patch_source == *"../.."* ]]; then
					git apply "$patch_source"
					sleep 1
				else 
					patch_file="${patch_source#*\/}"
					patch_args=$(echo $patch | cut -d ";" -f 3 | xargs)
					curl --output "$patch_file".patch -k --retry-delay 30 --retry 5 -f --retry-all-errors https://gitlab.freedesktop.org/mesa/mesa/-/"$patch_source".patch
					sleep 1
				
					git apply $patch_args "$patch_file".patch
				fi
			done
		fi
		
	fi
}

build_lib(){
	target="$1"
	echo "Creating meson cross file for $target ..." $'\n'

	case $target in
		"aarch64")
			cat <<EOF >"$workdir"/"$target"-crossfile
[binaries]
c = 'aarch64-linux-gnu-gcc'
cpp = 'aarch64-linux-gnu-g++'
ar = 'aarch64-linux-gnu-ar'
strip = 'aarch64-linux-gnu-strip'
pkgconfig = 'aarch64-linux-gnu-pkg-config'
[host_machine]
system = 'linux'
cpu_family = 'aarch64'
cpu = 'aarch64'
endian = 'little'
EOF
			;;
		"arm")
			cat <<EOF >"$workdir"/"$target"-crossfile
[binaries]
c = 'arm-linux-gnueabihf-gcc'
cpp = 'arm-linux-gnueabihf-g++'
ar = 'arm-linux-gnueabihf-ar'
strip = 'arm-linux-gnueabihf-strip'
pkgconfig = 'arm-linux-gnueabihf-pkg-config'
[host_machine]
system = 'linux'
cpu_family = 'arm'
cpu = 'arm'
endian = 'little'
EOF
			;;
		*)
			echo "Unknown target $target"
			exit 1
			;;
	esac

	echo "Generating build files for $target..." $'\n'
	meson build-"$target" --cross-file "$workdir"/"$target"-crossfile -Dbuildtype=release -Dplatforms=linux -Dgallium-drivers= -Dvulkan-drivers=freedreno -Dvulkan-beta=true -Dfreedreno-kmds=kgsl -Db_lto=true &> "$workdir"/meson_log
	if [ $? -ne 0 ]; then
		echo -e "$red Meson build generation failed for $target! $nocolor" && exit 1
	fi

	echo "Compiling build files for $target..." $'\n'
	ninja -C build-"$target" &> "$workdir"/ninja_log
	if [ $? -ne 0 ]; then
		echo -e "$red Ninja build failed for $target! $nocolor" && exit 1
	fi
}

port_lib(){
	target="$2"
	echo "Using patchelf to match soname for $target..."  $'\n'
	if [ ! -f "$workdir/mesa/build-$target/src/freedreno/vulkan/libvulkan_freedreno.so" ]; then
		echo -e "$red File libvulkan_freedreno.so not found for $target! $nocolor" && exit 1
	fi
	cp "$workdir"/mesa/build-"$target"/src/freedreno/vulkan/libvulkan_freedreno.so "$workdir"
	cd "$workdir"
	patchelf --set-soname vulkan.adreno.so libvulkan_freedreno.so
	if [ $? -ne 0 ]; then
		echo -e "$red Patchelf failed for $target! $nocolor" && exit 1
	fi

	if [ "$target" == "aarch64" ]; then
		mv libvulkan_freedreno.so aarch64_libvulkan_freedreno.so
	elif [ "$target" == "arm" ]; then
		mv libvulkan_freedreno.so arm_libvulkan_freedreno.so
	fi

	if ! [ -a "${target}_libvulkan_freedreno.so" ]; then
		echo -e "$red Build failed! $nocolor" && exit 1
	fi

	mkdir -p "$packagedir" && cd "$_"

	filename=turnip_"$(date +'%b-%d-%Y')"_"$commit_short"
	echo "Copy necessary files from work directory for $target..." $'\n'
	cp "$workdir"/"${target}_libvulkan_freedreno.so" "$packagedir"

	echo "Packing files into package for $target..." $'\n'
	zip -9 "$workdir"/"$filename$suffix".zip ./*

	cd "$workdir"

	if [ -z "$1" ]; then
		echo "Turnip - $mesa_version - $(date +'%b %d, %Y')" > release
		echo "$mesa_version"_"$commit_short" > tag
		echo  $filename > filename
		echo "### Base commit : [$commit_short](https://gitlab.freedesktop.org/mesa/mesa/-/commit/$commit_short)" > description
		echo "false" > patched
	else		
		if [ $1 == "patched" ]; then 
			echo "## Upstreams / Patches" >> description
			echo "These have not been merged by Mesa officially yet and may introduce bugs or" >> description
			echo "we revert stuff that breaks games but still got merged in (see --reverse)" >> description
			for patch in ${patches[@]}; do
				patch_name="$(echo $patch | cut -d ";" -f 1 | xargs)"
				patch_source="$(echo $patch | cut -d ";" -f 2 | xargs)"
				patch_args="$(echo $patch | cut -d ";" -f 3 | xargs)"
				if [[ $patch_source == *"../.."* ]]; then
					echo "- $patch_name, $patch_source, $patch_args" >> description
				else 
					echo "- $patch_name, [$patch_source](https://gitlab.freedesktop.org/mesa/mesa/-/$patch_source), $patch_args" >> description
				fi
			done
			echo "true" > patched
			echo "" >> description
			echo "_Upstreams / Patches are only applied to the patched version (\_patched.zip)_" >> description
			echo "_If a patch is not present anymore, it's most likely because it got merged, is not needed anymore or was breaking something._" >> description
		fi
	fi
	
	if ! [ -a "$workdir"/"$filename".zip ]; then
		echo -e "$red-Packing failed!$nocolor" && exit 1
	else
		echo -e "$green-All done, you can take your zip from this folder;$nocolor" && echo "$workdir"/
	fi
}

run_all
