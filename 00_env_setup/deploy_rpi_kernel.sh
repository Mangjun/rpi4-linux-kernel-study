#!/bin/bash

KERNEL=kernel8				# kernel의 버전으로 바꿔주세요
KERNEL_DIR="$HOME/linux"		# kernel의 경로로 바꿔주세요
ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-

RPI_USER=""	 			# 라즈베리파이 유저명으로 수정해주세요
RPI_IP=""				# 라즈베리파이 IP 주소로 수정해주세요
RPI="$RPI_USER@$RPI_IP:/home/$RPI_USER"

TEMP_DIR="$HOME/rpi_temp"

echo "[Step 1] Image와 dtb 파일들 SCP 전송 시작..."

ssh $RPI_USER@$RPI_IP "mkdir -p /home/$RPI_USER/overlays"

scp install_rpi_kernel.sh $RPI

scp $KERNEL_DIR/arch/$ARCH/boot/Image $RPI/$KERNEL.img
scp $KERNEL_DIR/arch/$ARCH/boot/dts/broadcom/*.dtb $RPI
scp $KERNEL_DIR/arch/$ARCH/boot/dts/overlays/*.dtb* $RPI/overlays

echo "[Step 2] 임시 폴더($TEMP_DIR)에 모듈 설치 중..."
cd $KERNEL_DIR || { echo "커널 디렉터리를 찾을 수 없습니다."; exit 1; }

rm -rf $TEMP_DIR
mkdir -p $TEMP_DIR

make ARCH=$ARCH CROSS_COMPILE=$CROSS_COMPILE INSTALL_MOD_PATH=$TEMP_DIR modules_install

echo "[Step 3] 모듈 폴더 압축 및 SCP 전송 중..."

cd $TEMP_DIR || exit 1
tar -cvzf modules.tar.gz *
scp modules.tar.gz $RPI

echo "[완료] 라즈베리파이의 /home/$RPI_USER 경로에 모든 파일이 전송되었습니다!"
