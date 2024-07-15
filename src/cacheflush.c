void cacheflush(void const *start, int bytes) {
#if defined(__x86_64__) || defined(_M_X64) || defined(i386) || defined(__i386__) || defined(__i386) || defined(_M_IX86)
    void const *end = start + bytes;
    while (start < end) {
        asm volatile("clflush %[ptr]"
                     :
                     : [ptr] "m"(start)
                     : "memory");
        start += 32;
    }
#elif defined(__aarch64__) || defined(_M_ARM64)
    __builtin___clear_cache(start, start + bytes);
#else
#error "no way to clear cache"
#endif
}
