# 🛠️ [00] Cross-Compile 환경 구축 및 커널 빌드 자동화 파이프라인

---

## 1. 실습 개요
* **목표**: 우분투 호스트(`x86_64`) 환경에서 라즈베리파이 4 타겟(`ARM64`)용 리눅스 커널을 크로스 컴파일하기 위한 필수 패키지를 설치하고, `Build` -> `SCP 전송` -> `Install` 로 이어지는 3단계 쉘 스크립트 파이프라인을 구축한다.
* **학습 포인트**: `Kbuild` 시스템의 동작 원리 이해, 원격 타겟 보드 제어(SSH/SCP) 자동화, 패키지 매니저의 의존성 및 버전 홀드 기법 습득.

---

## 2. 커널 빌드 필수 패키지
커널 소스를 기계어로 변환하기 전, `Kconfig` 설정 메뉴를 구성하고 복잡한 수학 연산 및 암호화 서명을 처리하기 위해 다음 도구들이 필수적으로 요구된다.

* **`bc`**: 커널 빌드 스크립트(`Makefile`) 내부에서 시간에 관련된 상수들이나 메모리 사이즈 오프셋 등 복잡한 임의 정밀도 수학 연산을 수행하는 텍스트 기반 계산기.
* **`flex` & `bison`**: 텍스트를 의미 있는 단어(Token)로 쪼개고 문법을 해석하는 구문 분석기 듀오. make menuconfig의 설정 메뉴 문법을 파싱하거나, Device Tree 소스(`.dts`)를 바이너리(`.dtb)`로 컴파일할 때 사용된다.
* **`libssl-dev`**: OpenSSL 개발 라이브러리. 최신 커널에서 모듈 서명 및 암호화 보안 처리를 위해 사용되며, 누락 시 빌드 에러가 발생한다.
* **`gcc-aarch64-linux-gnu`**: 인텔/AMD(`x86_64`) 아키텍처인 우분투 호스트에서 라즈베리파이(`arm64`)용 기계어를 생성하기 위한 크로스 컴파일러.

---

## 3. 실행 결과
호스트 PC에서 타겟 보드까지 클릭 한 번에 전송 및 적용할 수 있도록 3단계 쉘 스크립트를 구성하였다.

### [Step 1] 빌드 스크립트 (`build_rpi_kernel.sh`)
```shell
#!/bin/bash

KERNEL=kernel8                          # kernel의 버전으로 바꿔주세요
KERNEL_DIR=""                           # kernel의 소스 코드가 있는 경로로 바꿔주세요
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
```

---

### [Step 2] 전송 스크립트 (`deploy_rpi_kernel.sh`)
```shell
#!/bin/bash

KERNEL=kernel8                          # kernel의 버전으로 바꿔주세요
KERNEL_DIR=""                           # kernel의 경로로 바꿔주세요
ARCH=arm64
CROSS_COMPILE=aarch64-linux-gnu-

RPI_USER=""                             # 라즈베리파이 유저명으로 수정해주세요
RPI_IP=""                               # 라즈베리파이 IP 주소로 수정해주세요
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
```

---

### [Step 3] 설치 스크립트 (`install_rpi_kernel.sh` - 타겟 보드에서 실행)
```shell
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
```

---

## 🔥 4. 트러블슈팅 (Troubleshooting)

### Issue 1: apt upgrade 실행 시 커널 덮어쓰기 대참사
* **현상**: 라즈베리파이 타겟 보드에서 `sudo apt upgrade -y` 실행 후 재부팅 시, 기껏 크로스 컴파일하여 올려둔 커널 이미지와 모듈이 공식 배포판 버전으로 덮어씌워져 모듈 적재가 불가능해짐.
* **원인 분석**: 데비안/우분투 패키지 매니저는 의존성 및 버전 관리를 수행하며, 공식 저장소에 새 버전의 `linux-image` 패키지가 존재할 경우 `/boot/firmware` 파티션의 커널 바이너리를 교체해 버림.
* **해결 방안**: 개발 타겟 보드에서는 시스템 유틸리티만 업데이트하고 커널 패키지는 업데이트 대상에서 제외하도록 Hold 처리를 수행함.

```bash
# 라즈베리파이 OS (64-bit) 기준 커널 패키지 업데이트 잠금
sudo apt-mark hold linux-image-rpi-2712 linux-image-rpi-v8

# 정상 잠금 확인
apt-mark showhold
```

### Issue 2: 타겟 보드 커널 업데이트로 인한 호스트 버전 동기화 문제
* **현상**: 타겟 보드가 이미 최신 커널로 강제 업그레이드되어 버렸고, 기존 호스트 PC의 커널 소스 트리 버전이 구버전으로 남아있어 크로스 컴파일을 하더라도 타겟 보드에서 인식하지 못하는 상황 발생.
* **원인 분석**: 커널 모듈은 로드될 때 `vermagic`을 엄격하게 검사함. 호스트(빌드 환경)와 타겟(실행 환경)의 커널 버전이 다르면 `Invalid module format` 에러가 발생함.
* **해결 방안**: 타겟 보드를 구버전으로 롤백하는 대신, 호스트 PC의 커널 소스 트리를 최신 타겟 버전에 맞춰 강제로 버전업하여 문제를 해결함.