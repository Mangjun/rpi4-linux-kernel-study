# 🔬 [02] 커널 ftrace 디버깅 및 소스코드 추적

## 1. 개요
* **목표:** 커널 소스코드를 수정하지 않고 내장된 Function Tracer(ftrace)를 활용하여 모듈 적재 시 발생하는 커널 내부의 함수 호출 흐름(Call Stack)을 실시간으로 추적한다.
* **핵심 도구:** `debugfs`, `ftrace`, `egrep`

## 2. ftrace 자동화 셋업 스크립트
매번 복잡한 경로를 타이핑하는 실수를 방지하고, 타겟 함수(`do_init_module`)를 정확히 필터링하기 위해 쉘 스크립트를 작성하여 조종석을 세팅함.

**`ftrace_setup.sh`**
```bash
#!/bin/bash

TRACE_DIR="/sys/kernel/debug/tracing"

echo "1. ftrace 초기화 및 정지..."
echo 0 > $TRACE_DIR/tracing_on
sleep 1

echo 0 > $TRACE_DIR/events/enable
sleep 1

echo > $TRACE_DIR/trace
sleep 1

echo "2. 타겟 함수 필터 설정..."
echo do_init_module > $TRACE_DIR/set_ftrace_filter
sleep 1

echo "3. 함수 추적기 활성화..."
echo function > $TRACE_DIR/current_tracer
sleep 1

echo "4. 콜스택 및 오프셋 상세 옵션 켜기..."
echo 1 > $TRACE_DIR/options/func_stack_trace
sleep 1

echo 1 > $TRACE_DIR/options/sym-offset
sleep 1

echo "5. ftrace 녹화 시작!"
echo 1 > $TRACE_DIR/tracing_on
sleep 1

echo "✅ 셋업 완료!
```

## 3. 현업 로그 추출 및 추적 기법
ftrace 버퍼의 텍스트를 가독성 있게 추출하고, 커널 소스코드와 매핑하는 과정.

* 로그 추출 스크립트 (`ftrace_dump.sh`): 로그를 .c 확장자로 저장하여 에디터의 C언어 하이라이팅(Syntax Highlighting) 기능을 강제로 활성화, 가독성을 극대화함.
* 소스코드 딥다이브 (`egrep -nr`): ftrace 로그에 찍힌 타겟 함수(예: do_init_module)가 커널 소스 트리 내 어디에 구현되어 있는지 역추적.

```bash
# 커널 최상단 디렉토리에서 실행하여 구현부 파일과 라인 수 탐색
egrep -nr "do_init_module" .
```