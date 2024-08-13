#!/bin/bash

home_path=$(readlink -f ~)
sudo rm -rf /usr/local/*

# 创建工作目录
mkdir -p ~/env_workspace
cd ~/env_workspace

# 克隆最新的 box64 源代码
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

# 打包成 .pkg.tar.gz 文件 (aarch64 for Arch Linux)
create_pkg_package "${home_path}/box64_pkg" "box64" "/" "${deb_version}-${box64_commit}" "aarch64" "glibc"
