-- The test excercises below failure scenarios
--1. Failure while creating publications
--2. Failure while creating shared memory segment
--3. Failure while creating replication slots
--4. Failure while enabling subscription
--5. Failure on polling subscription state
--6. Failure on polling last write-ahead log location reported to origin WAL sender
--7. Failure on disabling subscription (right before dropping it)
--8. Failure on dropping subscription
CREATE SCHEMA "citus_split_test_schema";

CREATE ROLE test_split_role WITH LOGIN;
GRANT USAGE, CREATE ON SCHEMA "citus_split_test_schema" TO test_split_role;
SET ROLE test_split_role;

SET search_path TO "citus_split_test_schema";

SET citus.next_shard_id TO 8981000;
SET citus.next_placement_id TO 8610000;
SET citus.next_operation_id TO 777;
SET citus.next_cleanup_record_id TO 11;
SET citus.shard_count TO 2;
SET citus.shard_replication_factor TO 1;
SELECT pg_backend_pid() as pid \gset

-- Connections on the proxy port(worker_2) are monitored
SELECT nodeid AS worker_1_node FROM pg_dist_node WHERE nodeport=:worker_1_port \gset
SELECT nodeid AS worker_2_node FROM pg_dist_node WHERE nodeport=:worker_2_proxy_port \gset

CREATE TABLE table_to_split(id int PRIMARY KEY, int_data int, data text);
SELECT create_distributed_table('table_to_split', 'id');

\c - postgres - :master_port
-- Create a method to execute TryDropOrphanShards
CREATE OR REPLACE FUNCTION run_try_drop_marked_shards()
RETURNS VOID
AS 'citus'
LANGUAGE C STRICT VOLATILE;

--1. Failure while creating publications
    SELECT citus.mitmproxy('conn.onQuery(query="CREATE PUBLICATION .* FOR TABLE").killall()');
    SELECT pg_catalog.citus_split_shard_by_split_points(
        8981000,
        ARRAY['-100000'],
        ARRAY[:worker_2_node, :worker_2_node],
        'force_logical');
    SELECT * FROM pg_dist_cleanup;

    -- we need to allow connection so that we can connect to proxy
    SELECT citus.mitmproxy('conn.allow()');

    \c - - - :worker_2_proxy_port
    SET search_path TO "citus_split_test_schema", public, pg_catalog;
    SET citus.show_shards_for_app_name_prefixes = '*';
    -- Left over child shards
    SELECT relname FROM pg_class where relname LIKE '%table_to_split_%' AND relkind = 'r';
    -- Left over publications
    SELECT pubname FROM pg_publication;
    -- Left over replication slots
    SELECT slot_name FROM pg_replication_slots;
    -- Left over subscriptions
    SELECT subname FROM pg_subscription;

    \c - postgres - :master_port
    SELECT run_try_drop_marked_shards();
    SELECT * FROM pg_dist_cleanup;

    \c - - - :worker_2_proxy_port
    SET search_path TO "citus_split_test_schema", public, pg_catalog;
    SET citus.show_shards_for_app_name_prefixes = '*';
    -- Empty child shards after cleanup
    SELECT relname FROM pg_class where relname LIKE '%table_to_split_%' AND relkind = 'r';
    -- Empty publications
    SELECT pubname FROM pg_publication;
    -- Empty replication slot table
    SELECT slot_name FROM pg_replication_slots;
    -- Empty subscriptions
    SELECT subname FROM pg_subscription;
--1. Failure while creating publications

