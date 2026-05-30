# 🚀 Linux Kernel Core Mastery (2주 속성 실전반)

본 리포지토리는 도서 <b>[리눅스 커널의 구조와 원리 1, 2권]</b>을 기반으로, 현업에서 요구하는 핵심 커널 디버깅 및 디바이스 드라이버 개발 역량을 단기간(2주)에 마스터하기 위한 실습 및 트러블슈팅 기록입니다.

단순한 이론 공부를 넘어, 호스트 PC에서 크로스 컴파일을 수행하고 타겟 보드(Raspberry Pi 4)에 동적으로 모듈을 적재(insmod)하며 발생하는 다양한 이슈들을 해결하는 과정을 담고 있습니다.

## 💻 개발 및 테스트 환경 (Development Environment)
버전이 1자리만 달라도 동작이 달라지는 커널의 특성상, 철저하게 통제된 환경에서 실습을 진행합니다.

* **Target Board:** `Raspberry Pi 4 Model B (4GB) - ARM64`
* **Target OS:** `Raspberry Pi OS` (64-bit)
* **Kernel Version:** `6.12.75+rpt-rpi-v8` (최신 분기)
* **Host OS:** `Ubuntu 24.04 LTS` (Docker Container)
* **Cross-Compiler:** `aarch64-linux-gnu-gcc`
* **SSH & Terminal:** `MobaXterm`
* **Network Analysis:** `tcpdump` (Target) + `Wireshark` (Host)

## 📂 디렉토리 구조 및 전체 목차 (Table of Contents)
현업 디바이스 드라이버 개발에 즉시 투입될 수 있도록 핵심 코어 위주로 커리큘럼을 재구성했습니다.

### Phase 1: 커널 모듈과 디버깅 (Environment & Debugging)
- [x] **`00_env_setup/`**: 크로스 컴파일 환경 구축 및 커널 소스 트리(Module.symvers) 동기화
- [x] **`01_hello_module/`**: 기본 커널 모듈 제작 및 적재 실습
- [x] **`02_ftrace_debugging/`**: 커널 내부 함수 호출 흐름 추적 (현업 필수 디버깅 툴)

### Phase 2: 코어 서브시스템 분석 (Core Subsystems)
- [ ] **`03_process_thread/`**: 태스크(Task) 생성 및 스케줄링 이론/실습
- [ ] **`04_interrupt/`**: 하드웨어 인터럽트(IRQ) 처리 구조 및 핸들러 등록
- [ ] **`05_synchronization/`**: 멀티코어 환경의 동기화 기법 (Spinlock, Mutex)
- [ ] **`06_deferred_work/`**: 후반부 처리 기법 (Workqueue, Tasklet)

---
*💡 각 디렉토리 내부에는 실습 소스 코드(`.c`, `Makefile`)와 함께, 에러 해결 과정을 담은 `README.md`가 포함되어 있습니다.*