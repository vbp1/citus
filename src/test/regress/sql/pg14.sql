SHOW server_version \gset
SELECT substring(:'server_version', '\d+')::int > 13 AS server_version_above_thirteen
\gset
\if :server_version_above_thirteen
\else
\q
\endif

create schema pg14;
set search_path to pg14;

SET citus.next_shard_id TO 980000;
SET citus.shard_count TO 2;

-- test the new vacuum option, process_toast
CREATE TABLE t1 (a int);
SELECT create_distributed_table('t1','a');
SET citus.log_remote_commands TO ON;
VACUUM (FULL) t1;
VACUUM (FULL, PROCESS_TOAST) t1;
VACUUM (FULL, PROCESS_TOAST true) t1;
VACUUM (FULL, PROCESS_TOAST false) t1;
VACUUM (PROCESS_TOAST false) t1;
SET citus.log_remote_commands TO OFF;

create table dist(a int, b int);
select create_distributed_table('dist','a');
create index idx on dist(a);

set citus.log_remote_commands to on;
-- make sure that we send the tablespace option
SET citus.multi_shard_commit_protocol TO '1pc';
SET citus.multi_shard_modify_mode TO 'sequential';
reindex(TABLESPACE test_tablespace) index idx;
reindex(TABLESPACE test_tablespace, verbose) index idx;
reindex(TABLESPACE test_tablespace, verbose false) index idx ;
reindex(verbose, TABLESPACE test_tablespace) index idx ;
-- should error saying table space doesn't exist
reindex(TABLESPACE test_tablespace1) index idx;
reset citus.log_remote_commands;
-- CREATE STATISTICS only allow simple column references
CREATE TABLE tbl1(a timestamp, b int);
SELECT create_distributed_table('tbl1','a');
-- the last one should error out
CREATE STATISTICS s1 (dependencies) ON a, b FROM tbl1;
CREATE STATISTICS s2 (mcv) ON a, b FROM tbl1;
CREATE STATISTICS s3 (ndistinct) ON date_trunc('month', a), date_trunc('day', a) FROM tbl1;
set citus.log_remote_commands to off;

-- error out in case of ALTER TABLE .. DETACH PARTITION .. CONCURRENTLY/FINALIZE
-- only if it's a distributed partitioned table
CREATE TABLE par (a INT UNIQUE) PARTITION BY RANGE(a);
CREATE TABLE par_1 PARTITION OF par FOR VALUES FROM (1) TO (4);
CREATE TABLE par_2 PARTITION OF par FOR VALUES FROM (5) TO (8);
-- works as it's not distributed
ALTER TABLE par DETACH PARTITION par_1 CONCURRENTLY;
-- errors out
SELECT create_distributed_table('par','a');
ALTER TABLE par DETACH PARTITION par_2 CONCURRENTLY;
ALTER TABLE par DETACH PARTITION par_2 FINALIZE;


-- test column compression propagation in distribution
SET citus.shard_replication_factor TO 1;
CREATE TABLE col_compression (a TEXT COMPRESSION pglz, b TEXT);
SELECT create_distributed_table('col_compression', 'a', shard_count:=4);

SELECT attname || ' ' || attcompression AS column_compression FROM pg_attribute WHERE attrelid::regclass::text LIKE 'col\_compression%' AND attnum > 0 ORDER BY 1;
SELECT result AS column_compression FROM run_command_on_workers($$SELECT ARRAY(
SELECT attname || ' ' || attcompression FROM pg_attribute WHERE attrelid::regclass::text LIKE 'pg14.col\_compression%' AND attnum > 0 ORDER BY 1
)$$);

-- test column compression propagation in rebalance
SELECT shardid INTO moving_shard FROM citus_shards WHERE table_name='col_compression'::regclass AND nodeport=:worker_1_port LIMIT 1;
SELECT citus_move_shard_placement((SELECT * FROM moving_shard), :'public_worker_1_host', :worker_1_port, :'public_worker_2_host', :worker_2_port);
SELECT rebalance_table_shards('col_compression', rebalance_strategy := 'by_shard_count');
CALL citus_cleanup_orphaned_shards();
SELECT result AS column_compression FROM run_command_on_workers($$SELECT ARRAY(
SELECT attname || ' ' || attcompression FROM pg_attribute WHERE attrelid::regclass::text LIKE 'pg14.col\_compression%' AND attnum > 0 ORDER BY 1
)$$) ORDER BY length(result);

set client_min_messages to error;
drop schema pg14 cascade;
