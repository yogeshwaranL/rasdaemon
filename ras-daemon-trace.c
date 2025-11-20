/* SPDX-License-Identifier: GPL-2.0-or-later */

/*
 * Copyright (C) 2024 RAS Daemon Tracing Infrastructure
 *
 * Function call tracing using ftrace trace_marker for unified
 * kernel/userspace tracing.
 */

#include <stdio.h>
#include <stdarg.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

#include "ras-daemon-trace.h"
#include "ras-logger.h"

/* Trace marker file descriptor */
int ras_trace_fd = -1;

/* Trace marker paths to try */
static const char *trace_marker_paths[] = {
    "/sys/kernel/debug/tracing/trace_marker",
    "/sys/kernel/tracing/trace_marker",
    NULL
};

int ras_trace_init(void)
{
    int i;

    for (i = 0; trace_marker_paths[i] != NULL; i++) {
        ras_trace_fd = open(trace_marker_paths[i], O_WRONLY);
        if (ras_trace_fd >= 0) {
            log(TERM, LOG_INFO, "Tracing enabled via %s\n",
                trace_marker_paths[i]);
            return 0;
        }
    }

    log(TERM, LOG_WARNING,
        "Could not open trace_marker. Tracing disabled.\n"
        "Ensure debugfs is mounted: mount -t debugfs none /sys/kernel/debug\n");
    return -1;
}

void ras_trace_cleanup(void)
{
    if (ras_trace_fd >= 0) {
        close(ras_trace_fd);
        ras_trace_fd = -1;
    }
}

void ras_trace_mark(const char *fmt, ...)
{
    va_list args;
    char buf[512];
    int len;

    if (ras_trace_fd < 0)
        return;

    va_start(args, fmt);
    len = vsnprintf(buf, sizeof(buf) - 1, fmt, args);
    va_end(args);

    if (len > 0) {
        buf[len] = '\n';
        write(ras_trace_fd, buf, len + 1);
    }
}
