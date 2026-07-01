#!/bin/bash
set -euo pipefail
KERNEL_DIR="$PWD"
CLANG_PATH="/opt/clang-r416183b"
WORK_ROOT="$PWD"
AK3_ROOT="/root/AnyKernel3"
export TZ=Asia/Shanghai

# 安装依赖
sudo apt update -y
sudo apt install --no-install-recommends -y binutils git make bc bison openssl curl zip kmod cpio flex libelf-dev libssl-dev libc6-dev device-tree-compiler ca-certificates python3 xz-utils aria2 build-essential ccache pigz parallel jq wget

# 校验工具链
[ ! -d "${CLANG_PATH}/bin" ] || [ ! -f "${CLANG_PATH}/bin/clang-12" ] && echo "工具链缺失" && exit 1
export PATH="${CLANG_PATH}/bin:$PATH"
export CCACHE_DIR="$HOME/.ccache_kernel"
export CCACHE_MAXSIZE="5G"
export CCACHE_SLOPPINESS="file_macro,time_macros"

# 校验源码目录
[ ! -d "${KERNEL_DIR}/arch/arm64" ] && echo "非内核源码目录" && exit 1
cd "${KERNEL_DIR}"

# 编译环境变量
export ARCH=arm64
export SUBARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-
export CLANG_TRIPLE=aarch64-linux-gnu-
export LLVM=1
export LLVM_IAS=1

make clean && make mrproper
rm -rf out && mkdir -p out
start_time=$(date +%s)

# 编译命令直接写死版本，无点无下划线无前缀符号
make CC="ccache clang" -j$(nproc) O=out gki_defconfig
make CC="ccache clang" -j$(nproc) O=out olddefconfig prepare
make CC="ccache clang" LD=ld.lld LOCALVERSION="-android12-9-00288" -j$(nproc) O=out 2>&1 | tee "${WORK_ROOT}/build.log"

# 计算编译耗时
end_time=$(date +%s)
cost_sec=$((end_time - start_time))
cost_min=$((cost_sec / 60))
cost_s=$((cost_sec % 60))
echo "编译耗时：${cost_min}分${cost_s}秒"

# AK3打包流程
cd "${WORK_ROOT}"
BUILD_DATE=$(date +%Y%m%d)
ZIP_NAME="AnyKernel3-android12-5.10.252-release-${BUILD_DATE}.zip"

rm -rf "${AK3_ROOT}"
git clone --depth=1 https://hk.gh-proxy.org/https://github.com/yhys233/AnyKernel3 "${AK3_ROOT}"
cp "${KERNEL_DIR}/out/arch/arm64/boot/Image" "${AK3_ROOT}/"
cd "${AK3_ROOT}"

# 仅清理冗余文件，完全移除机型校验相关sed操作
rm -rf .git README.md patch ramdisk modules .github
zip -r9 "/mnt/${ZIP_NAME}" .

# 打包后清理AK3内Image文件
rm -f "${AK3_ROOT}/Image"

cd "${WORK_ROOT}"
echo "打包完成：${WORK_ROOT}/${ZIP_NAME}"
ccache -s
