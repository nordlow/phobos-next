/** Check stack address usage for a simplistic function.
   Run:
   - TCC:   tcc -O2 -run stackaddr.c
   - TCC:   tcc -O2 stackaddr.c -o stackaddr && ./stackaddr
   - GCC:   gcc -O2 stackaddr.c -o stackaddr && ./stackaddr
   - Clang: clang-17 -O2 stackaddr.c -o stackaddr && ./stackaddr
 */
#include <stdio.h>

void *last_ptr = NULL;

#define T unsigned int

T f(T x) {
  void *stack_ptr;
  // Inline assembly to fetch the stack pointer value
  __asm__("movq %%rsp, %0" : "=r"(stack_ptr));
  printf("Address:%p\n", stack_ptr);
  if (last_ptr != NULL)
	printf("Change:%lu bytes\n", last_ptr - stack_ptr);
  last_ptr = stack_ptr;
  if (x == 0)
    return 0;
  return f(x - 1) + 1;
}

int main() {
  f(3);
  return 0;
}
