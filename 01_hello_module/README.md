# 🛠️ [01] Hello Kernel Module 실습 및 트러블슈팅

## 1. 실습 개요
* **목표:** 가장 기본적인 형태의 리눅스 커널 모듈(`hello.ko`)을 작성하고, 크로스 컴파일하여 타겟 보드(Raspberry Pi 4) 커널에 동적으로 적재(Load) 및 제거(Unload)한다.
* **학습 포인트:** 커널 모듈의 뼈대 코드 작성법, 크로스 컴파일 전용 `Makefile` 구성, 타겟 보드 전송 및 테스트 사이클 확립.

## 2. 실행 결과
라즈베리파이 타겟 보드에서 정상 동작 확인 완료.
```bash
$sudo insmod hello.ko
$ dmesg | tail -n 2
[55312.997263] hello: loading out-of-tree module taints kernel.
[55313.002086] Hello, Kerenl 6.12! Module Loaded.

$ sudo rmmod hello
$ dmesg | tail -n 1
[55383.786991] Goodbye, Kernel! Module Unloaded.
```

## 🔥 3. 트러블슈팅 (Troubleshooting)
### Issue 1: 모듈 빌드 시 `Module.symvers is missing` 에러
* **현상**: 우분투 호스트에서 `make` 실행 시 컴파일은 진행되나, 마지막 `modpost` 단계에서 에러가 발생하며 `.ko` 파일이 생성되지 않음.
```Plaintext
WARNING: Module.symvers is missing.
ERROR: modpost: "_printk" undefined!
ERROR: modpost: "module_layout" undefined!
```

* **원인 분석**: 모듈이 커널 내부 함수(예: `printk`)를 호출하려면 해당 함수가 메모리 어디에 있는지 기록된 심볼 테이블(주소록)이 필요함. 크로스 컴파일을 위해 다운로드한 라즈베리파이 커널 소스 트리(`rpi-linux`)가 단 한 번도 전체 빌드(Full Build)를 거치지 않은 '초기 상태'였기 때문에 `Module.symvers` 파일이 존재하지 않아서 발생한 문제.

* **해결 방안**: 커널 소스 디렉토리에서 호스트 PC의 코어를 모두 사용하여 1회 쾌속 빌드를 수행, 심볼 테이블을 강제 생성함.

```bash
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc)
```

이후 모듈 디렉토리로 돌아와 재빌드(`make`)한 결과, 에러 없이 `hello.ko`가 정상적으로 생성됨.

### Issue 2: 타겟 보드와 다운로드한 커널 소스 간의 `Sublevel` 버전 불일치
* **현상**: 타겟 보드에서 `Invalid module format` 에러 발생. `modinfo` 확인 결과 타겟 보드는 `6.12.75` 이나, 깃허브에서 클론한 최신 커널 소스는 `6.12.91`로 버전 불일치 발생.
* **제약 사항**: 타겟 보드는 공유 장비이므로 커널 버전을 최신(`6.12.91`)으로 업데이트할 수 없는 상황.
* **해결 방안**: 마이너 버전(Sublevel) 차이이므로, 호스트 PC의 커널 소스 환경을 셋업할 때 Makefile의 변수를 `6.12.75`로 강제 조작(Spoofing)하여 빌드 환경을 구성함.

```bash
# 커널 소스 디렉토리에서 버전 강제 변조 주입
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- VERSION=6 PATCHLEVEL=12 SUBLEVEL=75 EXTRAVERSION="+rpt-rpi-v8" LOCALVERSION="" modules_prepare

# 모듈 클린 빌드
make clean
make
```
### Issue 3: 버전 매직 끝에 `+` 기호가 강제로 붙는 현상 (Dirty Tree)
* **현상**: 모듈 버전이 `6.12.75+rpt-rpi-v8+` 로 끝에 `+`가 붙어 로드 거부됨.
* **원인 분석**: 커널 내부의 `scripts/setlocalversion` 스크립트가 작동한 결과임. Git으로 관리되는 커널 소스에서 파일(`.config`)이 수정된(Dirty) 상태로 빌드를 시도하면, 커널이 '원본이 아닌 수정된 소스'임을 명시하기 위해 강제로 버전 끝에 `+`를 추가함.
* **해결 방안**: 커널 소스 디렉토리 내의 `.git` 폴더를 강제로 삭제(`rm -rf .git`)하여 Git 추적 자체를 원천 차단하고 재빌드하여 `+` 기호를 제거함.

### Issue 4: `disagrees about version of symbol` 에러 (CRC 지문 불일치)
* **현상**: `vermagic` 문자열을 완벽히 맞췄음에도 타겟 보드에서 `Invalid module format` 에러 발생. `dmesg` 확인 결과 내부 함수 심볼(`module_layout` 등)의 버전 불일치 에러 로그가 확인됨.
* **원인 분석**: 커널의 `CONFIG_MODVERSIONS` 보안 옵션 때문. 마이너 버전 차이(75 vs 91)로 인해 커널 내부 함수의 구조체 배치나 파라미터가 미세하게 달라 해시값(CRC) 지문이 일치하지 않음.
* **해결 방안**: 타겟 보드에 공식 헤더를 설치한 뒤, 생성된 커널 설정 파일(`.config`)과 심볼 지문 원본 파일(`Module.symvers`)을 호스트 PC로 덮어씌워 뼈대를 재구성함.

```bash
# 1. 타겟 보드 (Raspberry Pi)에서 헤더 설치
sudo apt update
sudo apt install linux-headers-$(uname -r)

# 2. 호스트 PC (Ubuntu)에서 원본 데이터 복사 및 뼈대 재구성
scp <USER_NAME>@<TARGET_IP>:/lib/modules/6.12.75+rpt-rpi-v8/build/.config ./.config
scp <USER_NAME>@<TARGET_IP>:/lib/modules/6.12.75+rpt-rpi-v8/build/Module.symvers ./Module.symvers
make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- VERSION=6 PATCHLEVEL=12 SUBLEVEL=75 EXTRAVERSION="+rpt-rpi-v8" modules_prepare
```

이후 모듈을 클린 빌드하여 타겟 보드와 버전 및 CRC가 100% 일치하는 모듈 생성 및 적재 성공.