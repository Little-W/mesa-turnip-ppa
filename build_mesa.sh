#!/bin/bash

# 记录项目路径
proj_path=$(pwd)
home_path=$(readlink -f ~)

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
    sudo cp -a /usr/local/* ${dest_dir}${install_prefix}

    # 打包为 .deb 文件
    dpkg-deb --build ${dest_dir} ${home_path}/upload/${package_name}-${mesa_version}-${commit_short}.deb
}

create_pkg_package () {
    local dest_dir=$1
    local package_name=$2
    local install_prefix=$3
    
    mkdir -p ${home_path}/upload
    mkdir -p ${dest_dir}/pkg/metadata

    # 创建 `desc` 文件
    cat <<EOF > ${dest_dir}/pkg/metadata/desc
%NAME%
${package_name}
%VERSION%
${mesa_version}-${commit_short}
%ARCH%
$(uname -m)
%DESC%
Mesa 3D graphics library with Turnip and Zink for Adreno GPUs
%DEPENDS%
glibc>=${libc_version}
llvm-libs>=${llvm_libs_version}
EOF

    # 将已安装的文件复制到 pkg 目录结构中
    sudo mkdir -p ${dest_dir}/pkg${install_prefix}
    sudo cp -a /usr/local/* ${dest_dir}/pkg${install_prefix}

    # 打包为 .pkg.tar.gz 文件
    cd ${dest_dir}
    tar -czf ${home_path}/upload/${package_name}-${mesa_version}-${commit_short}.pkg.tar.gz -C pkg .
}

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
CC=clang CXX=clang++ meson b --libdir=lib -Dgallium-drivers=virgl,zink,llvmpipe,freedreno,d3d12 -Dvulkan-drivers=freedreno -Dglx=dri -Dplatforms=x11,wayland -Dbuildtype=release -Dllvm=enabled -Dxlib-lease=enabled -Dgles2=enabled -Dgallium-nine=true -Dgallium-opencl=icd -Degl=enabled -Dfreedreno-kmds=kgsl,msm -Ddri3=enabled -Dgbm=enabled -Dvulkan-beta=true -Dvideo-codecs=all -Dglx-direct=true -Dtools=drm-shim,freedreno -Dgallium-vdpau=enabled -Dopengl=true -Dosmesa=true -Dpower8=enabled -Degl-native-platform=x11 -Dglvnd=enabled -Db_lto=true -Dcpp_args="-Wno-typedef-redefinition -O3" -Dc_args="-Wno-typedef-redefinition -O3"

cd b
ninja
sudo ninja install

# 打包为 .tgz 文件，保留 /usr/local 目录结构
cd ${home_path}
mkdir -p ${home_path}/upload/
tar -czf ${home_path}/upload/mesa-${mesa_version}-${commit_short}-lto-arch.tgz -C / usr/local

# 打包 LTO 版本的 .deb 包
create_deb_package "${home_path}/mesa_deb_lto_root" "mesa-adreno-lto-root-arch" "/"
create_deb_package "${home_path}/mesa_deb_lto_local" "mesa-adreno-lto-local-arch" "/usr/local"

# 打包 LTO 版本的 Arch Linux .pkg.tar.gz 包
create_pkg_package "${home_path}/mesa_pkg_lto_root" "mesa-adreno-lto-root-arch" "/"
create_pkg_package "${home_path}/mesa_pkg_lto_local" "mesa-adreno-lto-local-arch" "/usr/local"