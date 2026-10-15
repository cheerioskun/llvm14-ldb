# Memcached 1.6.19 with LDB

## Building Memcached
1. Download and extract Memcached-1.6.19.tar.gz
  * ``wget https://memcached.org/files/memcached-1.6.19.tar.gz``
  * ``tar -xvzf memcached-1.6.19.tar.gz``

2. (Optional) For per-request tagging, apply patch
  * ``patch -ruN -d memcached-1.6.19 < LLVM_DIR/apps/memcached-1.6.19/memcached-1.6.19.patch``

3. Configure Memcached
  * ``cd memcached-1.6.19``
  * ``memcached-1.6.19> ./configure``

4. Replace Makefile with the one for LDB
  * ``memcached-1.6.19> cp LLVM_DIR/apps/memcached-1.6.19/Makefile ./``

5. Make sure ROOT\_PATH in Makefile is set correctly to the LLVM root directory.

6. Build with Makefile
  * ``memcached-1.6.19> make``

7. Execute Memcached with LDB libary preloaded (Note that core 0 is used for Stack Scanner and core 1 is for Logger by default)
  * ``LD_PRELOAD=LLVM_DIR/libldb/libshim.so taskset 0xfffc ./memcached -p 16636 -v -m 10240 --threads=8`` 

## Small memtier integration

The Mahoraga setup/run recipes use Memcached 1.6.19 with this patch and memtier
2.5.2, one binary-protocol connection, and bounded localhost workloads:
https://github.com/cheerioskun/mahoraga/tree/bootstrap/research-workspace/infra/ldb

Unmodified memtier leaves request opaque IDs at zero. The optional small client
patch in those recipes adds connection-local sequential IDs for a SET-only trace.
Those IDs are not globally unique across connections or separate processes.

The tested server configuration uses localhost port 16636, UDP disabled, a
64 MiB cache, and four workers. LDB raw output/parser formats remain unchanged.
Integration results do not establish a reproduced performance experiment.

### Response-owned LDB context

After applying `memcached-1.6.19.patch`, apply `response-context.patch` with
`patch -p1 < /path/to/response-context.patch` in the extracted source directory.
Rebuild every application object because the response structure changes. For a
separate source directory, pass `ROOT_PATH=/absolute/path/to/llvm14-ldb` to make.

The binary opaque ID is saved on the response object after a complete command
header/key is available. TCP transmission restores a sole response's ID and
clears it on return, including partial-write retries. Multiple queued responses
are deliberately unassigned; batching and wire behavior are unchanged. TAG
intervals may be disjoint segments of one request, not a continuous wall-time
span. Callback exit clears context before the worker handles other connections.
UDP, ASCII and shared batch attribution are not covered by this integration.
