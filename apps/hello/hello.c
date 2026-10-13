#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "ldb/tag.h"

// Keep a visible frame long enough for the monitor to observe it.
__attribute__((noinline)) void hello_work(void) {
  if (usleep(10000) != 0) {
    perror("hello: usleep");
    abort();
  }
}

int main(void) {
  for (uint64_t request = 1; request <= 10; ++request) {
    ldb_tag_set(request);
    hello_work();
    ldb_tag_clear();
  }
  // Allow the logger to write the final tag before runtime shutdown.
  if (usleep(20000) != 0) return 1;
  puts("hello: completed 10 tagged requests");
  return 0;
}
