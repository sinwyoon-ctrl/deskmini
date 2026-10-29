# vault-server — DeskMini 볼트 정본의 서버 장치 사본

`~/vault.git`(bare 정본)은 git 이 훅을 추적하지 않고, `~/bin` 도 git 밖이라 여기에 사본을 둔다.
볼트 **내용**은 여기 없다(정본 `~/vault.git`, 메인 PC 클론, restic 백업이 사본).

| 원본 위치 | 이 폴더 |
|---|---|
| `~/vault.git/hooks/{pre-receive,post-receive,secret-scan.py,test-secret-scan.sh}` | `hooks/` |
| `~/bin/vault-note`, `~/bin/vault-backup` | `bin/` |
| `~/vault/.claude/settings.local.json` (graphify 훅, 로컬 전용) | `claude-local/` |
| `~/work/vault-spec/SPEC-20261029.md` | `SPEC-20261029.md` |
| `~/vault/sync_graph.sh` (그래프 수동 갱신: extract→cluster-only→label) | `sync_graph.sh` |
| `~/.local/share/vault-graph/bin/claude` (graphify 용 MCP 없는 claude 래퍼) | `bin/claude-mcpless-wrapper` |

## 복원 순서 (디스크 교체 시)
1. `git init --bare -b main ~/vault.git` 뒤 다른 사본(메인 클론·restic)에서 `git push --mirror` 로 내용 복원.
2. `cp hooks/* ~/vault.git/hooks/ && chmod +x ~/vault.git/hooks/*`
3. `git clone ~/vault.git ~/vault` (읽기 전용 거울), `git clone ~/vault.git ~/vault-agent` (에이전트 쓰기용).
   `~/vault-agent/.git/hooks/pre-commit` = `git diff --cached | python3 -I ~/vault.git/hooks/secret-scan.py`
4. `cp bin/* ~/bin/ && chmod +x ~/bin/vault-note ~/bin/vault-backup`
5. `cp claude-local/settings.local.json ~/vault/.claude/`
6. MCP: `claude mcp add -s user obsidian-vault -- npx -y @modelcontextprotocol/server-filesystem /home/ionenet/vault`
   `~/.claude/settings.json` permissions.deny 에 `mcp__obsidian-vault__{write_file,edit_file,create_directory,move_file}`.
7. 그래프(선택): `mkdir -p ~/.local/share/vault-graph/bin && cp bin/claude-mcpless-wrapper ~/.local/share/vault-graph/bin/claude && chmod +x` 뒤 `uv tool install "graphifyy[mcp]"`, `~/vault/sync_graph.sh`. 12문서 기준 40초.
8. 시험: `bash ~/vault.git/hooks/test-secret-scan.sh` 가 ALL PASS.

## 원본을 고쳤으면
원본을 고친 뒤 이 폴더로 다시 복사해 커밋한다(`cp` 표 참고). 반대 방향으로 쓰지 않는다.

## 백업 (restic → 메인 PC D:\vault-backup, 10/29 확정)
- 설정 `~/.config/vault-backup/{env,password,known_hosts}` (git 밖, 600). env 에 MAIN_SSH_HOST·RESTIC_REPOSITORY(sftp)·RESTIC_SFTP_COMMAND(전용 known_hosts 사용). 암호는 대표 비밀번호 관리자에 사본.
- `~/bin/vault-backup` 를 cron 이 09~18시 매시 호출, 하루 1회 성공. 메인 꺼져 있으면 건너뜀. 2일 미성공 시 notify.
- 복원: `restic -o "sftp.command=$RESTIC_SFTP_COMMAND" restore latest --target <폴더>` 뒤 `<폴더>/home/ionenet/vault.git` 을 정본 자리로.
- 메인 호스트 키 지문(ED25519) SHA256:4OxkBL2VakWuRqS3G7bF0CdajTLVzzBSbKwHW/qDBnk — 바뀌면 메인 세션에 확인.
