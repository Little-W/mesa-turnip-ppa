#! /bin/bash
project_path=${PWD}

echo "---------------------------------------------------------"
echo "         Start: Clean up and initial setup"
echo "---------------------------------------------------------"
apt update
apt install -y cmake git wget
sed -i 's/Types: deb/Types:deb deb-src/g' /etc/apt/sources.list.d/ubuntu.sources
dpkg --add-architecture armhf
apt update
apt install -y cbindgen python3-certifi python3-pycparser
echo "---------------------------------------------------------"
echo "         End: Clean up and initial setup"
echo "---------------------------------------------------------"

echo "---------------------------------------------------------"
echo "         Start: Install mesa dependencies"
echo "---------------------------------------------------------"
apt build-dep -y mesa
apt install -y libstdc++6:armhf mesa*:armhf
apt install -y vulkan* *-mesa-* mesa*-* sdl*
apt install -y zlib1g-dev:armhf libexpat1-dev:armhf  \
		    libdrm-dev:armhf libx11-dev:armhf libxext-dev:armhf libxdamage-dev:armhf  \
	        libxcb-glx0-dev:armhf libx11-xcb-dev:armhf libxcb-dri2-0-dev:armhf libxcb-dri3-dev:armhf \
		    libxcb-present-dev:armhf libxshmfence-dev:armhf libxxf86vm-dev:armhf libxrandr-dev:armhf \
		    libwayland-dev:armhf wayland-protocols:armhf libwayland-egl-backend-dev:armhf \
		    libxcb-shm0-dev:armhf pkg-config:armhf
echo "---------------------------------------------------------"
echo "         End: Install mesa dependencies"
echo "---------------------------------------------------------"

echo "---------------------------------------------------------"
echo "            Start: Configure compilers"
echo "---------------------------------------------------------"
apt remove -y llvm-17 llvm-17-dev llvm-17-tools
apt autoremove -y
apt install -y libclang-18-dev libclang-common-18-dev libclang-cpp18-dev \
  libclc-18 libclc-18-dev libllvmspirvlib-18-dev llvm-18 llvm-18-dev llvm-18-linker-tools \
  llvm-18-runtime llvm-18-tools llvm-spirv-18 libpolly-18-dev llvm-18*
apt install -y gcc-14 g++-14 g++-14-arm-linux-gnueabihf gcc-14-arm-linux-gnueabihf clang clang-18
rm /usr/bin/gcc
rm /usr/bin/g++
rm /usr/bin/arm-linux-gnueabihf-g++
rm /usr/bin/arm-linux-gnueabihf-gcc
rm /usr/bin/llvm-config
ln -s /usr/bin/gcc-14 /usr/bin/gcc
ln -s /usr/bin/g++-14 /usr/bin/g++
ln -s /usr/bin/arm-linux-gnueabihf-g++-14 /usr/bin/arm-linux-gnueabihf-g++
ln -s /usr/bin/arm-linux-gnueabihf-gcc-14 /usr/bin/arm-linux-gnueabihf-gcc
ln -s /usr/bin/llvm-config-18 /usr/bin/llvm-config
echo "---------------------------------------------------------"
echo "            End: Configure compilers"
echo "---------------------------------------------------------"

cd ${project_path}
cp -f ./files/cross32.txt ./mesa/cross32.txt
