/* SPDX-License-Identifier: GPL-2.0-or-later */

/*
 * Copyright (C) 2024 RAS Daemon Tracing Infrastructure
 *
 * Function call tracing using ftrace trace_marker for unified
 * kernel/userspace tracing.
 */

#ifndef __RAS_DAEMON_TRACE_H
#define __RAS_DAEMON_TRACE_H

#include <stdio.h>
#include <stdarg.h>

/* Trace marker file descriptor */
extern int ras_trace_fd;

/* Function prototypes */
int ras_trace_init(void);
void ras_trace_cleanup(void);
void ras_trace_mark(const char *fmt, ...);

/* Tracing macros - write to ftrace trace_marker */
#define RAS_TRACE_INIT() ras_trace_init()
#define RAS_TRACE_CLEANUP() ras_trace_cleanup()

#define RAS_TRACE_ENTRY() \
    ras_trace_mark("%s: entry", __func__)

#define RAS_TRACE_EXIT(ret) \
    ras_trace_mark("%s: exit ret=%d", __func__, (int)(ret))

#define RAS_TRACE_LOG(fmt, ...) \
    ras_trace_mark("%s: " fmt, __func__, ##__VA_ARGS__)

#endif /* __RAS_DAEMON_TRACE_H */
