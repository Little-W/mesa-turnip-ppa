#!/usr/bin/env bash

# 记录项目路径
proj_path=$(pwd)
home_path=$(readlink -f ~)

if [ -n "$1" ]; then
    UPLOAD_DIR=$1
else
    UPLOAD_DIR=/tmp/upload
fi

BUILD_DIR=${UPLOAD_DIR}/local
sudo mkdir -p ${UPLOAD_DIR}
sudo chmod -R 777 ${UPLOAD_DIR}

mkdir -p ${BUILD_DIR}

## Flags changes in order to use ccache..
if [ "$USE_CCACHE" = "true" ]; then
	export CC="ccache ${CC}"
	export CXX="ccache ${CXX}"

	if [ -z "${XDG_CACHE_HOME}" ]; then
		export XDG_CACHE_HOME="${home_path}"/.cache
	fi

	mkdir -p "${XDG_CACHE_HOME}"/ccache
	mkdir -p "${home_path}"/.ccache

fi

## ------------------------------------------------------------
## 						BOOTSTRAPS SETUP
## ------------------------------------------------------------

# Change these paths to where your Ubuntu bootstraps reside
export BOOTSTRAP_PATH=$(echo /opt/chroots/*_chroot)
sudo mkdir -p ${BOOTSTRAP_PATH}/${proj_path}

_bwrap () {
    bwrap --ro-bind "${BOOTSTRAP_PATH}" / --dev /dev --ro-bind /sys /sys \
          --proc /proc --tmpfs /home --tmpfs /run --tmpfs /var \
          --tmpfs /mnt --tmpfs /media --bind "${BUILD_DIR}" /usr/local \
          --bind "${proj_path}" "${proj_path}" \
          --ro-bind /proc/sys/fs/binfmt_misc /proc/sys/fs/binfmt_misc \
          --bind-try "${XDG_CACHE_HOME}"/ccache "${XDG_CACHE_HOME}"/ccache \
          --bind-try "${home_path}"/.ccache "${home_path}"/.ccache \
          --setenv PATH "/bin:/sbin:/usr/bin:/usr/sbin" \
          --setenv PKG_CONFIG_PATH "/tmp/arm64-deps/usr/lib/aarch64-linux-gnu/pkgconfig:/tmp/arm64-deps/usr/share/pkgconfig" \
          --setenv CMAKE_PREFIX_PATH "/tmp/arm64-deps/usr:/tmp/arm64-deps/usr/lib/aarch64-linux-gnu" \
          --setenv LD_LIBRARY_PATH "/tmp/arm64-deps/usr/lib/aarch64-linux-gnu:/lib/aarch64-linux-gnu:/usr/lib/aarch64-linux-gnu" \
          --setenv LC_ALL en_US.UTF-8 \
          --setenv LANGUAGE en_US.UTF-8 \
          --chdir "$(pwd)" \
          "$@"
}

if [ ! -d "${BOOTSTRAP_PATH}" ] ; then
	clear
	echo "Ubuntu Bootstrap is required for compilation!"
	exit 1
fi


create_deb_package () {
    local dest_dir=$1
    local package_name=$2
    local install_prefix=$3

    mkdir -p ${dest_dir}/DEBIAN
    cat <<EOF > ${dest_dir}/DEBIAN/control
Package: ${package_name}
Version: ${mesa_version}-${commit_short}
Architecture: arm64
Maintainer: Yusen <1405481963@qq.com>
Depends: libc6 (>= ${libc_version}), ${libllvm_package}
Description: Mesa 3D graphics library with Turnip and Zink for Adreno GPUs
EOF

    # 将已安装的文件复制到 deb 目录结构中
    sudo mkdir -p ${dest_dir}${install_prefix}
    sudo cp -a ${BUILD_DIR}/* ${dest_dir}${install_prefix}

    # 打包为 .deb 文件
    dpkg-deb --build ${dest_dir} ${UPLOAD_DIR}/${package_name}-${mesa_version}-${commit_short}.deb
}

cd ${proj_path}
# 克隆Mesa仓库
git clone --depth=1 https://gitlab.freedesktop.org/mesa/mesa.git -b 24.1

echo "---------------------------------------------------------"
echo "     Start: Copy cross compile configuration"
echo "---------------------------------------------------------"
cp -f ./files/cross64.txt ./mesa/cross64.txt
echo "---------------------------------------------------------"
echo "      End: Copy cross compile configuration"
echo "---------------------------------------------------------"

cd ${proj_path}/mesa
sudo cp -r /usr/include/drm/* /usr/include

commit_short=$(git rev-parse --short HEAD)
commit=$(git rev-parse HEAD)
mesa_version=$(cat VERSION | xargs)
version=$(awk -F'COMPLETE VK_MAKE_API_VERSION(|)' '{print $2}' <<< $(cat include/vulkan/vulkan_core.h) | xargs)
major=$(echo $version | cut -d "," -f 2 | xargs)
minor=$(echo $version | cut -d "," -f 3 | xargs)
patch=$(awk -F'VK_HEADER_VERSION |\n#define' '{print $2}' <<< $(cat include/vulkan/vulkan_core.h) | xargs)
vulkan_version="$major.$minor.$patch"

# 获取关键依赖项的版本
libc_version=$(dpkg-query -W -f='${Version}' libc6 | awk -F'-' '{print $1}' | tr -d '\n')
libllvm_package=$(dpkg -l | grep '^ii' | grep -E 'libllvm[0-9]' | awk '{print $2}' | sort -V | tail -n 1 | cut -d ':' -f 1)
llvm_libs_version=$(dpkg-query -W -f='${Version}' ${libllvm_package} | awk -F'-' '{print $1}' | tr -d '\n')

# 应用turnip-patches目录下的所有补丁
for patch in ../turnip-patches/*.patch; do
    patch -p1 < "$patch"
done

# 清理 /usr/local
sudo rm -rf /usr/local/*

# 编译 64 位 turnip + zink + 解码库 + 镓九
_bwrap meson b --cross-file=cross64.txt -Dgallium-drivers=virgl,zink,swrast,freedreno,d3d12 -Dvulkan-drivers=freedreno -Dglx=dri -Dplatforms=x11,wayland -Dbuildtype=release -Dllvm=enabled -Dxlib-lease=enabled -Dgles2=enabled -Dgallium-nine=true -Dgallium-opencl=icd -Degl=enabled -Dfreedreno-kmds=kgsl,msm -Ddri3=enabled -Dgbm=enabled -Dvulkan-beta=true -Dvideo-codecs=all -Dglx-direct=true -Dtools=drm-shim,freedreno -Dgallium-vdpau=enabled -Dopengl=true -Dosmesa=true -Dpower8=enabled -Degl-native-platform=x11 -Dglvnd=enabled -Db_lto=true -Dcpp_args="-Wno-narrowing -O3 -march=armv8.2-a+crc+simd+crypto -mtune=cortex-a76.cortex-a55" -Dc_args="-Wno-narrowing -Wno-incompatible-pointer-types -O3 -march=armv8.2-a+crc+simd+crypto -mtune=cortex-a76.cortex-a55"

cd b
_bwrap ninja
_bwrap ninja install

# 打包为 .tgz 文件，保留 /usr/local 目录结构
cd ${home_path}
tar -czf ${UPLOAD_DIR}/mesa-${mesa_version}-${commit_short}-lto.tgz -C / ${BUILD_DIR}

# 打包 LTO 版本的 .deb 包
create_deb_package "${home_path}/mesa_deb_lto_root" "mesa-adreno-lto-root" "/"
create_deb_package "${home_path}/mesa_deb_lto_local" "mesa-adreno-lto-local" "/usr/local"
