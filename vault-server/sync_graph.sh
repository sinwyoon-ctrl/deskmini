#!/bin/bash
# 볼트 지식 그래프 갱신(헤드리스). cron·수동 모두 가능.
# 보류 중. 노트 200개 또는 질문 10건 중 5건이 원문 탐색 8천 토큰 초과 시 야간 1회 시험(아스트라 10/29)
# graphify CLI 에는 'parse' 가 없다. 전체 파이프라인은 'extract' 이고,
# 의미 추출 LLM 은 로그인된 claude CLI(--backend claude-cli)를 쓴다(API 키 불필요).
# 산출물: graphify-out/graph.json, graphify-out/GRAPH_REPORT.md
set -u
VAULT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$VAULT_DIR"
export PATH="$HOME/.local/share/vault-graph/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"
# 추출 속도 설정(10/29): 중첩 claude 는 MCP 없이(래퍼), 모델 Sonnet, 병렬 3, 덩어리 작게, 호출 제한 15분
export GRAPHIFY_CLAUDE_CLI_MODEL="${GRAPHIFY_CLAUDE_CLI_MODEL:-sonnet}"
export GRAPHIFY_CLAUDE_CLI_PARALLEL=1
export GRAPHIFY_API_TIMEOUT="${GRAPHIFY_API_TIMEOUT:-900}"
EXTRACT_OPTS=(--max-concurrency 3 --token-budget 12000)
# Claude Code 세션 안에서 실행해도 중첩 세션 거부가 나지 않도록 세션 변수 제거
for v in $(env | grep -o '^CLAUDE[A-Z_]*'); do unset "$v"; done

echo "[Graphify] Updating Knowledge Graph..."
# 1) 추출(AST + 의미) -> graph.json   2) 군집 이름 붙이기 -> GRAPH_REPORT.md
if ! graphify extract . --backend claude-cli "${EXTRACT_OPTS[@]}" "$@"; then
  echo "[Graphify] extract failed" >&2; exit 1
fi
if ! graphify cluster-only . --backend claude-cli --no-viz; then
  echo "[Graphify] cluster-only failed" >&2; exit 1
fi
# 3) 이름 없는(새) 커뮤니티에만 이름 붙이기. cluster-only 는 저장된 이름을 재사용하므로 이 단계가 필요하다.
graphify label . --missing-only --backend claude-cli || echo "[Graphify] label 실패(그래프는 유효, 이름만 자리표시)" >&2
echo "[Graphify] Graph update complete."
ls -l graphify-out/graph.json graphify-out/GRAPH_REPORT.md
