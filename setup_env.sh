#! /bin/bash

project_path=${PWD}

echo "---------------------------------------------------------"
echo "         Start: Clean up and initial setup"
echo "---------------------------------------------------------"
sudo rm -rf /opt/circleci/
sudo apt update
sudo apt install -y cmake git wget
sudo sed -i 's/Types: deb/Types:deb deb-src/g' /etc/apt/sources.list.d/ubuntu.sources
sudo apt update
git clone --depth=1 https://github.com/alexvorxx/Zink-Mesa-Xlib.git mesa
echo "---------------------------------------------------------"
echo "         End: Clean up and initial setup"
echo "---------------------------------------------------------"

echo "---------------------------------------------------------"
echo "         Start: Install mesa dependencies"
echo "---------------------------------------------------------"
sudo apt build-dep -y mesa
sudo apt install -y vulkan* *-mesa-* mesa*-* sdl*
echo "---------------------------------------------------------"
echo "         End: Install mesa dependencies"
echo "---------------------------------------------------------"

echo "---------------------------------------------------------"
echo "         Start: Configure compilers"
echo "---------------------------------------------------------"

# 安装 llvm-18 和其他必要工具
sudo apt install -y libclang-18-dev libclang-common-18-dev libclang-cpp18-dev \
  libclc-18 libclc-18-dev libllvmspirvlib-18-dev llvm-18 llvm-18-dev llvm-18-linker-tools \
  llvm-18-runtime llvm-18-tools llvm-spirv-18 libpolly-18-dev llvm-18*
sudo apt install -y gcc g++ gcc-14 g++-14 clang-18 clang
# 更新编译器的符号链接
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 100
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-14 100
sudo update-alternatives --install /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-18 100
sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-18 100
sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-18 100
echo "---------------------------------------------------------"
echo "           End: Configure compilers"
echo "---------------------------------------------------------"