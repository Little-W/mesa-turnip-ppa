#! /bin/bash
dd if=/dev/zero of=/swapfile bs=1M count=40960
mkswap /swapfile
swapon /swapfile
apt build-dep -y mesa
apt install -y cmake git
apt install -y zlib1g-dev:armhf libexpat1-dev:armhf  \
		    libdrm-dev:armhf libx11-dev:armhf libxext-dev:armhf libxdamage-dev:armhf  \
	        libxcb-glx0-dev:armhf libx11-xcb-dev:armhf libxcb-dri2-0-dev:armhf libxcb-dri3-dev:armhf \
		    libxcb-present-dev:armhf libxshmfence-dev:armhf libxxf86vm-dev:armhf libxrandr-dev:armhf \
		    libwayland-dev:armhf wayland-protocols:armhf libwayland-egl-backend-dev:armhf \
		    libxcb-shm0-dev:armhf pkg-config:armhf
apt install -y clang

cp -r /usr/include/drm/* /usr/include \

patch -p1 < ../turnip-patches/fix-for-anon-file.patch
patch -p1 < ../turnip-patches/fix-for-getprogname.patch
patch -p1 < ../turnip-patches/zink_fixes.patch
patch -p1 < ../turnip-patches/dri3.patch

#编译64位turnip+zink+解码库+镓九
rm -rf b

CC=clang CXX=clang++ meson b -Dgallium-drivers=virgl,zink,softpipe,llvmpipe,d3d12 -Dvulkan-drivers=freedreno,swrast -Dglx=dri -Dplatforms=x11,wayland -Dbuildtype=release -Dllvm=enabled -Dxlib-lease=enabled -Dgles2=enabled -Dgallium-nine=true -Dgallium-opencl=icd -Degl=enabled -Dfreedreno-kmds=kgsl,msm -Ddri3=enabled  -Dvulkan-beta=true -Dvideo-codecs=vc1dec,h264dec,h264enc,h265dec,h265enc -Dglx-direct=true -Dtools=drm-shim,freedreno -Dgallium-vdpau=enabled -Dopengl=true -Dosmesa=true -Dpower8=enabled -Degl-native-platform=drm -Dc_args="-Wno-typedef-redefinition" -Db_lto=true --prefix=/root/build_out/usr/local

cd b
ninja install
cd ..
#编译32位turnip + zink
#cd /tmp/mesa
rm -rf build32
meson build32 --cross-file=cross.txt --libdir=lib/arm-linux-gnueabihf -Dgallium-drivers=virgl,zink,d3d12 -Dvulkan-drivers=freedreno -Dglx=dri -Dplatforms=x11,wayland -Dbuildtype=release -Dxlib-lease=enabled -Dgles2=enabled -Degl-native-platform=drm -Degl=enabled -Dfreedreno-kmds=kgsl,msm -Ddri3=enabled -Dvulkan-beta=true -Dvideo-codecs=vc1dec,h264dec,h264enc,h265dec,h265enc -Dglx-direct=true -Dtools=drm-shim,freedreno -Dopengl=true -Dpower8=enabled -Db_lto=true --prefix=/root/build_out/usr/local

cd build32
ninja install
