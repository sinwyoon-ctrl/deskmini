#!/bin/bash
# 비밀 검사기 단위 시험. 임시 bare+클론을 mktemp 아래에 만든다(삭제하지 않음).
HOOKS="$(cd "$(dirname "$0")" && pwd)"
T=$(mktemp -d); echo "시험 경로: $T"
git init -q --bare -b main "$T/bare.git"
cp "$HOOKS/pre-receive" "$HOOKS/secret-scan.py" "$T/bare.git/hooks/"
chmod +x "$T/bare.git/hooks/pre-receive"
git clone -q "$T/bare.git" "$T/w" 2>/dev/null
cd "$T/w"; git config user.email t@example.test; git config user.name tester
git checkout -q -b main 2>/dev/null
echo "# start" > README.md; git add -A; git commit -qm init
git push -q origin main >/dev/null 2>&1 || { echo "초기 push 실패"; exit 2; }
fails=0
res() { # name expect(0/1 push rc) actual
  if { [ "$2" = ok ] && [ "$3" = 0 ]; } || { [ "$2" = rej ] && [ "$3" != 0 ]; }; then echo "PASS ($1)"; else echo "FAIL ($1)"; fails=$((fails+1)); fi
}
push() { git push origin main >"$T/out.txt" 2>&1; }
reset_to_remote() { git fetch -q origin; git reset -q --hard origin/main; }
SECRET='password = EXAMPLE_TEST_value_1234'

# (a) 중간 커밋 비밀 + 다음 커밋 삭제
echo "$SECRET" > note.md; git add -A; git commit -qm mid
git rm -q note.md; git commit -qm remove
push; res "a 중간 커밋 비밀 2커밋 거절" rej $?; cat "$T/out.txt" | grep -c 'EXAMPLE_TEST' | sed 's/^/  출력에 값 노출 횟수: /'
reset_to_remote
# (b) 깨끗한 push
echo "hello world" > clean.md; git add -A; git commit -qm clean
push; res "b 깨끗한 push 통과" ok $?
# (c) allow 경로
echo "allowed/*.md" > .vault-scan-allow; mkdir -p allowed; echo "$SECRET" > allowed/a.md
git add -A; git commit -qm allow
push; res "c 허용 경로 키=값 통과" ok $?
# (d) 한글 파일명 .env
mkdir -p "한글폴더"; echo "x=1" > "한글폴더/.env"; git add -A; git commit -qm korean
push; res "d 한글 경로 .env 거절" rej $?; grep -q '한글폴더/.env' "$T/out.txt" && echo "  경로 출력 확인"
reset_to_remote
# (e) png
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\x00TEST' > pic.png; git add -A; git commit -qm png
push; res "e png 통과" ok $?
# (f) 미등록 .bin
printf 'BIN\x00\x01\x02TEST' > data.bin; git add -A; git commit -qm bin
push; res "f 미등록 바이너리 거절" rej $?; cat "$T/out.txt" | grep 'data.bin'
reset_to_remote

[ $fails = 0 ] && echo "ALL PASS" || { echo "FAILS: $fails"; exit 1; }
