#include <dlfcn.h>
#include <stdio.h>
#include <string.h>

int main(void) {
    char line[1024];
    int missing = 0;
    while (fgets(line, sizeof line, stdin)) {
        line[strcspn(line, "\n")] = 0;
        char *tab = strchr(line, '\t');
        if (!tab) continue;
        *tab = 0;
        const char *symbol = tab + 1;
        if (*symbol == '_') symbol++;
        void *handle = dlopen(line, RTLD_LAZY);
        if (!handle || !dlsym(handle, symbol)) {
            printf("MISSING %s in %s\n", tab + 1, line);
            missing++;
        }
    }
    printf("%d missing\n", missing);
    return missing != 0;
}
