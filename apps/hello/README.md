# Small LDB integration smoke

This C program emits ten request tags, each around a named function that sleeps
for 10 ms. It exercises compiler instrumentation, runtime logging, and parsing.
It is not a scheduler recording or latency experiment.

Prerequisites: custom compiler at build/bin/clang, libldb built, uv on PATH,
and pyelftools==0.29 in the parser venv. Mahoraga maintains the plain worker
setup/build commands at https://github.com/cheerioskun/mahoraga/tree/bootstrap/research-workspace/infra/ldb.

Run from anywhere:

```bash
bash /path/to/llvm14-ldb/apps/hello/run.sh
```

Default tooling and output directories are ldb-tools and ldb-runs next to the
checkout. Override with LDB_TOOLS_DIR and LDB_RUNS_DIR if needed. Default
application CPU is 4 (HELLO_CPU overrides it); the existing LDB runtime pins
monitor/logger threads to CPUs 0/1. Adapt this choice to the worker topology.

The runner saves commands, stdout/stderr, raw events, maps, parser outputs,
record counts, exit status, and checksums in a fresh hello-* directory. It checks
all ten tags and clears, complete records, stack samples, and hello_work function
attribution. It refuses to overlap an attached LDB shared-memory instance.
Failure artifacts remain in their run directory. The workload has a 15-second
timeout. Full clock alignment, event-loss validation, and scheduler-state
reconstruction require separate experiments.
