# 📖 [커널 이론] printk 로그 레벨과 커널 코어 패치 사이클

## 1. 커널 로깅의 철학: `printk`와 `dump_stack`의 양면성

### 🚨 무거운 연산 (Heavy Operation)
유저 스페이스의 `printf`와 달리, 커널 스페이스의 `printk`와 `dump_stack`은 시스템에 막대한 부하를 주는 매우 무거운(Heavy) 연산이다. 
* **인터럽트 지연:** 로그를 콘솔이나 UART(시리얼)로 출력하는 동안, 커널은 데이터의 무결성을 위해 일시적으로 인터럽트를 차단(Lock)하거나 하드웨어의 느린 전송 속도를 대기해야 한다.
* **하이젠버그(Heisenbug) 유발:** 타이밍이 생명인 고성능 영상/네트워크 드라이버에 디버깅용 `printk`를 남발할 경우, 출력 지연 시간으로 인해 시스템의 타이밍이 틀어져 멀쩡하던 장비가 뻗거나 죽던 장비가 살아나는 현상이 발생한다. (타이밍과 흐름 추적에는 가벼운 `ftrace`를 우선적으로 사용하는 이유)

### 💡 그럼에도 사용하는 이유
* **상태(데이터) 확인:** 특정 시점의 변수 값이나 구조체 내부 데이터(Payload Size, Channel ID 등)를 핀포인트로 확인하려면 필수적이다.
* **커널 패닉(Panic) 대응:** 시스템이 완전히 뻗어버려 `ftrace` 메모리 버퍼조차 날아가는 치명적 상황에서, 죽기 직전 시리얼 포트로 뿜어내는 `printk` 로그가 디버깅의 유일한 단서가 된다.

## 2. printk 로그 레벨 (Log Level) 제어
커널은 중요도에 따라 8단계의 로그 레벨을 제공하며, 현재 시스템의 설정(Console Loglevel)보다 높은 중요도의 로그만 화면에 즉각 출력하고 나머지는 메모리(`dmesg`)에만 조용히 기록한다.

* `KERN_EMERG` (0): 시스템이 사용 불가능한 상태 (최고 중요도)
* `KERN_ERR` (3): 에러 조건 (하드웨어 제어 실패 등)
* `KERN_WARNING` (4): 경고 상황
* `KERN_INFO` (6): 단순 정보 메시지 (일반적인 모듈 로드 확인용)
* `KERN_DEBUG` (7): 디버깅 메시지 (최하 중요도)

## 3. 현업 커널 본체(Core) 패치 및 테스트 사이클
모듈(`LKM`)이 아닌 커널 본체(예: `init/main.c`)를 직접 수정하여 시스템의 뇌를 교체하는 전체 파이프라인.

1. **원본 백업 및 수정:** `cp main.c main.c.orig` 백업 후 타겟 함수(`rest_init` 등)에 `printk(KERN_EMERG ...)` 코드를 주입.
2. **패치 생성:** `diff -u` 명령어로 원본과 수정본의 차이를 `.patch` 파일로 추출하여 형상 관리.
3. **풀 크로스 컴파일:** 호스트 PC에서 전체 코어를 `-j$(nproc)` 옵션으로 크로스 컴파일하여 `Image` (또는 `kernel8.img`) 바이너리 생성.
4. **가상 환경(QEMU) 검증:** 실제 타겟 보드(Target Board)에 플래싱(Flashing)하기 전, 타겟이 없거나 펌웨어 벽돌(Bricking) 위험이 있는 원격 환경에서는 QEMU 에뮬레이터를 통해 가상의 ARM64 보드를 띄워 안전하게 부팅 로그를 검증한다.

```bash
qemu-system-aarch64 -machine virt -cpu cortex-a72 -smp 4 -m 2048 -nographic -kernel arch/arm64/boot/Image -append "console=ttyAMA0 loglevel=8"
```

#### 🔍 QEMU 명령어 핵심 옵션 해부
우분투 터미널 안에서 가상의 라즈베리파이(ARM64 보드)를 물리적으로 조립하는 과정과 같다.

* `qemu-system-aarch64`: 64비트 ARM 아키텍처(AArch64) 전용 QEMU 에뮬레이터를 실행한다.
* `-machine virt`: 특정 하드웨어(보드)에 종속되지 않는 범용 가상 머신(Virtual Machine) 플랫폼을 사용한다.
* `-cpu cortex-a72`: 라즈베리파이 4의 실제 두뇌인 Cortex-A72 CPU를 가상으로 장착한다.
* `-smp 4`: Symmetric Multi-Processing. 가상 CPU 코어를 4개 할당하여 쿼드코어 환경을 구성한다.
* `-m 2048`: 가상 보드에 2048MB(2GB)의 RAM(메모리)을 꽂아준다.
* `-nographic`: 별도의 QEMU 그래픽 창(GUI)을 띄우지 않고, 현재 명령어를 입력한 터미널 화면을 가상 보드의 모니터처럼 직접 연결한다. (현업 서버 환경에서 필수)
* `-kernel arch/arm64/boot/Image`: 가상 보드가 전원을 켤 때 읽어 들일 커널 본체(뇌)의 경로를 지정한다. 부트로더를 건너뛰고 커널을 다이렉트로 로드한다.
* `-append "console=ttyAMA0 loglevel=8"`: 커널에게 전달하는 부팅 파라미터.
  * `console=ttyAMA0`: 커널의 메인 출력 화면을 첫 번째 시리얼 포트(ttyAMA0)로 지정한다. (`-nographic`과 결합되어 터미널에 로그를 뿌림)
  * `loglevel=8`: 커널의 화면 출력 제한을 완전히 해제하여, 가장 사소한 디버깅 로그(`KERN_DEBUG`)부터 치명적 에러까지 남김없이 화면에 쏟아내도록 강제한다.