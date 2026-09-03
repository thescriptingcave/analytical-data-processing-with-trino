CREATE SCHEMA IF NOT EXISTS iceberg_catalog;

CREATE TABLE IF NOT EXISTS iceberg_catalog.iceberg_tables (
    catalog_name               VARCHAR(255) NOT NULL,
    table_namespace            VARCHAR(255) NOT NULL,
    table_name                 VARCHAR(255) NOT NULL,
    metadata_location          VARCHAR(4000) NOT NULL,
    previous_metadata_location VARCHAR(4000),
    metadata                   JSONB,
    PRIMARY KEY (catalog_name, table_namespace, table_name)
);

CREATE TABLE IF NOT EXISTS iceberg_catalog.iceberg_partitions (
    table_catalog      VARCHAR(255) NOT NULL,
    table_namespace    VARCHAR(255) NOT NULL,
    table_name         VARCHAR(255) NOT NULL,
    partition_data     JSONB,
    record_count       BIGINT,
    file_size_in_bytes BIGINT,
    value_count        BIGINT,
    null_value_count   BIGINT,
    nan_value_count    BIGINT,
    lower_bounds       JSONB,
    upper_bounds       JSONB,
    key_id             INT,
    sequence_number    BIGINT,
    position_delete    BOOLEAN DEFAULT FALSE
);

CREATE TABLE IF NOT EXISTS iceberg_catalog.iceberg_snapshot_log (
    table_catalog    VARCHAR(255) NOT NULL,
    table_namespace  VARCHAR(255) NOT NULL,
    table_name       VARCHAR(255) NOT NULL,
    timestamp_millis BIGINT NOT NULL,
    snapshot_id      BIGINT NOT NULL
);

CREATE TABLE IF NOT EXISTS iceberg_catalog.iceberg_metadata_log (
    table_catalog    VARCHAR(255) NOT NULL,
    table_namespace  VARCHAR(255) NOT NULL,
    table_name       VARCHAR(255) NOT NULL,
    timestamp_millis BIGINT NOT NULL,
    metadata_file    VARCHAR(4000) NOT NULL
);

CREATE TABLE IF NOT EXISTS iceberg_catalog.iceberg_history_log (
    table_catalog   VARCHAR(255) NOT NULL,
    table_namespace VARCHAR(255) NOT NULL,
    table_name      VARCHAR(255) NOT NULL,
    made_current_at BIGINT NOT NULL,
    snapshot_id     BIGINT NOT NULL
);

GRANT USAGE ON SCHEMA iceberg_catalog TO iceberg;
GRANT ALL ON ALL TABLES IN SCHEMA iceberg_catalog TO iceberg;
ALTER DEFAULT PRIVILEGES IN SCHEMA iceberg_catalog
    GRANT ALL ON TABLES TO iceberg;
