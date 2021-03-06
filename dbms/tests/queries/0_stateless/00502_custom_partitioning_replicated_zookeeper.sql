-- IMPORTANT: Don't use this setting just yet.
-- It is for testing purposes, the syntax will likely change soon and the server will not be able
-- to load the tables created this way. You have been warned.
SET experimental_merge_tree_allow_custom_partitions = 1;

SET replication_alter_partitions_sync = 2;

SELECT '*** Not partitioned ***';

DROP TABLE IF EXISTS test.not_partitioned_replica1;
DROP TABLE IF EXISTS test.not_partitioned_replica2;
CREATE TABLE test.not_partitioned_replica1(x UInt8) ENGINE = ReplicatedMergeTree('/clickhouse/tables/test/not_partitioned', '1', tuple(), x, 8192);
CREATE TABLE test.not_partitioned_replica2(x UInt8) ENGINE = ReplicatedMergeTree('/clickhouse/tables/test/not_partitioned', '2', tuple(), x, 8192);

INSERT INTO test.not_partitioned_replica1 VALUES (1), (2), (3);
INSERT INTO test.not_partitioned_replica1 VALUES (4), (5);

SELECT 'Parts before OPTIMIZE:';
SELECT partition, name FROM system.parts WHERE database = 'test' AND table = 'not_partitioned_replica1' AND active ORDER BY name;
OPTIMIZE TABLE test.not_partitioned_replica1 PARTITION tuple() FINAL;
SELECT 'Parts after OPTIMIZE:';
SELECT partition, name FROM system.parts WHERE database = 'test' AND table = 'not_partitioned_replica2' AND active ORDER BY name;

SELECT 'Sum before DETACH PARTITION:';
SELECT sum(x) FROM test.not_partitioned_replica2;
ALTER TABLE test.not_partitioned_replica1 DETACH PARTITION ID 'all';
SELECT 'Sum after DETACH PARTITION:';
SELECT sum(x) FROM test.not_partitioned_replica2;

DROP TABLE test.not_partitioned_replica1;
DROP TABLE test.not_partitioned_replica2;

SELECT '*** Partitioned by week ***';

DROP TABLE IF EXISTS test.partitioned_by_week_replica1;
DROP TABLE IF EXISTS test.partitioned_by_week_replica2;
CREATE TABLE test.partitioned_by_week_replica1(d Date, x UInt8) ENGINE = ReplicatedMergeTree('/clickhouse/tables/test/partitioned_by_week', '1', toMonday(d), x, 8192);
CREATE TABLE test.partitioned_by_week_replica2(d Date, x UInt8) ENGINE = ReplicatedMergeTree('/clickhouse/tables/test/partitioned_by_week', '2', toMonday(d), x, 8192);

-- 2000-01-03 belongs to a different week than 2000-01-01 and 2000-01-02
INSERT INTO test.partitioned_by_week_replica1 VALUES ('2000-01-01', 1), ('2000-01-02', 2), ('2000-01-03', 3);
INSERT INTO test.partitioned_by_week_replica1 VALUES ('2000-01-03', 4), ('2000-01-03', 5);

SELECT 'Parts before OPTIMIZE:'; -- Select parts on the first replica to avoid waiting for replication.
SELECT partition, name FROM system.parts WHERE database = 'test' AND table = 'partitioned_by_week_replica1' AND active ORDER BY name;
OPTIMIZE TABLE test.partitioned_by_week_replica1 PARTITION '2000-01-03' FINAL;
SELECT 'Parts after OPTIMIZE:'; -- After OPTIMIZE with replication_alter_partitions_sync=2 replicas must be in sync.
SELECT partition, name FROM system.parts WHERE database = 'test' AND table = 'partitioned_by_week_replica2' AND active ORDER BY name;

SELECT 'Sum before DROP PARTITION:';
SELECT sum(x) FROM test.partitioned_by_week_replica2;
ALTER TABLE test.partitioned_by_week_replica1 DROP PARTITION '1999-12-27';
SELECT 'Sum after DROP PARTITION:';
SELECT sum(x) FROM test.partitioned_by_week_replica2;

