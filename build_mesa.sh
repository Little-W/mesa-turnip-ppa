#! /bin/bash

home_path=$(readlink -f ~)
cd ./mesa
cp -r /usr/include/drm/* /usr/include

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

# 应用turnip-patches目录下的所有补丁
for patch in ../turnip-patches/*.patch; do
    patch -p1 < "$patch"
done

# 清理 /usr/local
rm -rf /usr/local/*

# 编译 64 位 turnip + zink + 解码库 + 镓九
CC=clang CXX=clang++ meson b -Dgallium-drivers=virgl,zink,llvmpipe,d3d12 -Dvulkan-drivers=freedreno,swrast -Dglx=dri -Dplatforms=x11,wayland -Dbuildtype=release -Dllvm=enabled -Dxlib-lease=enabled -Dgles2=enabled -Dgallium-nine=true -Dgallium-opencl=icd -Degl=enabled -Dfreedreno-kmds=kgsl,msm -Ddri3=enabled  -Dvulkan-beta=true -Dvideo-codecs=vc1dec,h264dec,h264enc,h265dec,h265enc -Dglx-direct=true -Dtools=drm-shim,freedreno -Dgallium-vdpau=enabled -Dopengl=true -Dosmesa=true -Dpower8=enabled -Degl-native-platform=drm -Db_lto=true -Dcpp_args="-Wno-typedef-redefinition -flto -O3" -Dc_args="-Wno-typedef-redefinition -flto -O3"

cd b
ninja

# 安装 64 位构建
ninja install

# 编译 32 位 turnip + zink
cd ..
meson build32 --cross-file=cross32.txt --libdir=lib/arm-linux-gnueabihf -Dgallium-drivers=virgl,zink,d3d12 -Dvulkan-drivers=freedreno -Dglx=dri -Dplatforms=x11,wayland -Dbuildtype=release -Dxlib-lease=enabled -Dgles2=enabled -Degl-native-platform=drm -Degl=enabled -Dfreedreno-kmds=kgsl,msm -Ddri3=enabled -Dvulkan-beta=true -Dvideo-codecs=vc1dec,h264dec,h264enc,h265dec,h265enc -Dglx-direct=true -Dtools=drm-shim,freedreno -Dopengl=true -Dpower8=enabled -Db_lto=true -Dcpp_args="-O3 -flto" -Dc_args="-O3 -flto"

cd build32
ninja

# 安装 32 位构建
ninja install

# 打包为 .tgz 文件，保留 /usr/local 目录结构
cd ${home_path}
mkdir -p ${home_path}/upload/
tar -czf ${home_path}/upload/mesa-${mesa_version}-${commit_short}.tgz -C / usr/local

# 创建 DEBIAN 控制文件并打包为 .deb 文件
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
    mkdir -p ${dest_dir}${install_prefix}
    cp -a /usr/local/* ${dest_dir}${install_prefix}

    # 打包为 .deb 文件
    dpkg-deb --build ${dest_dir} ${home_path}/upload/${package_name}-${mesa_version}-${commit_short}.deb
}

# 创建两个版本的 deb 包
create_deb_package "${home_path}/mesa_deb_root" "mesa-adreno-root" "/"
create_deb_package "${home_path}/mesa_deb_local" "mesa-adreno-local" "/usr/local"
