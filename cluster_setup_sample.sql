\c postgres
CREATE DATABASE cluster;
\c cluster;

set enable_partitionwise_join = true;
set enable_partitionwise_aggregate = true;

CREATE EXTENSION postgres_fdw;

-- Create connections to data nodes.
CREATE SERVER data_node_0 FOREIGN DATA WRAPPER postgres_fdw OPTIONS (dbname 'cluster', host 'localhost', use_remote_estimate 'true', fetch_size '100000');
CREATE SERVER data_node_1 FOREIGN DATA WRAPPER postgres_fdw OPTIONS (dbname 'cluster', host 'localhost', use_remote_estimate 'true', fetch_size '100000');

-- The user mappings are necessary so that PostgreSQL knows with
-- which credentials to access the foreign servers for the data nodes.
CREATE USER MAPPING FOR postgres SERVER data_node_0 OPTIONS (user 'postgres');
CREATE USER MAPPING FOR postgres SERVER data_node_1 OPTIONS (user 'postgres');

-- Create partitioned tables on coordinator node.
CREATE TABLE lineitem (
    l_orderkey bigint NOT NULL,
    l_partkey int NOT NULL,
    l_suppkey int NOT NULL,
    l_linenumber int NOT NULL,
    l_quantity numeric(13,2) NOT NULL,
    l_extendedprice numeric(13,2) NOT NULL,
    l_discount numeric(13,2) NOT NULL,
    l_tax numeric(13,2) NOT NULL,
    l_returnflag "char" NOT NULL,
    l_linestatus "char" NOT NULL,
    l_shipdate date NOT NULL,
    l_commitdate date NOT NULL,
    l_receiptdate date NOT NULL,
    l_shipinstruct character varying(25) NOT NULL,
    l_shipmode character varying(10) NOT NULL,
    l_comment character varying(44) NOT NULL
) PARTITION BY HASH (l_orderkey);

CREATE TABLE orders (
    o_orderkey bigint NOT NULL,
    o_custkey int NOT NULL,
    o_orderstatus "char" NOT NULL,
    o_totalprice numeric(13,2) NOT NULL,
    o_orderdate date NOT NULL,
    o_orderpriority character varying(15) NOT NULL,
    o_clerk character varying(15) NOT NULL,
    o_shippriority int NOT NULL,
    o_comment character varying(79) NOT NULL
) PARTITION BY HASH (o_orderkey);

-- Create the backing tables for each partition on the data nodes.
-- Their schema matches the schema of the table on the coordinator node.
CREATE TABLE lineitem_dn_0_shard_0 AS (SELECT * FROM lineitem);
CREATE TABLE lineitem_dn_0_shard_1 AS (SELECT * FROM lineitem);
CREATE TABLE lineitem_dn_1_shard_0 AS (SELECT * FROM lineitem);
CREATE TABLE lineitem_dn_1_shard_1 AS (SELECT * FROM lineitem);

CREATE TABLE orders_dn_0_shard_0 AS (SELECT * FROM orders);
CREATE TABLE orders_dn_0_shard_1 AS (SELECT * FROM orders);
CREATE TABLE orders_dn_1_shard_0 AS (SELECT * FROM orders);
CREATE TABLE orders_dn_1_shard_1 AS (SELECT * FROM orders);

-- Create partitions on the coordinator node, each referencing a
-- corresponding partition on one of the data nodes.
CREATE FOREIGN TABLE lineitem_shard_0 PARTITION OF lineitem FOR VALUES WITH (MODULUS 4, REMAINDER 0) SERVER data_node_0 OPTIONS(table_name 'lineitem_dn_0_shard_0');
CREATE FOREIGN TABLE lineitem_shard_1 PARTITION OF lineitem FOR VALUES WITH (MODULUS 4, REMAINDER 1) SERVER data_node_1 OPTIONS(table_name 'lineitem_dn_1_shard_0');
CREATE FOREIGN TABLE lineitem_shard_2 PARTITION OF lineitem FOR VALUES WITH (MODULUS 4, REMAINDER 2) SERVER data_node_0 OPTIONS(table_name 'lineitem_dn_0_shard_1');
CREATE FOREIGN TABLE lineitem_shard_3 PARTITION OF lineitem FOR VALUES WITH (MODULUS 4, REMAINDER 3) SERVER data_node_1 OPTIONS(table_name 'lineitem_dn_1_shard_1');

CREATE FOREIGN TABLE orders_shard_0 PARTITION OF orders FOR VALUES WITH (MODULUS 4, REMAINDER 0) SERVER data_node_0 OPTIONS(table_name 'orders_dn_0_shard_0');
CREATE FOREIGN TABLE orders_shard_1 PARTITION OF orders FOR VALUES WITH (MODULUS 4, REMAINDER 1) SERVER data_node_1 OPTIONS(table_name 'orders_dn_1_shard_0');
CREATE FOREIGN TABLE orders_shard_2 PARTITION OF orders FOR VALUES WITH (MODULUS 4, REMAINDER 2) SERVER data_node_0 OPTIONS(table_name 'orders_dn_0_shard_1');
CREATE FOREIGN TABLE orders_shard_3 PARTITION OF orders FOR VALUES WITH (MODULUS 4, REMAINDER 3) SERVER data_node_1 OPTIONS(table_name 'orders_dn_1_shard_1');

-- Update statistics of all tables on the data nodes.
--
-- As long as remote estimates are used during planning there's no
-- need to call 'ANALYZE' for the tables on the coordinator node.
-- Be careful when you run ANALYZE on the coordinator for any table
-- that has large amounts of its data stored on a data node. This
-- is a very slow operation because all table rows must be fetched
-- from the data node through the FDW.
ANALYZE lineitem_dn_0_shard_0, lineitem_dn_0_shard_1, lineitem_dn_1_shard_0, lineitem_dn_1_shard_1;
ANALYZE orders_dn_0_shard_0, orders_dn_0_shard_1, orders_dn_1_shard_0, orders_dn_1_shard_1;