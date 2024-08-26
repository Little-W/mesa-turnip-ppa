#!/usr/bin/env bash
set -e

MESA_BRANCH=${MESA_BRANCH:-"main"}

# 克隆Mesa仓库
git clone --depth=1 https://gitlab.freedesktop.org/mesa/mesa.git -b ${MESA_BRANCH}

cp -f ./files/cross64_clang.txt ./mesa/cross64_clang.txt
cp -f ./files/cross64.txt ./mesa/cross64.txt

cd mesa
echo "应用补丁..."
for patch in ../turnip-patches/*.patch; do
    patch -p1 < "$patch"
done