--2. Failure while creating shared memory segment
\c - postgres - :master_port
    SELECT citus.mitmproxy('conn.onQuery(query="SELECT \* FROM pg_catalog.worker_split_shard_replication_setup\(.*").killall()');
    SELECT pg_catalog.citus_split_shard_by_split_points(
        8981000,
        ARRAY['-100000'],
        ARRAY[:worker_2_node, :worker_2_node],
        'force_logical');
    SELECT * FROM pg_dist_cleanup;
    -- we need to allow connection so that we can connect to proxy
    SELECT citus.mitmproxy('conn.allow()');

    \c - - - :worker_2_proxy_port
    SET search_path TO "citus_split_test_schema", public, pg_catalog;
    SET citus.show_shards_for_app_name_prefixes = '*';
    -- Left over child shards
    SELECT relname FROM pg_class where relname LIKE '%table_to_split_%' AND relkind = 'r';
    -- Left over publications
    SELECT pubname FROM pg_publication;
    -- Left over replication slots
    SELECT slot_name FROM pg_replication_slots;
    -- Left over subscriptions
    SELECT subname FROM pg_subscription;

    \c - postgres - :master_port
    SELECT run_try_drop_marked_shards();
    SELECT * FROM pg_dist_cleanup;

    \c - - - :worker_2_proxy_port
    SET search_path TO "citus_split_test_schema", public, pg_catalog;
    SET citus.show_shards_for_app_name_prefixes = '*';
    -- Empty child shards after cleanup
    SELECT relname FROM pg_class where relname LIKE '%table_to_split_%' AND relkind = 'r';
    -- Empty publications
    SELECT pubname FROM pg_publication;
    -- Empty replication slot table
    SELECT slot_name FROM pg_replication_slots;
    -- Empty subscriptions
    SELECT subname FROM pg_subscription;
--2. Failure while creating shared memory segment

--3. Failure while executing 'CREATE_REPLICATION_SLOT' for Snapshot.
    \c - postgres - :master_port
    SELECT citus.mitmproxy('conn.onQuery(query="CREATE_REPLICATION_SLOT .* LOGICAL .* EXPORT_SNAPSHOT.*").killall()');
    SELECT pg_catalog.citus_split_shard_by_split_points(
        8981000,
        ARRAY['-100000'],
        ARRAY[:worker_2_node, :worker_2_node],
        'force_logical');
    SELECT * FROM pg_dist_cleanup;
    -- we need to allow connection so that we can connect to proxy
    SELECT citus.mitmproxy('conn.allow()');

    \c - - - :worker_2_proxy_port
    SET search_path TO "citus_split_test_schema", public, pg_catalog;
    SET citus.show_shards_for_app_name_prefixes = '*';
    -- Left over child shards
    SELECT relname FROM pg_class where relname LIKE '%table_to_split_%' AND relkind = 'r';
    -- Left over publications
    SELECT pubname FROM pg_publication;
    -- Left over replication slots
    SELECT slot_name FROM pg_replication_slots;
    -- Left over subscriptions
    SELECT subname FROM pg_subscription;

    \c - postgres - :master_port
    SELECT run_try_drop_marked_shards();
    SELECT * FROM pg_dist_cleanup;

    \c - - - :worker_2_proxy_port
    SET search_path TO "citus_split_test_schema", public, pg_catalog;
    SET citus.show_shards_for_app_name_prefixes = '*';
    -- Empty child shards after cleanup
    SELECT relname FROM pg_class where relname LIKE '%table_to_split_%' AND relkind = 'r';
    -- Empty publications
    SELECT pubname FROM pg_publication;
    -- Empty replication slot table
    SELECT slot_name FROM pg_replication_slots;
    -- Empty subscriptions
    SELECT subname FROM pg_subscription;
--3. Failure while executing 'CREATE_REPLICATION_SLOT' for Snapshot.


--4. Failure while enabling subscription
    \c - postgres - :master_port
    SELECT citus.mitmproxy('conn.onQuery(query="ALTER SUBSCRIPTION .* ENABLE").killall()');
    SELECT pg_catalog.citus_split_shard_by_split_points(
        8981000,
        ARRAY['-100000'],
        ARRAY[:worker_2_node, :worker_2_node],
        'force_logical');
    SELECT * FROM pg_dist_cleanup;
    -- we need to allow connection so that we can connect to proxy
    SELECT citus.mitmproxy('conn.allow()');

    \c - - - :worker_2_proxy_port
    SET search_path TO "citus_split_test_schema", public, pg_catalog;
    SET citus.show_shards_for_app_name_prefixes = '*';
    -- Left over child shards
    SELECT relname FROM pg_class where relname LIKE '%table_to_split_%' AND relkind = 'r';
    -- Left over publications
    SELECT pubname FROM pg_publication;
    -- Left over replication slots
    SELECT slot_name FROM pg_replication_slots;
    -- Left over subscriptions
    SELECT subname FROM pg_subscription;

    \c - postgres - :master_port
    SELECT run_try_drop_marked_shards();
    SELECT * FROM pg_dist_cleanup;

    \c - - - :worker_2_proxy_port
    SET search_path TO "citus_split_test_schema", public, pg_catalog;
    SET citus.show_shards_for_app_name_prefixes = '*';
    -- Empty child shards after cleanup
    SELECT relname FROM pg_class where relname LIKE '%table_to_split_%' AND relkind = 'r';
    -- Empty publications
    SELECT pubname FROM pg_publication;
    -- Empty replication slot table
    SELECT slot_name FROM pg_replication_slots;
    -- Empty subscriptions
    SELECT subname FROM pg_subscription;
