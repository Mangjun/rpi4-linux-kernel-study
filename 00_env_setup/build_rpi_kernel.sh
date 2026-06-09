#!/bin/bash

KERNEL=kernel8				# kernel의 버전으로 바꿔주세요
KERNEL_DIR=""				# kernel의 소스 코드가 있는 경로로 바꿔주세요
BUILD_LOG="$HOME/rpi_build.log"
ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-
CONFIG=bcm2711_defconfig

echo "[Step 1] 빌드 필수 패키지 & 크로스 컴파일러 설치 중..."

sudo apt update
sudo apt install -y bc bison flex libssl-dev make build-essential gcc-aarch64-linux-gnu

echo "[Step 1] 패키지 설치 완료"
sleep 1

if [ -z "$KERNEL_DIR" ]; then
    echo "KERNEL_DIR 변수가 비어있습니다. 스크립트를 수정해주세요!"
    exit 1
fi

echo "[Step 2] 커널 소스 디렉터리로 이동 ($KERNEL_DIR)..."

cd $KERNEL_DIR || { echo "커널 디렉터리를 찾을 수 없습니다!"; exit 1; }

echo "[Step 3] 커널 설정 (Kconfig) 적용 중..."

make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE $CONFIG

echo "[Step 3] 커널 설정 완료"
sleep 1
echo "[Step 4] 본격적인 커널 빌드 시작 (이 작업은 시간이 걸립니다)..."

make -j$(nproc) ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE Image modules dtbs 2>&1 | tee $BUILD_LOG

echo "[완료] 커널 빌드(Image, modules, dtbs)가 성공적으로 끝났습니다!"
