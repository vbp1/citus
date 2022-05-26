-- File to create functions and helpers needed for split shard tests

-- Populates shared memory mapping for parent shard with id 1.
-- targetNode1, targetNode2 are the locations where child shard 2 and 3 are placed respectively
CREATE OR REPLACE FUNCTION SplitShardReplicationSetup(targetNode1 integer, targetNode2 integer) RETURNS text AS $$
DECLARE
    memoryId bigint := 0;
    memoryIdText text;
begin
	SELECT * into memoryId from split_shard_replication_setup(ARRAY[ARRAY[1,2,-2147483648,-1, targetNode1], ARRAY[1,3,0,2147483647,targetNode2]]);
    SELECT FORMAT('%s', memoryId) into memoryIdText;
    return memoryIdText;
end
$$ LANGUAGE plpgsql;

-- Create replication slots for targetNode1 and targetNode2 incase of non-colocated shards
CREATE OR REPLACE FUNCTION CreateReplicationSlot(targetNode1 integer, targetNode2 integer) RETURNS text AS $$
DECLARE
    targetOneSlotName text;
    targetTwoSlotName text;
    sharedMemoryId text;
    derivedSlotName text;
begin

    SELECT * into sharedMemoryId from public.SplitShardReplicationSetup(targetNode1, targetNode2);
    SELECT FORMAT('%s_%s', targetNode1, sharedMemoryId) into derivedSlotName;
    SELECT slot_name into targetOneSlotName from pg_create_logical_replication_slot(derivedSlotName, 'decoding_plugin_for_shard_split');

    -- if new child shards are placed on different nodes, create one more replication slot
    if (targetNode1 != targetNode2) then
        SELECT FORMAT('%s_%s', targetNode2, sharedMemoryId) into derivedSlotName;
        SELECT slot_name into targetTwoSlotName from pg_create_logical_replication_slot(derivedSlotName, 'decoding_plugin_for_shard_split');
        INSERT INTO slotName_table values(targetTwoSlotName, targetNode2, 1);
    end if;

    INSERT INTO slotName_table values(targetOneSlotName, targetNode1, 2);
    return targetOneSlotName;
end
$$ LANGUAGE plpgsql;

-- Populates shared memory mapping for colocated parent shards 4 and 7.
-- shard 4 has child shards 5 and 6. Shard 7 has child shards 8 and 9.
CREATE OR REPLACE FUNCTION SplitShardReplicationSetupForColocatedShards(targetNode1 integer, targetNode2 integer) RETURNS text AS $$
DECLARE
    memoryId bigint := 0;
    memoryIdText text;
begin
	SELECT * into memoryId from split_shard_replication_setup(
    ARRAY[
          ARRAY[4, 5, -2147483648,-1, targetNode1],
          ARRAY[4, 6, 0 ,2147483647,  targetNode2],
          ARRAY[7, 8, -2147483648,-1,  targetNode1],
          ARRAY[7, 9, 0, 2147483647 , targetNode2]
        ]);

    SELECT FORMAT('%s', memoryId) into memoryIdText;
    return memoryIdText;
end
$$ LANGUAGE plpgsql;

-- Create replication slots for targetNode1 and targetNode2 incase of colocated shards
CREATE OR REPLACE FUNCTION CreateReplicationSlotForColocatedShards(targetNode1 integer, targetNode2 integer) RETURNS text AS $$
DECLARE
    targetOneSlotName text;
    targetTwoSlotName text;
    sharedMemoryId text;
    derivedSlotName text;
begin

    SELECT * into sharedMemoryId from public.SplitShardReplicationSetupForColocatedShards(targetNode1, targetNode2);
    SELECT FORMAT('%s_%s', targetNode1, sharedMemoryId) into derivedSlotName;
    SELECT slot_name into targetOneSlotName from pg_create_logical_replication_slot(derivedSlotName, 'decoding_plugin_for_shard_split');

    -- if new child shards are placed on different nodes, create one more replication slot
    if (targetNode1 != targetNode2) then
        SELECT FORMAT('%s_%s', targetNode2, sharedMemoryId) into derivedSlotName;
        SELECT slot_name into targetTwoSlotName from pg_create_logical_replication_slot(derivedSlotName, 'decoding_plugin_for_shard_split');
        INSERT INTO slotName_table values(targetTwoSlotName, targetNode2, 1);
    end if;

    INSERT INTO slotName_table values(targetOneSlotName, targetNode1, 2);
    return targetOneSlotName;
end
$$ LANGUAGE plpgsql;

-- create subscription on target node with given 'subscriptionName'
CREATE OR REPLACE FUNCTION CreateSubscription(targetNodeId integer, subscriptionName text) RETURNS text AS $$
DECLARE
    replicationSlotName text;
    nodeportLocal int;
    subname text;
begin
    SELECT name into replicationSlotName from slotName_table where nodeId = targetNodeId;
    EXECUTE FORMAT($sub$create subscription %s connection 'host=localhost port=57637 user=postgres dbname=regression' publication PUB1 with(create_slot=false, enabled=true, slot_name='%s', copy_data=false)$sub$, subscriptionName, replicationSlotName);
    return replicationSlotName;
end
$$ LANGUAGE plpgsql;