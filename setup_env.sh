#! /bin/bash

project_path=${PWD}

echo "---------------------------------------------------------"
echo "         Start: Clean up and initial setup"
echo "---------------------------------------------------------"
sudo rm -rf /opt/circleci/
sudo apt update
sudo apt install -y cmake git wget
sudo sed -i 's/Types: deb/Types:deb deb-src/g' /etc/apt/sources.list.d/ubuntu.sources
sudo dpkg --add-architecture armhf
sudo apt update
sudo apt install -y cbindgen python3-certifi python3-pycparser
git clone --depth=1 https://gitlab.freedesktop.org/mesa/mesa.git
echo "---------------------------------------------------------"
echo "         End: Clean up and initial setup"
echo "---------------------------------------------------------"

echo "---------------------------------------------------------"
echo "         Start: Install mesa dependencies"
echo "---------------------------------------------------------"
sudo apt build-dep -y mesa
sudo apt install -y libstdc++6:armhf mesa*:armhf
sudo apt install -y vulkan* *-mesa-* mesa*-* sdl*
sudo apt install -y zlib1g-dev:armhf libexpat1-dev:armhf  \
		    libdrm-dev:armhf libx11-dev:armhf libxext-dev:armhf libxdamage-dev:armhf  \
	        libxcb-glx0-dev:armhf libx11-xcb-dev:armhf libxcb-dri2-0-dev:armhf libxcb-dri3-dev:armhf \
		    libxcb-present-dev:armhf libxshmfence-dev:armhf libxxf86vm-dev:armhf libxrandr-dev:armhf \
		    libwayland-dev:armhf wayland-protocols:armhf libwayland-egl-backend-dev:armhf \
		    libxcb-shm0-dev:armhf pkg-config:armhf
echo "---------------------------------------------------------"
echo "         End: Install mesa dependencies"
echo "---------------------------------------------------------"

echo "---------------------------------------------------------"
echo "         Start: Configure compilers"
echo "---------------------------------------------------------"
# 删除 llvm-17
sudo apt remove -y llvm-17 llvm-17-dev llvm-17-tools
sudo apt autoremove -y

# 安装 llvm-18 和其他必要工具
sudo apt install -y libclang-18-dev libclang-common-18-dev libclang-cpp18-dev \
  libclc-18 libclc-18-dev libllvmspirvlib-18-dev llvm-18 llvm-18-dev llvm-18-linker-tools \
  llvm-18-runtime llvm-18-tools llvm-spirv-18 libpolly-18-dev llvm-18*
sudo apt install -y gcc-14 g++-14 g++-14-arm-linux-gnueabihf gcc-14-arm-linux-gnueabihf clang clang-18

# 更新编译器的符号链接
sudo rm /usr/bin/gcc
sudo rm /usr/bin/g++
sudo rm /usr/bin/arm-linux-gnueabihf-g++
sudo rm /usr/bin/arm-linux-gnueabihf-gcc
sudo rm /usr/bin/llvm-config
sudo ln -s /usr/bin/gcc-14 /usr/bin/gcc
sudo ln -s /usr/bin/g++-14 /usr/bin/g++
sudo ln -s /usr/bin/arm-linux-gnueabihf-g++-14 /usr/bin/arm-linux-gnueabihf-g++
sudo ln -s /usr/bin/arm-linux-gnueabihf-gcc-14 /usr/bin/arm-linux-gnueabihf-gcc
sudo ln -s /usr/bin/llvm-config-18 /usr/bin/llvm-config
echo "---------------------------------------------------------"
echo "           End: Configure compilers"
echo "---------------------------------------------------------"

echo "---------------------------------------------------------"
echo "              Start: Create swap"
echo "---------------------------------------------------------"
sudo dd if=/dev/zero of=/swapfile bs=1M count=10240
sudo mkswap /swapfile
sudo swapon /swapfile
echo "---------------------------------------------------------"
echo "               End: Create swap"
echo "---------------------------------------------------------"

echo "---------------------------------------------------------"
echo "     Start: Copy cross compile configuration"
echo "---------------------------------------------------------"
cd ${project_path}
cp -f ./files/cross32.txt ./mesa/cross32.txt
echo "---------------------------------------------------------"
echo "      End: Copy cross compile configuration"
echo "---------------------------------------------------------"