--4. Failure while enabling subscription

--5. Failure on polling subscription state
    \c - postgres - :master_port
    SELECT citus.mitmproxy('conn.onQuery(query="^SELECT count\(\*\) FROM pg_subscription_rel").killall()');
    SELECT pg_catalog.citus_split_shard_by_split_points(
        8981000,
        ARRAY['-100000'],
        ARRAY[:worker_2_node, :worker_2_node],
        'force_logical');
    SELECT * FROM pg_dist_cleanup;
    -- we need to allow connection so that we can connect to proxy
    SELECT citus.mitmproxy('conn.allow()');

    \c - - - :worker_2_proxy_port
    SET search_path TO "citus_split_test_schema", public, pg_catalog;
    SET citus.show_shards_for_app_name_prefixes = '*';
    -- Left over child shards
    SELECT relname FROM pg_class where relname LIKE '%table_to_split_%' AND relkind = 'r';
    -- Left over publications
    SELECT pubname FROM pg_publication;
    -- Left over replication slots
    SELECT slot_name FROM pg_replication_slots;
    -- Left over subscriptions
    SELECT subname FROM pg_subscription;

    \c - postgres - :master_port
    SELECT run_try_drop_marked_shards();
    SELECT * FROM pg_dist_cleanup;

    \c - - - :worker_2_proxy_port
    SET search_path TO "citus_split_test_schema", public, pg_catalog;
    SET citus.show_shards_for_app_name_prefixes = '*';
    -- Empty child shards after cleanup
    SELECT relname FROM pg_class where relname LIKE '%table_to_split_%' AND relkind = 'r';
    -- Empty publications
    SELECT pubname FROM pg_publication;
    -- Empty replication slot table
    SELECT slot_name FROM pg_replication_slots;
    -- Empty subscriptions
    SELECT subname FROM pg_subscription;
--5. Failure on polling subscription state

--6. Failure on polling last write-ahead log location reported to origin WAL sender
    \c - postgres - :master_port
    SELECT citus.mitmproxy('conn.onQuery(query="^SELECT min\(latest_end_lsn").killall()');
    SELECT pg_catalog.citus_split_shard_by_split_points(
        8981000,
        ARRAY['-100000'],
        ARRAY[:worker_2_node, :worker_2_node],
        'force_logical');
    SELECT * FROM pg_dist_cleanup;
    -- we need to allow connection so that we can connect to proxy
    SELECT citus.mitmproxy('conn.allow()');

    \c - - - :worker_2_proxy_port
    SET search_path TO "citus_split_test_schema", public, pg_catalog;
    SET citus.show_shards_for_app_name_prefixes = '*';
    -- Left over child shards
    SELECT relname FROM pg_class where relname LIKE '%table_to_split_%' AND relkind = 'r';
    -- Left over publications
    SELECT pubname FROM pg_publication;
    -- Left over replication slots
    SELECT slot_name FROM pg_replication_slots;
    -- Left over subscriptions
    SELECT subname FROM pg_subscription;

    \c - postgres - :master_port
    SELECT run_try_drop_marked_shards();
    SELECT * FROM pg_dist_cleanup;

    \c - - - :worker_2_proxy_port
    SET search_path TO "citus_split_test_schema", public, pg_catalog;
    SET citus.show_shards_for_app_name_prefixes = '*';
    -- Empty child shards after cleanup
    SELECT relname FROM pg_class where relname LIKE '%table_to_split_%' AND relkind = 'r';
    -- Empty publications
    SELECT pubname FROM pg_publication;
    -- Empty replication slot table
    SELECT slot_name FROM pg_replication_slots;
    -- Empty subscriptions
    SELECT subname FROM pg_subscription;
