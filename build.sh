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

# ВАЖНО: Используем конфиг из репозитория (там уже прописан профиль X96Q)
cp $CUR_DIR/configs/immortal_h313.config ./.config
# Если нужно добавить пакеты, можно раскомментировать строку ниже:
# cat "$CUR_DIR/configs/my_packages.txt" >> .config

make defconfig

# ВАЖНО: Исправляем конфиг ядра под 6.12 (добавляем SUNXI_ADDR_MGT)
cp $CUR_DIR/configs/kernel_h313_6.12.config target/linux/sunxi/config-6.12
echo "CONFIG_SUNXI_ADDR_MGT=y" >> target/linux/sunxi/config-6.12

# ВАЖНО: Удаляем падающую плату a64-olinuxino из U-Boot
sed -i '/a64-olinuxino/d' package/boot/uboot-sunxi/Makefile

# КРИТИЧНО ВАЖНО: Переименовываем наш DTS в то имя, которое ожидает скрипт упаковки
cp $CUR_DIR/configs/sun50i-h313-x96q-ddr3-v5.1.dts target/linux/sunxi/dts/sun50i-h313-x96q.dts
# Добавляем в Makefile для сборки именно этого имени
echo 'dtb-$(CONFIG_ARCH_SUNXI) += sun50i-h313-x96q.dtb' >> target/linux/sunxi/dts/Makefile

# Применяем патчи
rm -f target/linux/sunxi/patches-6.12/910-arm64-dts-allwinner-h5-add-more-cpu-operating-points-.patch
cp $CUR_DIR/patches/kernel/* target/linux/sunxi/patches-6.12/
cp $CUR_DIR/patches/u-boot/* package/boot/uboot-sunxi/patches/

# Запускаем сборку
make -j$(nproc)
