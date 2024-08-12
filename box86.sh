#!/bin/bash

home_path=$(readlink -f ~)
sudo rm -rf /usr/local/*

# 创建工作目录
mkdir -p ~/env_workspace
cd ~/env_workspace

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
mkdir -p ${home_path}/upload/

# 函数: 打包成 .pkg.tar.gz 文件
create_pkg_package () {
    local dest_dir=$1
    local package_name=$2
    local install_prefix=$3
    local version=$4
    local arch=$5
    local depends_name=$6

    mkdir -p ${dest_dir}/pkg/metadata

    # 创建 `desc` 文件
    cat <<EOF > ${dest_dir}/pkg/metadata/desc
%NAME%
${package_name}
%VERSION%
${version}
%ARCH%
${arch}
%DESC%
${package_name} - A dynamic recompiler for running x86 applications on ARM platforms.
%DEPENDS%
${depends_name}>=${libc_version}
EOF

    # 将已安装的文件复制到 pkg 目录结构中
    sudo mkdir -p ${dest_dir}/pkg${install_prefix}
    sudo cp -a ${DESTDIR}/* ${dest_dir}/pkg${install_prefix}

    # 打包为 .pkg.tar.gz 文件
    cd ${dest_dir}
    tar -czf ${home_path}/upload/${package_name}-${version}-${arch}.pkg.tar.gz -C pkg .
}

# 构建和安装 box86 (armv7h)
cd box86
mkdir build
cd build
cmake .. -DARM64=1 -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBAD_SIGNAL=ON -DARM_DYNAREC=ON -Dmfpu=neon-fp-armv8 -Dmfloat-abi=hard -DSD845=ON
make -j8

# 安装到临时目录
DESTDIR=${home_path}/box86_install
make install DESTDIR=${DESTDIR}

# 安装到默认目录（/usr/local）
sudo make install

# 替换临时目录中的二进制文件
sudo cp /usr/local/bin/box86 ${DESTDIR}/usr/local/bin/

# 打包成 .tgz 文件
cd ${home_path}
tar -czf ${home_path}/upload/box86-${box86_tag}-${box86_commit}.tgz -C ${DESTDIR} .

# 打包成 .deb 文件
deb_version=$(echo ${box86_tag} | sed 's/^v//')
cd ${home_path}
mkdir -p ${DESTDIR}/DEBIAN
cat <<EOF > ${DESTDIR}/DEBIAN/control
Package: box86
Version: ${deb_version}-${box86_commit}
Architecture: armhf
Maintainer: Yusen <1405481963@qq.com>
Depends: libc6 (>= ${libc_version})
Description: Box86 - A dynamic recompiler for running x86 applications on ARM platforms.
EOF
dpkg-deb --build ${DESTDIR} ${home_path}/upload/box86-${box86_tag}-${box86_commit}.deb

# 打包成 .pkg.tar.gz 文件 (armv7h for Arch Linux)
create_pkg_package "${home_path}/box86_pkg" "box86" "/" "${deb_version}-${box86_commit}" "armv7h" "glibc"

# 清理临时目录
rm -rf ${DESTDIR}

# 构建和安装 box64 (aarch64)
cd ~/env_workspace/box64
mkdir build
cd build
cmake .. -DARM_DYNAREC=1 -DCMAKE_BUILD_TYPE=RelWithDebInfo -DBAD_SIGNAL=ON -DARM_DYNAREC=ON -Dmfpu=neon-fp-armv8 -Dmfloat-abi=hard -DSD845=ON
make -j8

# 安装到临时目录
DESTDIR=${home_path}/box64_install
make install DESTDIR=${DESTDIR}

# 安装到默认目录（/usr/local）
sudo make install

# 替换临时目录中的二进制文件
sudo cp /usr/local/bin/box64 ${DESTDIR}/usr/local/bin/

# 打包成 .tgz 文件
cd ${home_path}
tar -czf ${home_path}/upload/box64-${box64_tag}-${box64_commit}.tgz -C ${DESTDIR} .

# 打包成 .deb 文件
deb_version=$(echo ${box64_tag} | sed 's/^v//')
cd ${home_path}
mkdir -p ${DESTDIR}/DEBIAN
cat <<EOF > ${DESTDIR}/DEBIAN/control
Package: box64
Version: ${deb_version}-${box64_commit}
Architecture: arm64
Maintainer: Yusen <1405481963@qq.com>
Depends: libc6 (>= ${libc_version})
Description: Box64 - A dynamic recompiler for running x86_64 applications on ARM64 platforms.
EOF
dpkg-deb --build ${DESTDIR} ${home_path}/upload/box64-${box64_tag}-${box64_commit}.deb

# 打包成 .pkg.tar.gz 文件 (aarch64 for Arch Linux)
create_pkg_package "${home_path}/box64_pkg" "box64" "/" "${deb_version}-${box64_commit}" "aarch64" "glibc"

# 清理临时目录
rm -rf ${DESTDIR}
