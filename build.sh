#!/bin/bash
#
# Compile script for MoeKernel
# Copyright (C) 2024 Shoiya A.

SECONDS=0
PATH=$PWD/toolchain/bin:$PATH

export modpath=AnyKernel3/modules/vendor/lib/modules
export ARCH=arm64

export KBUILD_BUILD_USER=Moe
export KBUILD_BUILD_HOST=Nyan

export LLVM_DIR=$PWD/toolchain/bin
export LLVM=1

AK3_DIR="$HOME/AnyKernel3"
DEFCONFIG="vendor/bangkk_defconfig"
ZIPNAME="MoeKernel-bangkk-$(date '+%Y%m%d-%H%M').zip"

if [[ $1 = "-m" || $1 = "--menu" ]]; then
    mkdir -p out
    make O=out ARCH=arm64 $DEFCONFIG menuconfig
elif [[ $1 = "menu" ]]; then
    mkdir -p out
    make O=out ARCH=arm64 $DEFCONFIG menuconfig
else
    mkdir -p out
    make O=out ARCH=arm64 $DEFCONFIG
fi

url_ksu_update="https://github.com/MoeKernel/scripts/raw/ksu/ksu_update.sh"
url_init_clang="https://github.com/MoeKernel/scripts/raw/ksu/init_clang.sh"

file_ksu_update="$PWD/ksu_update.sh"
file_init_clang="$PWD/init_clang.sh"

download_chmod_and_execute() {
    local url="$1"
    local file="$2"

    if [ ! -f "$file" ]; then
        echo "File $file not found. Downloading..."
        wget "$url" -O "$file"
        if [ $? -eq 0 ]; then
            echo "Download of $file completed."
            chmod +x "$file"
            echo "Execute permissions added to $file."
        else
            echo "Failed to download $file."
            return 1
        fi
    else
        echo "File $file already exists."
    fi

    echo "Executing $file..."
    "$file"
    if [ $? -eq 0 ]; then
        echo "$file executed successfully."
    else
        echo "Failed to execute $file."
    fi
}

download_chmod_and_execute "$url_ksu_update" "$file_ksu_update"
download_chmod_and_execute "$url_init_clang" "$file_init_clang"

ARGS='
CC=clang
LD='${LLVM_DIR}/ld.lld'
ARCH=arm64
AR='${LLVM_DIR}/llvm-ar'
NM='${LLVM_DIR}/llvm-nm'
AS='${LLVM_DIR}/llvm-as'
OBJCOPY='${LLVM_DIR}/llvm-objcopy'
OBJDUMP='${LLVM_DIR}/llvm-objdump'
READELF='${LLVM_DIR}/llvm-readelf'
OBJSIZE='${LLVM_DIR}/llvm-size'
STRIP='${LLVM_DIR}/llvm-strip'
LLVM_AR='${LLVM_DIR}/llvm-ar'
LLVM_DIS='${LLVM_DIR}/llvm-dis'
LLVM_NM='${LLVM_DIR}/llvm-nm'
LLVM=1
'

if [[ $1 = "-r" || $1 = "--regen" ]]; then
	make $ARGS $DEFCONFIG savedefconfig
	cp out/defconfig arch/arm64/configs/$DEFCONFIG
	echo -e "\nSuccessfully regenerated defconfig at $DEFCONFIG"
	exit
fi

make ${ARGS} O=out $DEFCONFIG moto.config
make ${ARGS} O=out -j$(nproc)

[ ! -e "out/arch/arm64/boot/Image" ] && \
echo "  ERROR : image binary not found in any of the specified locations , fix compile!" && \
exit 1

make O=out ${ARGS} -j$(nproc) INSTALL_MOD_PATH=modules INSTALL_MOD_STRIP=1 modules_install

echo -e "\nKernel compiled succesfully! Zipping up...\n"
if [ -d "$AK3_DIR" ]; then
	cp -r $AK3_DIR AnyKernel3
	git -C AnyKernel3 checkout bangkk &> /dev/null
elif ! git clone -q https://github.com/MoeKernel/AnyKernel3 -b bangkk; then
	echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
	exit 1
fi

mkdir -p ${modpath}
kver=$(make kernelversion)
kmod=$(echo ${kver} | awk -F'.' '{print $3}')

mkdir -p AnyKernel3/modules/vendor/lib/modules 
kver=$(make kernelversion)
kmod=$(echo ${kver} | awk -F'.' '{print $3}')
cp out/.config AnyKernel3/config
cp out/arch/arm64/boot/Image AnyKernel3/Image
cp out/arch/arm64/boot/dtb.img AnyKernel3/dtb
cp out/arch/arm64/boot/dtbo.img AnyKernel3/dtbo.img
# cp build.sta/${DEVICE}_modules.blocklist ${modpath}/modules.blocklist
cp $(find out/modules/lib/modules/5.4* -name '*.ko') ${modpath}/
cp out/modules/lib/modules/5.4*/modules.{alias,dep,softdep} ${modpath}/
cp out/modules/lib/modules/5.4*/modules.order ${modpath}/modules.load

sed -i 's/\(kernel\/[^: ]*\/\)\([^: ]*\.ko\)/\/vendor\/lib\/modules\/\2/g' ${modpath}/modules.dep
sed -i 's/.*\///; s/\.ko$//' ${modpath}/modules.load

source build.sta/${DEVICE}_mdconf
for useles_modules in "${modules_to_nuke[@]}"; do
  grep -vE "$useles_modules" ${modpath}/modules.load > /tmp/templd && mv /tmp/templd ${modpath}/modules.load
done

cd AnyKernel3
zip -r9 "../$ZIPNAME" * -x .git README.md *placeholder
cd ..
echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
echo "Zip: $ZIPNAME"
curl -F "file=@$ZIPNAME" https://temp.sh/upload
rm -rf AnyKernel3
