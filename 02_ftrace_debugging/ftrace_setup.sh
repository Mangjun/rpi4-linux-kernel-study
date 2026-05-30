#!/bin/bash

TRACE_DIR="/sys/kernel/debug/tracing"

echo "1. ftrace 초기화 및 정지..."
echo 0 > $TRACE_DIR/tracing_on # ftrace 정지
sleep 1

echo 0 > $TRACE_DIR/events/enable # ftrace 초기화
sleep 1

echo > $TRACE_DIR/trace # 기존에 쌓인 로그 비우기
sleep 1

echo "2. 타겟 함수 필터 설정..."
# 원하는 함수 호출 스택 보기
# 함수명 > /sys/kernel/debug/tracing/set_ftrace_filter
echo do_init_module > $TRACE_DIR/set_ftrace_filter
sleep 1

echo "3. 함수 추적기 활성화..."
# 함수 필터 trace에 등록
echo function > $TRACE_DIR/current_tracer
sleep 1

echo "4. 콜스택 및 오프셋 상세 옵션 켜기..."
echo 1 > $TRACE_DIR/options/func_stack_trace # Call Stack 옵션 켜기
sleep 1

echo 1 > $TRACE_DIR/options/sym-offset # Offset 옵션 켜기
sleep 1

echo "5. ftrace 녹화 시작!"
echo 1 > $TRACE_DIR/tracing_on # ftrace 시작
sleep 1

echo "✅ 셋업 완료!"
# sudo cat /sys/kernel/debug/tracing/trace 으로 녹화 결과 확인 가능