#!/bin/bash
# 여행사이트 Supabase 무료플랜 '자동 정지' 예방용 깨우기 핑.
# Supabase 무료 프로젝트는 1주(7일) 미접속 시 일시정지된다. launchd가 3일마다
# 이 스크립트를 돌려 REST API를 가볍게 한 번 읽어 활동을 발생시켜 정지를 막는다.
# 데이터는 건드리지 않고 select만(읽기 전용). 실패해도 다음 주기에 재시도.
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"

REPO="$HOME/projects/travel"
LOG="$REPO/logs/keep-alive.log"
mkdir -p "$REPO/logs"

URL='https://rtueiiwaulmpazrdzwld.supabase.co/rest/v1/trips?select=id&limit=1'
KEY='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ0dWVpaXdhdWxtcGF6cmR6d2xkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODEwMjI2MTQsImV4cCI6MjA5NjU5ODYxNH0.Ki8sigtxs4OTMJNFEaBA8b2ldRc3nlqxN4Y6FwJUeQw'

TS="$(date '+%Y-%m-%d %H:%M:%S')"
CODE="$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$URL" -H "apikey: $KEY" -H "Authorization: Bearer $KEY" 2>/dev/null)"

if [ "$CODE" = "200" ]; then
  echo "[$TS] OK ($CODE) — 깨우기 성공, 정지 예방됨" >> "$LOG"
else
  echo "[$TS] WARN ($CODE) — 응답 이상. 다음 주기 재시도" >> "$LOG"
fi
# 로그가 너무 커지지 않게 최근 200줄만 유지
tail -n 200 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG" 2>/dev/null || true
