#!/bin/bash

TRACE_DIR="/sys/kernel/debug/tracing"
CURRENT_TIME=$(date +"%Y%m%d_%H%M%S")
LOG_FILENAME="ftrace_log_${CURRENT_TIME}.c"

echo "1. ftrace 기록 정지..."
echo 0 > $TRACE_DIR/tracing_on
sleep 1

echo "2. 로그 파일을 현재 디렉토리로 추출 중..."
cp $TRACE_DIR/trace ./${LOG_FILENAME}

echo "✅ 추출 완료! 파일명: ${LOG_FILENAME}"