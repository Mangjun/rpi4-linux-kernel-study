# [실전 트러블슈팅] Debugfs 드라이버 구현 및 QEMU/Initramfs 테스트 환경 구축

## 📌 개요
본 문서는 물리적인 라즈베리파이 타겟 보드가 없는 환경에서, 리눅스 커널의 **Debugfs 드라이버를 직접 구현**하고 <b>QEMU 가상 머신과 초경량 램디스크(Initramfs)</b>를 활용하여 이를 테스트하는 전체 파이프라인과 트러블슈팅 과정을 기록함.

---

## 1. Debugfs 드라이버 구현 (커널 내부 백도어)
커널 내부 변수를 User Space에서 실시간으로 읽고 쓰기 위한 가상 파일 시스템(`debugfs`) 드라이버 구현.

### 1.1 소스 코드 작성 (`drivers/soc/bcm/rpi_debugfs.c`)
```c
#include <linux/module.h>
#include <linux/moduleparam.h>
#include <linux/platform_device.h>
#include <linux/io.h>
#include <linux/init.h>
#include <linux/memblock.h>
#include <linux/slab.h>
#include <linux/of.h>
#include <linux/of_address.h>
#include <linux/cpu.h>
#include <linux/delay.h>
#include <asm/setup.h>
#include <linux/input.h>
#include <linux/debugfs.h>
#include <linux/timer.h>
#include <linux/workqueue.h>
#include <linux/mutex.h>
#include <linux/uaccess.h>
#include <asm/memory.h>

uint32_t raspbian_debug_state = 0x1000;
static struct dentry *rpi_kernel_debug_debugfs_root;

static int rpi_kernel_debug_stat_get(void *data, u64 *val)
{
        printk("===[%s][L:%d][val:%d]===\n", __func__, __LINE__, raspbian_debug_state);
        *val = raspbian_debug_state;

        return 0;
}

static int rpi_kernel_debug_stat_set(void *data, u64 val)
{
        raspbian_debug_state = (uint32_t)val;

        printk("[rpi] [%s][L:%d], raspbian_debug_state[%lu], value[%lu]===\n", __func__, __LINE__, (long unsigned int)raspbian_debug_state, (long unsigned int)val);

        return 0;
}

DEFINE_SIMPLE_ATTRIBUTE(rpi_kernel_debug_stat_fops, rpi_kernel_debug_stat_get, rpi_kernel_debug_stat_set, "%llu\n");

static int rpi_kernel_debug_debugfs_driver_probe(struct platform_device *pdev)
{
        printk("===[%s][L:%d]===\n", __func__, __LINE__);

        return 0;
}

static struct platform_driver rpi_kernel_debug_debugfs_driver = {
        .probe          = rpi_kernel_debug_debugfs_driver_probe,
        .driver         = {
                .owner = THIS_MODULE,
                .name  = "rpi_debug",
        },
};

static int __init rpi_kernel_debug_debugfs_init(void)
{
        printk("===[%s][L:%d]===\n", __func__, __LINE__);

        rpi_kernel_debug_debugfs_root = debugfs_create_dir("rpi_debug", NULL);
        debugfs_create_file("val", 0644, rpi_kernel_debug_debugfs_root, NULL, &rpi_kernel_debug_stat_fops);

        return platform_driver_register(&rpi_kernel_debug_debugfs_driver);
}

late_initcall(rpi_kernel_debug_debugfs_init);

MODULE_DESCRIPTION("raspberrypi debug interface driver");
MODULE_AUTHOR("mangjun");
MODULE_LICENSE("GPL");
```

* `DEFINE_SIMPLE_ATTRIBUTE` 매크로를 사용하여 `read/write` file_operations를 단순화.
* [주의] 최신 6.x 커널에서는 `<linux/slub_def.h>` 헤더가 삭제되었으므로 `<linux/slab.h>`만 사용.

### 1.2. 커널 빌트인(Built-in) 설정 (`Makefile`)
```Makefile
# drivers/soc/bcm/Makefile 파일 수정
obj-y += rpi_debugfs.o  # 모듈(.ko)이 아닌 커널(Image)에 영구 탑재
```

### 1.3. 커널 이미지(Image) 빌드
```bash
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- VERSION=6 ... EXTRAVERSION="+rpt-rpi-v8" Image -j$(nproc)
```

## 2. QEMU용 초경량 Initramfs(램디스크) 제작
수 GB 용량의 RootFS 이미지(`.img`) 없이 커널 드라이버만 빠르게 테스트하기 위한 `BusyBox` 기반 가상 하드디스크 구축.

### 2.1. ARM64용 정적 비지박스 세팅
* **[치명적 에러]** 호스트(Ubuntu/x86)용 비지박스를 넣으면 ARM 커널이 인식하지 못해 `Kernel panic: No working init found` 발생. **반드시 ARM64용 바이너리를 직접 다운로드해야 함**.

```bash
mkdir -p ~/my_rootfs/bin ~/my_rootfs/proc ~/my_rootfs/sys
cd ~/my_rootfs/bin

# ARM64용 비지박스 다운로드 및 권한 부여
wget [https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-armv8l](https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-armv8l) -O busybox
chmod +x busybox

# 필수 명령어 심볼릭 링크 생성
ln -s busybox sh; ln -s busybox mount; ln -s busybox ls; ln -s busybox cat; ln -s busybox echo
```

### 2.2. 초기화 스크립트(`init`) 작성 및 압축
```bash
cd ~/my_rootfs
cat << 'EOF' > init
#!/bin/sh
mount -t proc none /proc
mount -t sysfs none /sys
mount -t debugfs none /sys/kernel/debug  # Debugfs 자동 마운트
echo "Boot Success! Debugfs is Ready."
exec /bin/sh
EOF
chmod +x init

# cpio 포맷으로 램디스크 압축
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ~/initramfs.cpio.gz
```

## 3. QEMU 부팅 및 Debugfs 테스트

### 3.1. QEMU 실행 명령어 (RootFS 분리 모드)
```bash
qemu-system-aarch64 \
  -M virt \
  -cpu cortex-a72 \
  -smp 4 \
  -m 2048 \
  -kernel arch/arm64/boot/Image \
  -initrd ~/initramfs.cpio.gz \
  -nographic
```
* **종료 단축키**: `Ctrl + A` 누른 후 손 떼고 `x` 입력.

### 3.2. 동작 검증 (User Space ↔ Kernel Space 통신)
부팅 완료 후 쉘(`#`)에서 아래 명령어들을 통해 구현한 드라이버 동작 확인.

```bash
# 1. 파일 생성 확인
ls -l /sys/kernel/debug/rpi_debug/val

# 2. Get 함수
cat /sys/kernel/debug/rpi_debug/val

# 3. Set 함수
echo 9999 > /sys/kernel/debug/rpi_debug/val
```