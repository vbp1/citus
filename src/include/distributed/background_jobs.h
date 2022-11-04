/*-------------------------------------------------------------------------
 *
 * background_jobs.h
 *	  Functions related to running the background tasks queue monitor.
 *
 * Copyright (c) Citus Data, Inc.
 *
 *-------------------------------------------------------------------------
 */

#ifndef CITUS_BACKGROUND_JOBS_H
#define CITUS_BACKGROUND_JOBS_H

#include "postgres.h"

#include "postmaster/bgworker.h"

#include "distributed/metadata_utility.h"

/*
 * BackgroundMonitorExecutionStates encodes execution states in FSM for Background task monitor
 */
typedef enum BackgroundMonitorExecutionStates
{
	ExecutionStarted,
	TaskConcurrentCancelCheck,
	TryConsumeTaskWorker,
	TaskHadError,
	TaskEnded,
	ExecutionEnded
} BackgroundMonitorExecutionStates;

/*
 * BackgroundExecutorHashEntry hash table entry to refer existing task executors
 */
typedef struct BackgroundExecutorHashEntry
{
	/* hash key must be the first to hash correctly */
	int64 taskid;

	BackgroundWorkerHandle *handle;
	dsm_segment *seg;
	StringInfo message;
} BackgroundExecutorHashEntry;


/*
 * QueueMonitorExecutionContext is used for background worker failure handling and allocations
 */
typedef struct QueueMonitorExecutionContext
{
	/* current total # of parallel task executors */
	int64 currentExecutorCount;

	/* last background allocation failure timestamp */
	TimestampTz backgroundWorkerFailedStartTime;

	/* context for monitor related allocations */
	MemoryContext ctx;
} QueueMonitorExecutionContext;

extern BackgroundWorkerHandle * StartCitusBackgroundTaskQueueMonitor(Oid database,
																	 Oid extensionOwner);
extern void CitusBackgroundTaskQueueMonitorMain(Datum arg);
extern void CitusBackgroundTaskExecutor(Datum main_arg);

extern Datum citus_job_cancel(PG_FUNCTION_ARGS);
extern Datum citus_job_wait(PG_FUNCTION_ARGS);
extern Datum citus_task_wait(PG_FUNCTION_ARGS);
extern void citus_job_wait_internal(int64 jobid, BackgroundJobStatus *desiredStatus);
extern void citus_task_wait_internal(int64 taskid, BackgroundTaskStatus *desiredStatus);

#endif /*CITUS_BACKGROUND_JOBS_H */
