# 📖 [커널 이론] ftrace와 디버깅 패치 아키텍처

## 1. 커널 디버깅의 두 가지 축
커널 패닉이나 알 수 없는 드라이버 오동작 발생 시, 현업에서는 거시적 분석(ftrace)과 미시적 분석(디버깅 패치)을 병행한다.

### A. 디버깅 패치 (Debugging Patch)
* **개념**: 특정 분기문이나 에러 발생 예상 지점에 `dump_stack()` 등의 추적 코드를 강제로 삽입(개복 수술)하여 빌드하는 원초적 디버깅 기법.
* **장점**: 특정 변수 값이나 예외 조건이 발동하는 '정확한 그 순간'을 핀포인트로 잡아낼 수 있음.
* **단점**: 코드를 수정하고 타겟 보드에 다시 적재해야 하는 번거로움이 존재.

### B. ftrace (Function Tracer)
* **개념**: 소스코드 수정 없이 커널 내부 메모리 버퍼(Ring Buffer)를 활용해 함수 호출 흐름과 소요 시간을 실시간으로 녹화하는 내장 인프라 (엑스레이 촬영).
* **장점**: 빌드 및 전송 과정 없이 즉각적인 추적이 가능하며, 시스템 크래시 직전의 메모리 덤프에서 호출 흐름을 건져낼 수 있음.
* **단점**: 추적 범위를 넓게 잡으면 오버헤드가 발생하여 시스템이 느려질 수 있음.

## 2. 현업 트러블슈팅 파이프라인
1. `ftrace`를 활성화하여 시스템 셧다운 직전에 호출된 **마지막 함수**를 찾아낸다.
2. `egrep -nr`을 통해 해당 커널 함수의 **소스코드 위치**를 특정한다.
3. 특정된 소스코드에 `dump_stack()`이나 임시 로그를 심는 **디버깅 패치**를 적용하여 어떤 변수 값이 문제를 일으켰는지 최종 확인한다.

## 3. ftrace 실전 셋업 파이프라인 (검증 및 필터링)
스크립트를 맹목적으로 실행하기 전, 현재 커널(타겟 보드)에서 지원하는 트레이서와 이벤트를 확인하고 정밀하게 타겟팅하는 현업 필수 과정이다.

### Step 1: 지원 여부 검증 (Search)
커널이 해당 함수나 이벤트를 추적할 수 있도록 컴파일되어 있는지 `available_*` 파일들을 통해 사전 확인한다.

* **트레이서 확인:** `cat /sys/kernel/debug/tracing/available_tracers`
  * (주로 `function`, `function_graph`, `nop` 등이 출력되는지 확인)
* **함수 필터 확인:** 타겟 함수가 인라인(inline)화 등의 최적화로 날아가지 않았는지 검증.
  * `grep "do_init_module" /sys/kernel/debug/tracing/available_filter_functions`
* **이벤트 확인:** 스케줄링, 인터럽트 등 커널 내부의 특정 사건(Event) 지원 여부 검증.
  * `grep "sched_switch" /sys/kernel/debug/tracing/available_events`

### Step 2: 트레이서 및 필터 지정 (Select & Filter)
검증이 끝난 대상을 조종석에 세팅한다. (`tracing_on`이 0인 상태에서 진행)

* **메인 트레이서 장착:**
  * `echo function > /sys/kernel/debug/tracing/current_tracer` (함수 추적기 장착)
  * (초기화할 때는 `echo nop > current_tracer` 사용)
* **함수 필터링 (Function):** 수만 개의 커널 함수 중 타겟 함수만 캡처하도록 제한.
  * `echo do_init_module > /sys/kernel/debug/tracing/set_ftrace_filter`
* **이벤트 필터링 (Events):** 특정 사건이 발생할 때만 로그를 남기도록 개별 스위치 ON.
  * (먼저 전체 이벤트를 끈다) `echo 0 > /sys/kernel/debug/tracing/events/enable`
  * (특정 이벤트만 켠다) `echo 1 > /sys/kernel/debug/tracing/events/sched/sched_switch/enable`

### Step 3: 녹화 시작 (Record)
모든 세팅이 끝난 후, 에러 유발 직전에 마스터 스위치를 켠다.
* `echo 1 > /sys/kernel/debug/tracing/tracing_on`