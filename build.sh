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
./scripts/feeds install -a

# Костыли от зацикливания пакетов (qbittorrent и weechat)
rm -rf package/feeds/*/luci-app-qbittorrent
rm -rf package/feeds/*/qbittorrent*
rm -rf package/feeds/*/luci-app-weechat
rm -rf package/feeds/*/weechat*
rm -rf tmp/.config-package.in

for patch in $CUR_DIR/patches/Makefile/*.patch; do
    [ -f "$patch" ] && git apply "$patch" || true
done

cp $CUR_DIR/configs/immortal_h313.config ./.config
cat "$CUR_DIR/configs/my_packages.txt" >> .config

# ВАЖНО: Создаем папки принудительно перед копированием!
mkdir -p target/linux/sunxi/dts/
mkdir -p package/boot/uboot-sunxi/patches/

# Копируем наш DTS и прописываем в Makefile
cp $CUR_DIR/configs/sun50i-h313-x96q-ddr3-v5.1.dts target/linux/sunxi/dts/sun50i-h313-x96q-ddr3-v5.1.dts
echo 'dtb-$(CONFIG_ARCH_SUNXI) += sun50i-h313-x96q-ddr3-v5.1.dtb' >> target/linux/sunxi/dts/Makefile

make defconfig
cp $CUR_DIR/configs/kernel_h313_6.12.config target/linux/sunxi/config-6.12
rm -f target/linux/sunxi/patches-6.12/910-arm64-dts-allwinner-h5-add-more-cpu-operating-points-.patch
cp $CUR_DIR/patches/kernel/* target/linux/sunxi/patches-6.12/
cp $CUR_DIR/patches/u-boot/* package/boot/uboot-sunxi/patches/
make -j$(nproc)
