#!/bin/bash

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

# 创建工作目录
mkdir -p ${proj_path}/env_workspace
cd ${proj_path}/env_workspace

# 删除已有的 box86 和 box64
rm -rf box86
rm -rf box64

# 克隆最新的 box86 和 box64 源代码
git clone --depth 1 --single-branch https://github.com/ptitSeb/box86.git
cd box86
git fetch --tags
box86_tag=$(git describe --tags $(git rev-list --tags --max-count=1))
box86_commit=$(git rev-parse --short HEAD)
cd ..

git clone --depth 1 --single-branch https://github.com/ptitSeb/box64.git
cd box64
git fetch --tags
box64_tag=$(git describe --tags $(git rev-list --tags --max-count=1))
box64_commit=$(git rev-parse --short HEAD)
cd ..

# 获取libc6版本
libc_version=$(dpkg-query -W -f='${Version}' libc6 | awk -F'-' '{print $1}' | tr -d '\n')

# 准备上传目录
mkdir -p ${UPLOAD_DIR}/

# 设置 LTO 编译器和 LLVM 链接器标志，启用 big.LITTLE 优化，并配置汇编标志
CFLAGS="-pipe -O3 -march=armv8.2-a+crc+simd+crypto -mtune=cortex-a76.cortex-a55 -ffast-math"
LDFLAGS="-O2"
ASMFLAGS="-pipe -march=armv8.2-a+crc+simd+crypto -mtune=cortex-a76.cortex-a55"

# 构建和安装 box86 (armv7h)
cd box86
mkdir build
cd build

_bwrap cmake .. -DARM_DYNAREC=ON \
-DCMAKE_BUILD_TYPE=RelWithDebInfo \
-DCMAKE_C_COMPILER=/usr/bin/arm-linux-gnueabihf-gcc \
-DCMAKE_CXX_COMPILER=/usr/bin/arm-linux-gnueabihf-g++ \
-DCMAKE_AR=/usr/bin/arm-linux-gnueabihf-gcc-ar \
-DCMAKE_STRIP=/usr/bin/arm-linux-gnueabihf-strip \
-DCMAKE_SYSTEM_PROCESSOR=armv7-a \
-DCMAKE_C_FLAGS="$CFLAGS" \
-DCMAKE_CXX_FLAGS="$CFLAGS" \
-DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
-DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS" \
-DCMAKE_ASM_FLAGS="$ASMFLAGS"

_bwrap make -j8

# 安装到临时目录
DESTDIR=${proj_path}/box86_install
_bwrap make install DESTDIR=${DESTDIR}

# 安装到默认目录（/usr/local）
_bwrap sudo make install

# 替换临时目录中的二进制文件
_bwrap sudo cp /usr/local/bin/box86 ${DESTDIR}/usr/local/bin/

# 打包成 .tgz 文件
cd ${UPLOAD_DIR}
tar -czf box86-${box86_tag}-${box86_commit}.tgz -C ${DESTDIR} .

# 打包成 .deb 文件
deb_version=$(echo ${box86_tag} | sed 's/^v//')
cd ${UPLOAD_DIR}
mkdir -p ${DESTDIR}/DEBIAN
cat <<EOF > ${DESTDIR}/DEBIAN/control
Package: box86
Version: ${deb_version}-${box86_commit}
Architecture: armhf
Maintainer: Yusen <1405481963@qq.com>
Depends: libc6 (>= ${libc_version})
Description: Box86 - A dynamic recompiler for running x86 applications on ARM platforms.
EOF
dpkg-deb --build ${DESTDIR} box86-${box86_tag}-${box86_commit}.deb

# 清理临时目录
rm -rf ${DESTDIR}

# 构建和安装 box64 (aarch64)
cd ${proj_path}/env_workspace/box64
mkdir build
cd build

_bwrap cmake .. -DARM_DYNAREC=ON \
-DCMAKE_BUILD_TYPE=RelWithDebInfo \
-DCMAKE_C_COMPILER=/usr/bin/aarch64-linux-gnu-gcc \
-DCMAKE_CXX_COMPILER=/usr/bin/aarch64-linux-gnu-g++ \
-DCMAKE_AR=/usr/bin/aarch64-linux-gnu-gcc-ar \
-DCMAKE_STRIP=/usr/bin/aarch64-linux-gnu-strip \
-DCMAKE_SYSTEM_PROCESSOR=aarch64 \
-DCMAKE_C_FLAGS="$CFLAGS" \
-DCMAKE_CXX_FLAGS="$CFLAGS" \
-DCMAKE_EXE_LINKER_FLAGS="$LDFLAGS" \
-DCMAKE_SHARED_LINKER_FLAGS="$LDFLAGS" \
-DCMAKE_ASM_FLAGS="$ASMFLAGS"

_bwrap make -j8

# 安装到临时目录
DESTDIR=${proj_path}/box64_install
_bwrap make install DESTDIR=${DESTDIR}

# 安装到默认目录（/usr/local）
_bwrap sudo make install

# 替换临时目录中的二进制文件
_bwrap sudo cp /usr/local/bin/box64 ${DESTDIR}/usr/local/bin/

# 打包成 .tgz 文件
cd ${UPLOAD_DIR}
tar -czf box64-${box64_tag}-${box64_commit}.tgz -C ${DESTDIR} .

# 打包成 .deb 文件
deb_version=$(echo ${box64_tag} | sed 's/^v//')
cd ${UPLOAD_DIR}

mkdir -p ${DESTDIR}/DEBIAN
cat <<EOF > ${DESTDIR}/DEBIAN/control
Package: box64
Version: ${deb_version}-${box64_commit}
Architecture: arm64
Maintainer: Yusen <1405481963@qq.com>
Depends: libc6 (>= ${libc_version})
Description: Box64 - A dynamic recompiler for running x86_64 applications on ARM64 platforms.
EOF
dpkg-deb --build ${DESTDIR} box64-${box64_tag}-${box64_commit}.deb

# 清理临时目录
rm -rf ${DESTDIR}