DROP TABLE test.partitioned_by_week_replica1;
DROP TABLE test.partitioned_by_week_replica2;

SELECT '*** Partitioned by a (Date, UInt8) tuple ***';

DROP TABLE IF EXISTS test.partitioned_by_tuple_replica1;
DROP TABLE IF EXISTS test.partitioned_by_tuple_replica2;
CREATE TABLE test.partitioned_by_tuple_replica1(d Date, x UInt8, y UInt8) ENGINE = ReplicatedMergeTree('/clickhouse/tables/test/partitioned_by_tuple', '1', (d, x), x, 8192);
CREATE TABLE test.partitioned_by_tuple_replica2(d Date, x UInt8, y UInt8) ENGINE = ReplicatedMergeTree('/clickhouse/tables/test/partitioned_by_tuple', '2', (d, x), x, 8192);

INSERT INTO test.partitioned_by_tuple_replica1 VALUES ('2000-01-01', 1, 1), ('2000-01-01', 2, 2), ('2000-01-02', 1, 3);
INSERT INTO test.partitioned_by_tuple_replica1 VALUES ('2000-01-02', 1, 4), ('2000-01-01', 1, 5);

SELECT 'Parts before OPTIMIZE:';
SELECT partition, name FROM system.parts WHERE database = 'test' AND table = 'partitioned_by_tuple_replica1' AND active ORDER BY name;
OPTIMIZE TABLE test.partitioned_by_tuple_replica1 PARTITION ('2000-01-01', 1) FINAL;
OPTIMIZE TABLE test.partitioned_by_tuple_replica1 PARTITION ('2000-01-02', 1) FINAL;
SELECT 'Parts after OPTIMIZE:';
SELECT partition, name FROM system.parts WHERE database = 'test' AND table = 'partitioned_by_tuple_replica2' AND active ORDER BY name;

SELECT 'Sum before DETACH PARTITION:';
SELECT sum(y) FROM test.partitioned_by_tuple_replica2;
ALTER TABLE test.partitioned_by_tuple_replica1 DETACH PARTITION ID '20000101-1';
SELECT 'Sum after DETACH PARTITION:';
SELECT sum(y) FROM test.partitioned_by_tuple_replica2;

DROP TABLE test.partitioned_by_tuple_replica1;
DROP TABLE test.partitioned_by_tuple_replica2;

SELECT '*** Partitioned by String ***';

DROP TABLE IF EXISTS test.partitioned_by_string_replica1;
DROP TABLE IF EXISTS test.partitioned_by_string_replica2;
CREATE TABLE test.partitioned_by_string_replica1(s String, x UInt8) ENGINE = ReplicatedMergeTree('/clickhouse/tables/test/partitioned_by_string', '1', tuple(s), x, 8192);
CREATE TABLE test.partitioned_by_string_replica2(s String, x UInt8) ENGINE = ReplicatedMergeTree('/clickhouse/tables/test/partitioned_by_string', '2', tuple(s), x, 8192);

INSERT INTO test.partitioned_by_string_replica1 VALUES ('aaa', 1), ('aaa', 2), ('bbb', 3);
INSERT INTO test.partitioned_by_string_replica1 VALUES ('bbb', 4), ('aaa', 5);

SELECT 'Parts before OPTIMIZE:';
SELECT partition, name FROM system.parts WHERE database = 'test' AND table = 'partitioned_by_string_replica1' AND active ORDER BY name;
OPTIMIZE TABLE test.partitioned_by_string_replica2 PARTITION 'aaa' FINAL;
SELECT 'Parts after OPTIMIZE:';
SELECT partition, name FROM system.parts WHERE database = 'test' AND table = 'partitioned_by_string_replica2' AND active ORDER BY name;

SELECT 'Sum before DROP PARTITION:';
SELECT sum(x) FROM test.partitioned_by_string_replica2;
ALTER TABLE test.partitioned_by_string_replica1 DROP PARTITION 'bbb';
SELECT 'Sum after DROP PARTITION:';
SELECT sum(x) FROM test.partitioned_by_string_replica2;

DROP TABLE test.partitioned_by_string_replica1;
DROP TABLE test.partitioned_by_string_replica2;
