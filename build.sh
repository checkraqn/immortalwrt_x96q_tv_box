#!/bin/bash
set -e

REPO_URL="https://github.com/immortalwrt/immortalwrt.git"
BUILD_DIR="immortalwrt_src"
CUR_DIR=$(pwd)

TARGET_COMMIT="bce0a385ed95e93bc86bd6ff3e5ec5fb25293454" 

sudo chown -R build:build .

if [ ! -d "$BUILD_DIR/.git" ]; then
    rm -rf "$BUILD_DIR"
    git clone $REPO_URL $BUILD_DIR
fi

cd "$BUILD_DIR"

git fetch origin
git checkout $TARGET_COMMIT

./scripts/feeds update -a
./scripts/feeds install luci
./scripts/feeds install base-files
./scripts/feeds install dnsmasq
./scripts/feeds install firewall4
./scripts/feeds install odhcpd-ipv6only
./scripts/feeds install dropbear

# Костыли от зацикливания пакетов
rm -rf package/feeds/*/luci-app-qbittorrent
rm -rf package/feeds/*/qbittorrent*
rm -rf package/feeds/*/luci-app-weechat
rm -rf package/feeds/*/weechat*
rm -rf tmp/.config-package.in

# Создаем минимальный конфиг OpenWrt
echo "CONFIG_TARGET_sunxi=y" > .config
echo "CONFIG_TARGET_sunxi_cortexa53=y" >> .config
echo "CONFIG_TARGET_sunxi_cortexa53_Generic=y" >> .config
echo "CONFIG_TARGET_PROFILE=\"Generic\"" >> .config
echo "CONFIG_TARGET_ROOTFS_EXT4FS=y" >> .config
echo "CONFIG_TARGET_IMAGES_EXT4_SDCARD=y" >> .config

# Добавляем LuCI
echo "CONFIG_PACKAGE_luci=y" >> .config
echo "CONFIG_PACKAGE_luci-theme-bootstrap=y" >> .config
echo "CONFIG_PACKAGE_luci-app-firewall=y" >> .config

# Копируем наш DTS
mkdir -p target/linux/sunxi/dts/
cp $CUR_DIR/configs/sun50i-h313-x96q-ddr3-v5.1.dts target/linux/sunxi/dts/sun50i-h313-x96q-ddr3-v5.1.dts
echo 'dtb-$(CONFIG_ARCH_SUNXI) += sun50i-h313-x96q-ddr3-v5.1.dtb' >> target/linux/sunxi/dts/Makefile

make defconfig

# ВАЖНО: Копируем конфиг ядра и добавляем туда фикс для 6.12!
cp $CUR_DIR/configs/kernel_h313_6.12.config target/linux/sunxi/config-6.12
echo "CONFIG_SUNXI_ADDR_MGT=y" >> target/linux/sunxi/config-6.12

# Применяем наши патчи (ядро и U-Boot)
rm -f target/linux/sunxi/patches-6.12/910-arm64-dts-allwinner-h5-add-more-cpu-operating-points-.patch
cp $CUR_DIR/patches/kernel/* target/linux/sunxi/patches-6.12/
cp $CUR_DIR/patches/u-boot/* package/boot/uboot-sunxi/patches/

# Запускаем сборку. Возвращаем многопоточность для скорости!
make -j$(nproc)
