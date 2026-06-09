#!/bin/bash

KERNEL=kernel8

echo "[1/4] 커널 이미지 및 디바이스 트리(/boot/firmware) 업데이트 중..."
sudo cp $KERNEL.img /boot/firmware
sudo cp *.dtb /boot/firmware
sudo cp overlays/* /boot/firmware/overlays/

echo "[2/4] 모듈 압축 해제 중..."
tar -xzvf modules.tar.gz

echo "[3/4] 새 모듈을 시스템 경로로 복사 중..."
sudo cp -a lib/modules/* /lib/modules/

echo "[4/4] 모듈 인덱스 갱신(depmod) 및 디스크 동기화..."
NEW_KERNEL_VER=$(ls lib/modules | head -n 1)

if [ -n "$NEW_KERNEL_VER" ]; then
    echo "  -> 타겟 커널 버전: $NEW_KERNEL_VER"
    sudo depmod -a $NEW_KERNEL_VER
else
    echo "❌ 모듈 버전을 찾을 수 없습니다."
fi

sync

echo "[5/5] 임시 파일 정리 중..."
rm -rf lib
rm -f modules.tar.gz

echo "[완료] 모든 적용이 끝났습니다!"
