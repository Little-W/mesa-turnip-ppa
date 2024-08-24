#!/usr/bin/env bash

## A script for creating Ubuntu bootstraps for mesa compilation.
##
## debootstrap and perl are required
## root rights are required

PROJDIR=$(pwd)

if [ "$EUID" != 0 ]; then
	echo "This script requires root rights!"
	exit 1
fi

if ! command -v debootstrap 1>/dev/null || ! command -v perl 1>/dev/null; then
	echo "Please install debootstrap and perl and run the script again"
	exit 1
fi

export CHROOT_DISTRO="noble"
export CHROOT_MIRROR="https://ftp.uni-stuttgart.de/ubuntu/"

export MAINDIR=/opt/chroots
export CHROOT="${MAINDIR}"/${CHROOT_DISTRO}_chroot

build_container () {
	CHROOT_PATH="${CHROOT}"

	echo "Unmount chroot directories. Just in case."
	umount -Rl "${CHROOT_PATH}"
	
	echo "Mount directories for chroot"
	mount --bind "${CHROOT_PATH}" "${CHROOT_PATH}"
	mount -t proc /proc "${CHROOT_PATH}"/proc
	mount --bind /sys "${CHROOT_PATH}"/sys
	mount --make-rslave "${CHROOT_PATH}"/sys
	mount --bind /dev "${CHROOT_PATH}"/dev
	mount --bind /dev/pts "${CHROOT_PATH}"/dev/pts
	mount --bind /dev/shm "${CHROOT_PATH}"/dev/shm
	mount --make-rslave "${CHROOT_PATH}"/dev

	rm -f "${CHROOT_PATH}"/etc/resolv.conf
	cp /etc/resolv.conf "${CHROOT_PATH}"/etc/resolv.conf
    
	echo "Chrooting into ${CHROOT_PATH}"
	chroot "${CHROOT_PATH}" /usr/bin/env LC_ALL=en_US.UTF_8 LANGUAGE=en_US.UTF_8 LANG=en_US.UTF-8 \
			PATH="/bin:/sbin:/usr/bin:/usr/local/bin:/usr/sbin" \
			/opt/setup_env.sh

	echo "Unmount chroot directories"
	umount -l "${CHROOT_PATH}"
	umount "${CHROOT_PATH}"/proc
	umount "${CHROOT_PATH}"/sys
	umount "${CHROOT_PATH}"/dev/pts
	umount "${CHROOT_PATH}"/dev/shm
	umount "${CHROOT_PATH}"/dev
}