--6. Failure on polling last write-ahead log location reported to origin WAL sender

--7. Failure on disabling subscription (right before dropping it)
    \c - postgres - :master_port
    SELECT citus.mitmproxy('conn.onQuery(query="^ALTER SUBSCRIPTION .* DISABLE").killall()');
    SELECT pg_catalog.citus_split_shard_by_split_points(
        8981000,
        ARRAY['-100000'],
        ARRAY[:worker_2_node, :worker_2_node],
        'force_logical');
    SELECT * FROM pg_dist_cleanup;
    -- we need to allow connection so that we can connect to proxy
    SELECT citus.mitmproxy('conn.allow()');

    \c - - - :worker_2_proxy_port
    SET search_path TO "citus_split_test_schema", public, pg_catalog;
    SET citus.show_shards_for_app_name_prefixes = '*';
    -- Left over child shards
    SELECT relname FROM pg_class where relname LIKE '%table_to_split_%' AND relkind = 'r';
    -- Left over publications
    SELECT pubname FROM pg_publication;
    -- Left over replication slots
    SELECT slot_name FROM pg_replication_slots;
    -- Left over subscriptions
    SELECT subname FROM pg_subscription;

    \c - postgres - :master_port
    SELECT run_try_drop_marked_shards();
    SELECT * FROM pg_dist_cleanup;

    \c - - - :worker_2_proxy_port
    SET search_path TO "citus_split_test_schema", public, pg_catalog;
    SET citus.show_shards_for_app_name_prefixes = '*';
    -- Empty child shards after cleanup
    SELECT relname FROM pg_class where relname LIKE '%table_to_split_%' AND relkind = 'r';
    -- Empty publications
    SELECT pubname FROM pg_publication;
    -- Empty replication slot table
    SELECT slot_name FROM pg_replication_slots;
    -- Empty subscriptions
    SELECT subname FROM pg_subscription;
--7. Failure on disabling subscription (right before dropping it)

--8. Failure on dropping subscription
    \c - postgres - :master_port
    SELECT citus.mitmproxy('conn.onQuery(query="^DROP SUBSCRIPTION").killall()');
    SELECT pg_catalog.citus_split_shard_by_split_points(
        8981000,
        ARRAY['-100000'],
        ARRAY[:worker_2_node, :worker_2_node],
        'force_logical');
    SELECT * FROM pg_dist_cleanup;
    SELECT relname FROM pg_class where relname LIKE '%table_to_split_%' AND relkind = 'r';
    -- we need to allow connection so that we can connect to proxy
    SELECT citus.mitmproxy('conn.allow()');

    \c - - - :worker_2_proxy_port
    SET search_path TO "citus_split_test_schema", public, pg_catalog;
    SET citus.show_shards_for_app_name_prefixes = '*';
    -- Left over child shards
    SELECT relname FROM pg_class where relname LIKE '%table_to_split_%' AND relkind = 'r';
    -- Left over publications
    SELECT pubname FROM pg_publication;
    -- Left over replication slots
    SELECT slot_name FROM pg_replication_slots;
    -- Left over subscriptions
    SELECT subname FROM pg_subscription;

    \c - postgres - :master_port
    SELECT run_try_drop_marked_shards();
    SELECT * FROM pg_dist_cleanup;

    \c - - - :worker_2_proxy_port
    SET search_path TO "citus_split_test_schema", public, pg_catalog;
    SET citus.show_shards_for_app_name_prefixes = '*';
    -- Empty child shards after cleanup
    SELECT relname FROM pg_class where relname LIKE '%table_to_split_%' AND relkind = 'r';
    -- Empty publications
    SELECT pubname FROM pg_publication;
    -- Empty replication slot table
    SELECT slot_name FROM pg_replication_slots;
    -- Empty subscriptions
    SELECT subname FROM pg_subscription;
--8. Failure on dropping subscription
