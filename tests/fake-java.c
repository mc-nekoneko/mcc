#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const char *log_path;

static void write_event(const char *event) {
    FILE *log = fopen(log_path, "a");
    if (log == NULL) {
        _exit(2);
    }
    fprintf(log, "%s %d\n", event, getpid());
    fclose(log);
}

static void on_term(int signal_number) {
    (void)signal_number;
    write_event("term");
    _exit(0);
}

int main(int argc, char **argv) {
    if (argc == 2 && strcmp(argv[1], "-version") == 0) {
        return 0;
    }
    log_path = getenv("JAVA_TEST_LOG");
    if (log_path == NULL) {
        return 2;
    }
    signal(SIGTERM, on_term);
    write_event("started");
    for (;;) {
        pause();
    }
}