prepare_chroot () {
cat <<EOF > "${MAINDIR}"/setup_env.sh
#!/usr/bin/env bash

apt update
apt -y install nano
apt -y install locales
echo "en_US.UTF_8 UTF-8" >> /etc/locale.gen

echo "deb [arch=amd64] ${CHROOT_MIRROR} ${CHROOT_DISTRO} main restricted" > /etc/apt/sources.list
echo "deb [arch=amd64] ${CHROOT_MIRROR} ${CHROOT_DISTRO}-updates main restricted" >> /etc/apt/sources.list
echo "deb [arch=amd64] ${CHROOT_MIRROR} ${CHROOT_DISTRO} universe" >> /etc/apt/sources.list
echo "deb [arch=amd64] ${CHROOT_MIRROR} ${CHROOT_DISTRO}-updates universe" >> /etc/apt/sources.list
echo "deb [arch=amd64] ${CHROOT_MIRROR} ${CHROOT_DISTRO} multiverse" >> /etc/apt/sources.list
echo "deb [arch=amd64] ${CHROOT_MIRROR} ${CHROOT_DISTRO}-updates multiverse" >> /etc/apt/sources.list
echo "deb [arch=amd64] ${CHROOT_MIRROR} ${CHROOT_DISTRO}-backports main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb [arch=amd64] http://security.ubuntu.com/ubuntu ${CHROOT_DISTRO}-security main restricted" >> /etc/apt/sources.list
echo "deb [arch=amd64] http://security.ubuntu.com/ubuntu ${CHROOT_DISTRO}-security universe" >> /etc/apt/sources.list
echo "deb [arch=amd64] http://security.ubuntu.com/ubuntu ${CHROOT_DISTRO}-security multiverse" >> /etc/apt/sources.list

echo "deb-src [arch=amd64] ${CHROOT_MIRROR} ${CHROOT_DISTRO} main restricted" >> /etc/apt/sources.list
echo "deb-src [arch=amd64] ${CHROOT_MIRROR} ${CHROOT_DISTRO}-updates main restricted" >> /etc/apt/sources.list
echo "deb-src [arch=amd64] ${CHROOT_MIRROR} ${CHROOT_DISTRO} universe" >> /etc/apt/sources.list
echo "deb-src [arch=amd64] ${CHROOT_MIRROR} ${CHROOT_DISTRO}-updates universe" >> /etc/apt/sources.list
echo "deb-src [arch=amd64] ${CHROOT_MIRROR} ${CHROOT_DISTRO} multiverse" >> /etc/apt/sources.list
echo "deb-src [arch=amd64] ${CHROOT_MIRROR} ${CHROOT_DISTRO}-updates multiverse" >> /etc/apt/sources.list
echo "deb-src [arch=amd64] ${CHROOT_MIRROR} ${CHROOT_DISTRO}-backports main restricted universe multiverse" >> /etc/apt/sources.list
echo "deb-src [arch=amd64] http://security.ubuntu.com/ubuntu ${CHROOT_DISTRO}-security main restricted" >> /etc/apt/sources.list
echo "deb-src [arch=amd64] http://security.ubuntu.com/ubuntu ${CHROOT_DISTRO}-security universe" >> /etc/apt/sources.list
echo "deb-src [arch=amd64] http://security.ubuntu.com/ubuntu ${CHROOT_DISTRO}-security multiverse" >> /etc/apt/sources.list

apt update
apt -y upgrade
apt -y dist-upgrade
apt -y install software-properties-common

locale-gen

# 添加arm64架构支持
dpkg --add-architecture arm64

# 添加arm64软件源
echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports $(lsb_release -cs) main restricted universe multiverse" > /etc/apt/sources.list.d/arm64.list
echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports $(lsb_release -cs)-updates main restricted universe multiverse" >> /etc/apt/sources.list.d/arm64.list
echo "deb [arch=arm64] http://ports.ubuntu.com/ubuntu-ports $(lsb_release -cs)-backports main restricted universe multiverse" >> /etc/apt/sources.list.d/arm64.list

echo "deb-src [arch=arm64] http://ports.ubuntu.com/ubuntu-ports $(lsb_release -cs) main restricted universe multiverse" >> /etc/apt/sources.list.d/arm64.list
echo "deb-src [arch=arm64] http://ports.ubuntu.com/ubuntu-ports $(lsb_release -cs)-updates main restricted universe multiverse" >> /etc/apt/sources.list.d/arm64.list
echo "deb-src [arch=arm64] http://ports.ubuntu.com/ubuntu-ports $(lsb_release -cs)-backports main restricted universe multiverse" >> /etc/apt/sources.list.d/arm64.list

apt update

ln -s /usr/bin/pkg-config /usr/bin/aarch64-linux-gnu-pkg-config

rm -rf /usr/lib/aarch64-linux-gnu/
ln -s /tmp/arm64-deps/usr/lib/aarch64-linux-gnu /usr/lib/aarch64-linux-gnu
#rm -rf /tmp/arm64-deps/usr/lib/aarch64-linux-gnu/*.a

rm -rf /usr/include/aarch64-linux-gnu/

ls /tmp/arm64-deps/usr/include/ | \
xargs -I {} sh -c '\
if [ -e "/usr/include/{}" ]; then \
    echo "目标目录中已存在 {}，跳过..."; \
else \
    echo "创建符号链接：/tmp/arm64-deps/usr/include/{} -> /usr/include/{}"; \
    sudo ln -s "/tmp/arm64-deps/usr/include/{}" "/usr/include/{}"; \
fi'

cd /usr/lib
ln -s ./aarch64-linux-gnu/ld-linux-aarch64.so.1 ./

apt install -y qemu-user-binfmt cmake

# 安装mesa构建依赖和基本工具
apt build-dep -y mesa

# 安装 GCC 14 交叉编译器 (AArch64)
apt install -y gcc-14-aarch64-linux-gnu g++-14-aarch64-linux-gnu binutils-aarch64-linux-gnu

# 设置 AArch64 GCC 14 为默认
update-alternatives --install /usr/bin/aarch64-linux-gnu-gcc aarch64-linux-gnu-gcc /usr/bin/aarch64-linux-gnu-gcc-14 100
update-alternatives --install /usr/bin/aarch64-linux-gnu-g++ aarch64-linux-gnu-g++ /usr/bin/aarch64-linux-gnu-g++-14 100
update-alternatives --install /usr/bin/aarch64-linux-gnu-gcc-ar aarch64-linux-gnu-gcc-ar /usr/bin/aarch64-linux-gnu-gcc-ar-14 100
update-alternatives --install /usr/bin/aarch64-linux-gnu-gcc-nm aarch64-linux-gnu-gcc-nm /usr/bin/aarch64-linux-gnu-gcc-nm-14 100
update-alternatives --install /usr/bin/aarch64-linux-gnu-gcc-ranlib aarch64-linux-gnu-gcc-ranlib /usr/bin/aarch64-linux-gnu-gcc-ranlib-14 100

update-alternatives --set aarch64-linux-gnu-gcc /usr/bin/aarch64-linux-gnu-gcc-14
update-alternatives --set aarch64-linux-gnu-g++ /usr/bin/aarch64-linux-gnu-g++-14
update-alternatives --set aarch64-linux-gnu-gcc-ar /usr/bin/aarch64-linux-gnu-gcc-ar-14
update-alternatives --set aarch64-linux-gnu-gcc-nm /usr/bin/aarch64-linux-gnu-gcc-nm-14
update-alternatives --set aarch64-linux-gnu-gcc-ranlib /usr/bin/aarch64-linux-gnu-gcc-ranlib-14

# 安装 GCC 14 交叉编译器 (ARMHF)
apt install -y gcc-14-arm-linux-gnueabihf g++-14-arm-linux-gnueabihf binutils-arm-linux-gnueabihf

# 设置 ARMHF GCC 14 为默认
update-alternatives --install /usr/bin/arm-linux-gnueabihf-gcc arm-linux-gnueabihf-gcc /usr/bin/arm-linux-gnueabihf-gcc-14 100
update-alternatives --install /usr/bin/arm-linux-gnueabihf-g++ arm-linux-gnueabihf-g++ /usr/bin/arm-linux-gnueabihf-g++-14 100
update-alternatives --install /usr/bin/arm-linux-gnueabihf-gcc-ar arm-linux-gnueabihf-gcc-ar /usr/bin/arm-linux-gnueabihf-gcc-ar-14 100
update-alternatives --install /usr/bin/arm-linux-gnueabihf-gcc-nm arm-linux-gnueabihf-gcc-nm /usr/bin/arm-linux-gnueabihf-gcc-nm-14 100
update-alternatives --install /usr/bin/arm-linux-gnueabihf-gcc-ranlib arm-linux-gnueabihf-gcc-ranlib /usr/bin/arm-linux-gnueabihf-gcc-ranlib-14 100

update-alternatives --set arm-linux-gnueabihf-gcc /usr/bin/arm-linux-gnueabihf-gcc-14
update-alternatives --set arm-linux-gnueabihf-g++ /usr/bin/arm-linux-gnueabihf-g++-14
update-alternatives --set arm-linux-gnueabihf-gcc-ar /usr/bin/arm-linux-gnueabihf-gcc-ar-14
update-alternatives --set arm-linux-gnueabihf-gcc-nm /usr/bin/arm-linux-gnueabihf-gcc-nm-14
update-alternatives --set arm-linux-gnueabihf-gcc-ranlib /usr/bin/arm-linux-gnueabihf-gcc-ranlib-14

# 安装 Clang-18、LLD-18 及相关 LLVM 工具
sudo apt install -y clang-18 lld-18 llvm-18 llvm-18-dev llvm-18-tools libllvm18 libclang-18-dev libclang-common-18-dev libclang1-18 libclang-cpp18

# 设置 Clang-18 为默认的 Clang 版本
sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-18 100
sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-18 100
sudo update-alternatives --install /usr/bin/llvm-config llvm-config /usr/bin/llvm-config-18 100

# 设置 LLD-18 为默认的链接器
sudo update-alternatives --install /usr/bin/ld.lld ld.lld /usr/bin/lld-18 100
sudo update-alternatives --install /usr/bin/lld lld /usr/bin/lld-18 100

# 设置其他 LLVM 工具为默认，移除版本号后设置
sudo update-alternatives --install /usr/bin/llvm-ar llvm-ar /usr/bin/llvm-ar-18 100
sudo update-alternatives --install /usr/bin/llvm-nm llvm-nm /usr/bin/llvm-nm-18 100
sudo update-alternatives --install /usr/bin/llvm-strip llvm-strip /usr/bin/llvm-strip-18 100
sudo update-alternatives --install /usr/bin/llvm-objcopy llvm-objcopy /usr/bin/llvm-objcopy-18 100
sudo update-alternatives --install /usr/bin/llvm-objdump llvm-objdump /usr/bin/llvm-objdump-18 100
sudo update-alternatives --install /usr/bin/llvm-readelf llvm-readelf /usr/bin/llvm-readelf-18 100
sudo update-alternatives --install /usr/bin/llvm-ranlib llvm-ranlib /usr/bin/llvm-ranlib-18 100

sudo update-alternatives --set clang /usr/bin/clang-18
sudo update-alternatives --set clang++ /usr/bin/clang++-18
sudo update-alternatives --set llvm-config /usr/bin/llvm-config-18
sudo update-alternatives --set ld.lld /usr/bin/lld-18
sudo update-alternatives --set lld /usr/bin/lld-18
sudo update-alternatives --set llvm-ar /usr/bin/llvm-ar-18
sudo update-alternatives --set llvm-nm /usr/bin/llvm-nm-18
sudo update-alternatives --set llvm-strip /usr/bin/llvm-strip-18
sudo update-alternatives --set llvm-objcopy /usr/bin/llvm-objcopy-18
sudo update-alternatives --set llvm-objdump /usr/bin/llvm-objdump-18
sudo update-alternatives --set llvm-readelf /usr/bin/llvm-readelf-18
sudo update-alternatives --set llvm-ranlib /usr/bin/llvm-ranlib-18

echo "库目录展示"
ls -l /usr/lib/aarch64-linux-gnu/
#ls -l /tmp/arm64-deps/usr/lib/aarch64-linux-gnu/
echo "交叉编译环境配置完成"

# 清理...
apt -y clean
apt -y autoclean
EOF

    mkdir -p "${CHROOT}"/tmp
    mv /tmp/arm64-deps/ "${CHROOT}"/tmp/
	chmod +x "${MAINDIR}"/setup_env.sh
	mv "${MAINDIR}"/setup_env.sh "${CHROOT}"/opt
}

mkdir -p "${MAINDIR}"

if [ -z "$DEBOOTSTRAP_DIR" ]; then
	if [ -x /debootstrap/debootstrap ]; then
		DEBOOTSTRAP_DIR=/debootstrap
	else
		DEBOOTSTRAP_DIR=/usr/share/debootstrap
	fi
fi

echo -n "amd64" > "${DEBOOTSTRAP_DIR}"/arch
debootstrap --arch=amd64 $CHROOT_DISTRO "${CHROOT}" $CHROOT_MIRROR

prepare_chroot
build_container

rm "${CHROOT}"/opt/setup_env.sh
echo "Done"

