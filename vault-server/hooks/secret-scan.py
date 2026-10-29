#!/usr/bin/env python3
"""볼트에 비밀·개인정보가 들어오는지 검사한다. stdin 으로 커밋 하나의 unified diff 를 스트리밍으로 받는다.
사용: secret-scan.py [--commit 짧은해시] [--allow-file 경로] [--lines-only]
문제가 있으면 1, 없으면 0. 패턴에 걸린 '값'은 출력하지 않고 커밋·파일·줄번호·종류만 알린다."""
import re, sys, fnmatch

MAX_HITS = 50
FILE_BLOCK = re.compile(r'(^|/)(\.env(\..*)?|.*\.pem|.*\.key|.*\.p12|.*\.pfx|id_rsa.*|id_ed25519.*|credentials.*\.json|.*secrets?\.(json|ya?ml|toml))$', re.I)
SAFE_BINARY = re.compile(r'\.(png|jpe?g|gif|webp|svg|pdf)$', re.I)
CARD = re.compile(r'(?<![\d\-])(?:\d[ \-]?){12,15}\d(?![\d\-])')
PATTERNS = [
    ("Anthropic/OpenAI 키", re.compile(r'\bsk-(ant-)?[A-Za-z0-9_\-]{20,}')),
    ("AWS 액세스 키", re.compile(r'\bAKIA[0-9A-Z]{16}\b')),
    ("GitHub 토큰", re.compile(r'\bgh[pousr]_[A-Za-z0-9]{30,}\b')),
    ("Google API 키", re.compile(r'\bAIza[0-9A-Za-z_\-]{30,}\b')),
    ("Telegram 봇 토큰", re.compile(r'\b\d{8,10}:[A-Za-z0-9_\-]{35}\b')),
    ("개인키 블록", re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----')),
    ("주민등록번호", re.compile(r'(?<!\d)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])-?[1-4]\d{6}(?!\d)')),
    ("키=값 형태 비밀", re.compile(r'(?i)\b(api[_\-]?key|secret[_\-]?key|access[_\-]?token|auth[_\-]?token|password|passwd)\b\s*[:=]\s*["\']?[^\s"\']{8,}')),
]

def luhn_ok(digits):
    total, alt = 0, False
    for ch in reversed(digits):
        d = int(ch)
        if alt:
            d *= 2
            if d > 9: d -= 9
        total += d
        alt = not alt
    return total % 10 == 0

def card_hit(text):
    for m in CARD.finditer(text):
        digits = re.sub(r'\D', '', m.group(0))
        if 13 <= len(digits) <= 16 and luhn_ok(digits):
            return True
    return False

def main():
    commit, allow_file, lines_only = "", None, False
    a = sys.argv[1:]
    i = 0
    while i < len(a):
        if a[i] == '--commit' and i + 1 < len(a): commit = a[i+1]; i += 2
        elif a[i] == '--allow-file' and i + 1 < len(a): allow_file = a[i+1]; i += 2
        elif a[i] == '--lines-only': lines_only = True; i += 1
        else: i += 1
    globs = []
    if allow_file:
        try:
            with open(allow_file, encoding='utf-8', errors='replace') as f:
                globs = [l.strip() for l in f if l.strip() and not l.lstrip().startswith('#')]
        except OSError:
            pass
    hits = []
    def add(f, n, label):
        if len(hits) < MAX_HITS: hits.append((f, n, label))
    st = {"f": None, "deleted": False, "binary": False, "done": False}

    def allowed(f):
        return f is not None and any(fnmatch.fnmatchcase(f, g) for g in globs)

    def finish():
        f = st["f"]
        if f is None or st["deleted"]: return
        if FILE_BLOCK.search(f): add(f, 0, "비밀 파일 이름 자체가 금지")
        if st["binary"] and not SAFE_BINARY.search(f) and not allowed(f):
            add(f, 0, "검토되지 않은 바이너리")

    def begin(f):
        finish()
        st.update(f=f, deleted=False, binary=False)

    lineno = 0
    skip_content = False
    for raw in sys.stdin.buffer:
        line = raw.decode('utf-8', 'replace').rstrip('\n')
        if line.startswith('diff --git '):
            k = line.rfind(' b/')
            begin(line[k+3:] if k >= 0 else None)
            skip_content = False
            lineno = 0
            continue
        if line.startswith('deleted file mode'):
            st["deleted"] = True; continue
        if line.startswith('Binary files ') or line.startswith('GIT binary patch'):
            st["binary"] = True; continue
        if line.startswith('+++ '):
            p = line[4:].split('\t')[0]
            if p == '/dev/null': st["deleted"] = True
            else:
                if p.startswith('b/'): p = p[2:]
                st["f"] = p
            f = st["f"]
            skip_content = bool(f and (SAFE_BINARY.search(f) or allowed(f)))
            continue
        if line.startswith('--- '):
            continue
        if line.startswith('@@'):
            m = re.search(r'\+(\d+)', line); lineno = int(m.group(1)) - 1 if m else 0; continue
        if line.startswith('+'):
            lineno += 1
            if skip_content or st["deleted"]: continue
            text = line[1:]
            for label, pat in PATTERNS:
                if pat.search(text): add(st["f"], lineno, label); break
            else:
                if card_hit(text): add(st["f"], lineno, "카드번호")
        elif not line.startswith('-') and not line.startswith('\\'):
            lineno += 1
    finish()
    if hits:
        if not lines_only:
            print("거절: 비밀·개인정보로 보이는 내용이 있습니다. 값은 표시하지 않습니다.")
        for f, n, label in hits:
            print(f"  {commit} {f}:{n}  {label}")
        sys.exit(1)

main()
