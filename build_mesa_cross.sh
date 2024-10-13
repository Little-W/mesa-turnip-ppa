#!/usr/bin/env bash
set -e
# 记录项目路径
proj_path=$(pwd)
home_path=$(readlink -f ~)

if [ -n "$1" ]; then
    UPLOAD_DIR=$1
else
    UPLOAD_DIR=/tmp/upload
fi

if [ "${ARCHLINUX}" = "1" ]; then
    LIBDIR=" --libdir=lib"
    SUFFIX="-arch"
else
    LIBDIR=" --libdir=lib/aarch64-linux-gnu"
    SUFFIX=''
fi

BUILD_DIR=${UPLOAD_DIR}/local
sudo mkdir -p ${UPLOAD_DIR}
sudo chmod -R 777 ${UPLOAD_DIR}
rm -rf ${BUILD_DIR}
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
          --proc /proc --tmpfs /home --tmpfs /run \
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
          --setenv TMPDIR "${proj_path}" \
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

cd ${proj_path}/mesa

commit_short=$(git rev-parse --short HEAD)
commit=$(git rev-parse HEAD)
mesa_version=$(cat VERSION | xargs)
version=$(awk -F'COMPLETE VK_MAKE_API_VERSION(|)' '{print $2}' <<< $(cat include/vulkan/vulkan_core.h) | xargs)
major=$(echo $version | cut -d "," -f 2 | xargs)
minor=$(echo $version | cut -d "," -f 3 | xargs)
patch=$(awk -F'VK_HEADER_VERSION |\n#define' '{print $2}' <<< $(cat include/vulkan/vulkan_core.h) | xargs)
vulkan_version="$major.$minor.$patch"

raw_libc_version=$(_bwrap dpkg-query -W -f='${Version}' libc6)
libc_version=$(echo "$raw_libc_version" | awk -F'-' '{print $1}' | tr -d '\n')
raw_libllvm_packages=$(_bwrap dpkg -l | grep '^ii' | grep -E 'libllvm[0-9]+')
libllvm_package=$(echo "$raw_libllvm_packages" | awk '{print $2}' | sort -V | tail -n 1 | cut -d ':' -f 1)

export CPPFLAGS="-D_FORTIFY_SOURCE=0"

export CFLAGS_BASE="-O3 -march=armv8.2-a+crc+simd+crypto -mtune=cortex-a77 -fno-math-errno -fno-trapping-math -funroll-loops -fno-semantic-interposition -fcf-protection=none -mharden-sls=none -fomit-frame-pointer"


export CFLAGS_LLVM="-Wno-typedef-redefinition -mllvm -extra-vectorizer-passes -mllvm -enable-cond-stores-vec -mllvm -enable-loop-distribute -mllvm -enable-unroll-and-jam -mllvm -enable-loop-flatten -mllvm -interleave-small-loop-scalar-reduction"

export LDFLAGS_BASE="-O3"

export LDFLAGS_LLVM="-fuse-ld=lld"

if [ "${CLANG}" = "1" ]; then
    export CFLAGS="${CFLAGS_BASE} ${CFLAGS_LLVM}"
    export LDFLAGS="${LDFLAGS_BASE} ${LDFLAGS_LLVM}"
    CROSSFILE_SUFFIX="_clang"
    BUILDFILE_SUFFIX="-clang"
else
    export CFLAGS="${CFLAGS_BASE}"
    export LDFLAGS="${LDFLAGS_BASE}"
fi

export CXXFLAGS="${CFLAGS}"
export CCLDFLAGS="${LDFLAGS}"
export CXXLDFLAGS="${LDFLAGS}"

if [[ "$(printf '%s\n' "$mesa_version" "24.2" | sort -V | head -n1)" == "24.2" ]]; then
    SOFTRENDERER="llvmpipe"
else
    SOFTRENDERER="swrast"
fi

rm -rf b
# 编译 64 位 turnip + zink + 解码库 + 镓九
_bwrap meson b --cross-file=cross64${CROSSFILE_SUFFIX}.txt ${LIBDIR} -Dbuildtype=release -Dplatforms=x11,wayland -Ddri3=enabled -Dgallium-drivers=virgl,zink,${SOFTRENDERER},freedreno -Dvulkan-drivers=freedreno -Dfreedreno-kmds=msm,kgsl -Dimagination-srv=true -Dvulkan-layers=device-select -Dgles2=enabled -Dopengl=true -Dgbm=enabled -Dglx=dri -Dosmesa=true -Dpower8=enabled -Dxlib-lease=enabled -Dvulkan-beta=true -Dvideo-codecs=all -Degl-native-platform=x11 -Dglx-direct=true -Degl=enabled -Dglvnd=enabled -Db_lto=true -Dcpp_args="${CXXFLAGS} -Wno-narrowing" -Dc_args="${CFLAGS} -Wno-narrowing -Wno-incompatible-pointer-types"

cd b
_bwrap ninja
_bwrap ninja install

# 打包为 .tgz 文件，保留 /usr/local 目录结构
cd ${home_path}
tar -czf ${UPLOAD_DIR}/mesa-${mesa_version}-${commit_short}${SUFFIX}${BUILDFILE_SUFFIX}.tgz -C / ${BUILD_DIR}

# 打包 LTO 版本的 .deb 包
create_deb_package "${home_path}/mesa_deb_root" "mesa-adreno-root${SUFFIX}${BUILDFILE_SUFFIX}" "/"
create_deb_package "${home_path}/mesa_deb_local" "mesa-adreno-local${SUFFIX}${BUILDFILE_SUFFIX}" "/usr/local"
