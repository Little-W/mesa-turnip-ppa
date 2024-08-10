#! /bin/bash

# 使用readlink -f将~转换为绝对路径
home_path=$(readlink -f ~)
cd ./mesa
sudo cp -r /usr/include/drm/* /usr/include \

commit_short=$(git rev-parse --short HEAD)
commit=$(git rev-parse HEAD)
mesa_version=$(cat VERSION | xargs)
version=$(awk -F'COMPLETE VK_MAKE_API_VERSION(|)' '{print $2}' <<< $(cat include/vulkan/vulkan_core.h) | xargs)
major=$(echo $version | cut -d "," -f 2 | xargs)
minor=$(echo $version | cut -d "," -f 3 | xargs)
patch=$(awk -F'VK_HEADER_VERSION |\n#define' '{print $2}' <<< $(cat include/vulkan/vulkan_core.h) | xargs)
vulkan_version="$major.$minor.$patch"

patch -p1 < ../turnip-patches/fix-for-anon-file.patch
patch -p1 < ../turnip-patches/fix-for-getprogname.patch
patch -p1 < ../turnip-patches/zink_fixes.patch
patch -p1 < ../turnip-patches/dri3.patch

#编译64位turnip+zink+解码库+镓九

CC=clang CXX=clang++ meson b -Dgallium-drivers=virgl,zink,llvmpipe,d3d12 -Dvulkan-drivers=freedreno,swrast -Dglx=dri -Dplatforms=x11,wayland -Dbuildtype=release -Dllvm=enabled -Dxlib-lease=enabled -Dgles2=enabled -Dgallium-nine=true -Dgallium-opencl=icd -Degl=enabled -Dfreedreno-kmds=kgsl,msm -Ddri3=enabled  -Dvulkan-beta=true -Dvideo-codecs=vc1dec,h264dec,h264enc,h265dec,h265enc -Dglx-direct=true -Dtools=drm-shim,freedreno -Dgallium-vdpau=enabled -Dopengl=true -Dosmesa=true -Dpower8=enabled -Degl-native-platform=drm -Db_lto=true -Dc_args="-Wno-typedef-redefinition -flto -O3"

cd b
ninja 
cd ..
#编译32位turnip + zink
#cd /tmp/mesa
meson build32 --cross-file=cross32.txt --libdir=lib/arm-linux-gnueabihf -Dgallium-drivers=virgl,zink,d3d12 -Dvulkan-drivers=freedreno -Dglx=dri -Dplatforms=x11,wayland -Dbuildtype=release -Dxlib-lease=enabled -Dgles2=enabled -Degl-native-platform=drm -Degl=enabled -Dfreedreno-kmds=kgsl,msm -Ddri3=enabled -Dvulkan-beta=true -Dvideo-codecs=vc1dec,h264dec,h264enc,h265dec,h265enc -Dglx-direct=true -Dtools=drm-shim,freedreno -Dopengl=true -Dpower8=enabled -Db_lto=true -Dc_args="-flto -O3"

cd build32
ninja
sudo rm -rf /usr/local
sudo mkdir /usr/local
sudo ninja install
cd ..
cd b
sudo ninja install
mkdir -p ${home_path}/upload/
tar -czf ${home_path}/upload/${mesa_version}-${commit_short}.tgz /usr/local
