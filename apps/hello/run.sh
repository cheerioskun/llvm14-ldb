#!/usr/bin/env bash
# Compile and validate a short integration smoke; no scheduler recording.
set -euo pipefail
sample_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ldb_root=$(cd "$sample_dir/../.." && pwd)
tools_dir=${LDB_TOOLS_DIR:-$(dirname "$ldb_root")/ldb-tools}
runs_dir=${LDB_RUNS_DIR:-$(dirname "$ldb_root")/ldb-runs}
export PATH="$HOME/.local/bin:$PATH"
export UV_CACHE_DIR="$tools_dir/uv-cache"
parser_python="$tools_dir/venv/bin/python"
command -v uv >/dev/null
test -x "$parser_python"
shm_key=$(printf '0x%08x' 401916)
if ! ipcs -m | awk -v key="$shm_key" '$1 == key && $6 > 0 {exit 1}'; then
    printf 'Another LDB instance is attached to %s; stop before running.\n' "$shm_key" >&2
    exit 1
fi
mkdir -p "$runs_dir"
run_dir=$(mktemp -d "$runs_dir/hello-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")
printf 'Run directory: %s\n' "$run_dir"
trap 'result=$?; printf "%s\n" "$result" > "$run_dir/exit-status.txt"' EXIT
{
    set -x
    git -C "$ldb_root" rev-parse HEAD
    git -C "$ldb_root" status --short
    uname -srm
    uv --version
    uv pip freeze --python "$parser_python"
    make -C "$sample_dir"
    cp -a "$sample_dir/hello" "$sample_dir/hello.c" "$run_dir/"
    cd "$run_dir"
    timeout 15s taskset -c "${HELLO_CPU:-4}" env LD_PRELOAD="$ldb_root/libldb/libshim.so" ./hello > stdout.txt 2> stderr.txt
    grep -F 'hello: completed 10 tagged requests' stdout.txt
    test -s maps.data
    uv run --no-project --python "$parser_python" python - <<'PY'
from collections import Counter
from pathlib import Path
import struct
record = struct.Struct('<IIIIQQQ')
data = Path('ldb.data').read_bytes()
assert data and len(data) % record.size == 0, 'Empty or incomplete LDB records'
events = list(record.iter_unpack(data))
counts = Counter(e[0] for e in events)
tags = [e[4] for e in events if e[0] == 2]
assert tags == list(range(1, 11)), f'Unexpected request tags: {tags}'
assert counts[5] == 10, f'Expected 10 tag clears, got {counts[5]}'
assert counts[1] > 0, 'No stack samples'
assert all(e[2] < 1_000_000_000 for e in events), 'Invalid timestamp fraction'
Path('records.txt').write_text(f'records={len(events)}\nevent_counts={dict(counts)}\ntags={tags}\n')
print(Path('records.txt').read_text())
PY
    uv run --no-project --python "$parser_python" "$ldb_root/scripts/parse_summary.py" ./hello > summary.txt
    grep -F hello_work summary.txt
    uv run --no-project --python "$parser_python" "$ldb_root/scripts/parse_req.py" ./hello 1 > request-1.txt
    test -s request-1.txt
    sha256sum hello hello.c ldb.data maps.data stdout.txt stderr.txt records.txt summary.txt request-1.txt > SHA256SUMS
} > "$run_dir/commands.log" 2>&1
printf 'PASS: %s\n' "$run_dir"
