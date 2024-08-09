#! /bin/bash
project_path=${PWD}
sudo rm -rf /opt/circleci/
sudo apt update
sudo apt install -y cmake git wget
sudo sed -i 's/Types: deb/Types:deb deb-src/g' /etc/apt/sources.list.d/ubuntu.sources
sudo sed -i 's/Types: deb/Types:deb deb-src/g' /etc/apt/sources.list
sudo dpkg --add-architecture armhf
sudo apt update
sudo apt install -y cbindgen python3-certifi python3-pycparser
git clone --depth=1 https://gitlab.freedesktop.org/mesa/mesa.git
sudo apt install -y zlib1g-dev:armhf libexpat1-dev:armhf  \
		    libdrm-dev:armhf libx11-dev:armhf libxext-dev:armhf libxdamage-dev:armhf  \
	        libxcb-glx0-dev:armhf libx11-xcb-dev:armhf libxcb-dri2-0-dev:armhf libxcb-dri3-dev:armhf \
		    libxcb-present-dev:armhf libxshmfence-dev:armhf libxxf86vm-dev:armhf libxrandr-dev:armhf \
		    libwayland-dev:armhf wayland-protocols:armhf libwayland-egl-backend-dev:armhf \
		    libxcb-shm0-dev:armhf pkg-config:armhf
sudo apt install -y libclang-18-dev libclang-common-18-dev libclang-cpp18-dev \
  libclc-18 libclc-18-dev libllvmspirvlib-18-dev llvm-18 llvm-18-dev llvm-18-linker-tools \
  llvm-18-runtime llvm-18-tools llvm-spirv-18 libpolly-18-dev libpolly-17-dev llvm-18*
sudo apt install -y gcc-14 g++-14 g++-14-arm-linux-gnueabihf gcc-14-arm-linux-gnueabihf clang clang-18
sudo rm /usr/bin/gcc
sudo rm /usr/bin/g++
sudo rm /usr/bin/arm-linux-gnueabihf-g++
sudo rm /usr/bin/arm-linux-gnueabihf-gcc
sudo ln -s /usr/bin/gcc-14 /usr/bin/gcc
sudo ln -s /usr/bin/g++-14 /usr/bin/g++
sudo ln -s /usr/bin/arm-linux-gnueabihf-g++-14 /usr/bin/arm-linux-gnueabihf-g++
sudo ln -s /usr/bin/arm-linux-gnueabihf-gcc-14 /usr/bin/arm-linux-gnueabihf-gcc

echo "------------------------------"
echo "     Install mesa deps"
echo "------------------------------"
sudo apt build-dep -y mesa
echo "------------------------------"
echo "   Install mesa deps OK"
echo "------------------------------"

mkdir -p ~/tmp
cd ~/tmp
wget https://xorg.freedesktop.org/releases/individual/xserver/xorg-server-21.1.13.tar.xz
wget https://xorg.freedesktop.org/archive/individual/proto/xorgproto-2024.1.tar.xz
wget https://xorg.freedesktop.org/releases/individual/xserver/xwayland-24.1.2.tar.xz
tar -xvf xorg-server-21.1.13.tar.xz
cd xorg-server-21.1.13
mkdir b
cd b
sudo apt build-dep -y xorg-server
meson .. -Dxvfb=true -Dglx=true -Dudev_kms=true -Ddri3=true -Ddrm=true
sudo ninja install
#【2】编译xorgproto-2023.2
cd ~/tmp
tar -xvf xorgproto-2024.1.tar.xz
cd xorgproto-2024.1
mkdir b
cd b
meson .. -Dlegacy=true
sudo ninja install
#【3】编译xwayland-23.1.2
cd ~/tmp
tar -xvf xwayland-24.1.2.tar.xz
cd xwayland-24.1.2
mkdir b
cd b
sudo apt build-dep -y xwayland
meson .. -Dxvfb=true -Dglx=true -Ddri3=true -Ddrm=true -Dmitshm=true
sudo ninja install

cd ~/tmp
wget https://dri.freedesktop.org/libdrm/libdrm-2.4.122.tar.xz
tar -xvf libdrm-2.4.122.tar.xz
cd libdrm-2.4.122
rm -rf b
mkdir b
cd b
meson .. -Dfreedreno=enabled -Dfreedreno-kgsl=true -Dudev=true
sudo ninja install
cd ~/tmp
cp -f ${project_path}/files/cross32.txt ~/tmp/libdrm-2.4.122
cd libdrm-2.4.122
rm -rf build32
meson build32 --cross-file=cross32.txt --libdir=lib/arm-linux-gnueabihf -Dfreedreno=enabled -Dfreedreno-kgsl=true -Dudev=true
cd build32
sudo ninja install

echo "------------------------------"
echo "        Create Swap"
echo "------------------------------"
sudo dd if=/dev/zero of=/swapfile bs=1M count=10240
sudo mkswap /swapfile
sudo swapon /swapfile
cd ${project_path}
cp -f ./files/cross32.txt ./mesa/cross32.txt

