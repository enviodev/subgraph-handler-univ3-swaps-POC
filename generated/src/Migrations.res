let sql = Postgres.makeSql(~config=Config.db->Obj.magic /* TODO: make this have the correct type */)

module EventSyncState = {
  let createEventSyncStateTable: unit => promise<unit> = async () => {
    let _ = await %raw("sql`
      CREATE TABLE IF NOT EXISTS public.event_sync_state (
        chain_id INTEGER NOT NULL,
        block_number INTEGER NOT NULL,
        log_index INTEGER NOT NULL,
        transaction_index INTEGER NOT NULL,
        block_timestamp INTEGER NOT NULL,
        PRIMARY KEY (chain_id)
      );
      `")
  }

  let dropEventSyncStateTable = async () => {
    let _ = await %raw("sql`
      DROP TABLE IF EXISTS public.event_sync_state;
    `")
  }
}

module ChainMetadata = {
  let createChainMetadataTable: unit => promise<unit> = async () => {
    let _ = await %raw("sql`
      CREATE TABLE IF NOT EXISTS public.chain_metadata (
        chain_id INTEGER NOT NULL,
        start_block INTEGER NOT NULL,
        block_height INTEGER NOT NULL,
        first_event_block_number INTEGER NULL,
        latest_processed_block INTEGER NULL,
        num_events_processed INTEGER NULL,
        PRIMARY KEY (chain_id)
      );
      `")
  }

  let dropChainMetadataTable = async () => {
    let _ = await %raw("sql`
      DROP TABLE IF EXISTS public.chain_metadata;
    `")
  }
}

module PersistedState = {
  let createPersistedStateTable: unit => promise<unit> = async () => {
    let _ = await %raw("sql`
      CREATE TABLE IF NOT EXISTS public.persisted_state (
        id SERIAL PRIMARY KEY,
        envio_version TEXT NOT NULL, 
        config_hash TEXT NOT NULL,
        schema_hash TEXT NOT NULL,
        handler_files_hash TEXT NOT NULL,
        abi_files_hash TEXT NOT NULL
      );
      `")
  }

  let dropPersistedStateTable = async () => {
    let _ = await %raw("sql`
      DROP TABLE IF EXISTS public.persisted_state;
    `")
  }
}

module SyncBatchMetadata = {
  let createSyncBatchTable: unit => promise<unit> = async () => {
    @warning("-21")
    let _ = await %raw("sql`
      CREATE TABLE IF NOT EXISTS public.sync_batch (
        chain_id INTEGER NOT NULL,
        block_timestamp_range_end INTEGER NOT NULL,
        block_number_range_end INTEGER NOT NULL,
        block_hash_range_end TEXT NOT NULL,
        PRIMARY KEY (chain_id, block_number_range_end)
      );
      `")
  }

  @@warning("-21")
  let dropSyncStateTable = async () => {
    let _ = await %raw("sql`
      DROP TABLE IF EXISTS public.sync_batch;
    `")
  }
  @@warning("+21")
}

module RawEventsTable = {
  let createEventTypeEnum: unit => promise<unit> = async () => {
    @warning("-21")
    let _ = await %raw("sql`
      DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'event_type') THEN
          CREATE TYPE EVENT_TYPE AS ENUM(
          'SwapContract_Swap'
          );
        END IF;
      END $$;
      `")
  }

  let createRawEventsTable: unit => promise<unit> = async () => {
    let _ = await createEventTypeEnum()

    @warning("-21")
    let _ = await %raw("sql`
      CREATE TABLE IF NOT EXISTS public.raw_events (
        chain_id INTEGER NOT NULL,
        event_id NUMERIC NOT NULL,
        block_number INTEGER NOT NULL,
        log_index INTEGER NOT NULL,
        transaction_index INTEGER NOT NULL,
        transaction_hash TEXT NOT NULL,
        src_address TEXT NOT NULL,
        block_hash TEXT NOT NULL,
        block_timestamp INTEGER NOT NULL,
        event_type EVENT_TYPE NOT NULL,
        params JSON NOT NULL,
        db_write_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        PRIMARY KEY (chain_id, event_id)
      );
      `")
  }

  @@warning("-21")
  let dropRawEventsTable = async () => {
    let _ = await %raw("sql`
      DROP TABLE IF EXISTS public.raw_events;
    `")
    let _ = await %raw("sql`
      DROP TYPE IF EXISTS EVENT_TYPE CASCADE;
    `")
  }
  @@warning("+21")
}

module DynamicContractRegistryTable = {
  let createDynamicContractRegistryTable: unit => promise<unit> = async () => {
    @warning("-21")
    let _ = await %raw("sql`
      DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'contract_type') THEN
          CREATE TYPE CONTRACT_TYPE AS ENUM (
          'SwapContract'
          );
        END IF;
      END $$;
      `")

    @warning("-21")
    let _ = await %raw("sql`
      CREATE TABLE IF NOT EXISTS public.dynamic_contract_registry (
        chain_id INTEGER NOT NULL,
        event_id NUMERIC NOT NULL,
        contract_address TEXT NOT NULL,
        contract_type CONTRACT_TYPE NOT NULL,
        PRIMARY KEY (chain_id, contract_address)
      );
      `")
  }

  @@warning("-21")
  let dropDynamicContractRegistryTable = async () => {
    let _ = await %raw("sql`
      DROP TABLE IF EXISTS public.dynamic_contract_registry;
    `")
    let _ = await %raw("sql`
      DROP TYPE IF EXISTS EVENT_TYPE CASCADE;
    `")
  }
  @@warning("+21")
}

module EnumTypes = {}

module EntityHistory = {
  let createEntityTypeEnum: unit => promise<unit> = async () => {
    @warning("-21")
    let _ = await %raw("sql`
      DO $$ BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'entity_type') THEN
          CREATE TYPE ENTITY_TYPE AS ENUM(
            'Swap'
          );
        END IF;
      END $$;
      `")
  }

  let createEntityHistoryTable: unit => promise<unit> = async () => {
    let _ = await createEntityTypeEnum()

    // NULL for an `entity_id` means that the entity was deleted.
    await %raw("sql`
      CREATE TABLE \"public\".\"A\" (
        chain_id INTEGER NOT NULL,
        block_number INTEGER NOT NULL,
        log_index INTEGER NOT NULL,
        transaction_hash BYTEA NOT NULL,
        entity_type ENTITY_TYPE NOT NULL,
        entity_id TEXT,
        PRIMARY KEY (entity_id, chain_id, block_number, log_index));
      `")
  }

  // NOTE: didn't add 'delete' functions here - delete functions aren't being used currently.
}

module Swap = {
  let createSwapTable: unit => promise<unit> = async () => {
    await %raw("sql`
      CREATE TABLE \"public\".\"Swap\" (\"amount0\" numeric NOT NULL,\"amount1\" numeric NOT NULL,\"blockNumber\" integer NOT NULL,\"blockTimestamp\" integer NOT NULL,\"id\" text NOT NULL,\"liquidity\" numeric NOT NULL,\"liquidityPool\" text NOT NULL,\"recipient\" text NOT NULL,\"sender\" text NOT NULL,\"sqrtPriceX96\" numeric NOT NULL,\"tick\" numeric NOT NULL,\"transactionHash\" text NOT NULL, 
        db_write_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
        PRIMARY KEY (\"id\"));`")
  }

  let createSwapHistoryTable: unit => promise<unit> = async () => {
    // Rather using chain_id + log_index + block_number and not also "transaction_hash TEXT NOT NULL"
    await %raw("sql`
      CREATE TABLE \"public\".\"Swap_history\" (
        chain_id INTEGER NOT NULL,
        block_number INTEGER NOT NULL,
        log_index INTEGER NOT NULL,
        \"amount0\" numeric NOT NULL,
        \"amount1\" numeric NOT NULL,
        \"blockNumber\" integer NOT NULL,
        \"blockTimestamp\" integer NOT NULL,
        \"id\" text NOT NULL,
        \"liquidity\" numeric NOT NULL,
        \"liquidityPool\" text NOT NULL,
        \"recipient\" text NOT NULL,
        \"sender\" text NOT NULL,
        \"sqrtPriceX96\" numeric NOT NULL,
        \"tick\" numeric NOT NULL,
        \"transactionHash\" text NOT NULL,
        db_write_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP, 
        PRIMARY KEY (\"id\", chain_id, block_number, log_index));`")
  }

  let deleteSwapTable: unit => promise<unit> = async () => {
    // NOTE: we can refine the `IF EXISTS` part because this now prints to the terminal if the table doesn't exist (which isn't nice for the developer).
    await %raw("sql`DROP TABLE IF EXISTS \"public\".\"Swap\";`")
  }
}

let deleteAllTables: unit => promise<unit> = async () => {
  Logging.trace("Dropping all tables")
  // NOTE: we can refine the `IF EXISTS` part because this now prints to the terminal if the table doesn't exist (which isn't nice for the developer).

  @warning("-21")
  await (
    %raw(
      "sql.unsafe`DROP SCHEMA public CASCADE;CREATE SCHEMA public;GRANT ALL ON SCHEMA public TO postgres;GRANT ALL ON SCHEMA public TO public;`"
    )
  )
}

let deleteAllTablesExceptRawEventsAndDynamicContractRegistry: unit => promise<unit> = async () => {
  // NOTE: we can refine the `IF EXISTS` part because this now prints to the terminal if the table doesn't exist (which isn't nice for the developer).

  @warning("-21")
  await (
    %raw("sql.unsafe`
    DO $$ 
    DECLARE
        table_name_var text;
    BEGIN
        FOR table_name_var IN (SELECT table_name
                           FROM information_schema.tables
                           WHERE table_schema = 'public'
                           AND table_name != 'raw_events'
                           AND table_name != 'dynamic_contract_registry') 
        LOOP
            EXECUTE 'DROP TABLE IF EXISTS ' || table_name_var || ' CASCADE';
        END LOOP;
    END $$;
  `")
  )
}

type t
@module external process: t = "process"

type exitCode = Success | Failure
@send external exit: (t, exitCode) => unit = "exit"

// TODO: all the migration steps should run as a single transaction
let runUpMigrations = async (~shouldExit) => {
  let exitCode = ref(Success)
  await PersistedState.createPersistedStateTable()->Promise.catch(err => {
    exitCode := Failure
    Logging.errorWithExn(err, `EE800: Error creating persisted_state table`)->Promise.resolve
  })

  await EventSyncState.createEventSyncStateTable()->Promise.catch(err => {
    exitCode := Failure
    Logging.errorWithExn(err, `EE800: Error creating event_sync_state table`)->Promise.resolve
  })
  await ChainMetadata.createChainMetadataTable()->Promise.catch(err => {
    exitCode := Failure
    Logging.errorWithExn(err, `EE800: Error creating chain_metadata table`)->Promise.resolve
  })
  await SyncBatchMetadata.createSyncBatchTable()->Promise.catch(err => {
    exitCode := Failure
    Logging.errorWithExn(err, `EE800: Error creating sync_batch table`)->Promise.resolve
  })
  await RawEventsTable.createRawEventsTable()->Promise.catch(err => {
    exitCode := Failure
    Logging.errorWithExn(err, `EE800: Error creating raw_events table`)->Promise.resolve
  })
  await DynamicContractRegistryTable.createDynamicContractRegistryTable()->Promise.catch(err => {
    exitCode := Failure
    Logging.errorWithExn(err, `EE801: Error creating dynamic_contracts table`)->Promise.resolve
  })

  // TODO: catch and handle query errors
  await Swap.createSwapTable()->Promise.catch(err => {
    exitCode := Failure
    Logging.errorWithExn(err, `EE802: Error creating Swap table`)->Promise.resolve
  })
  await Swap.createSwapHistoryTable()->Promise.catch(err => {
    exitCode := Failure
    Logging.errorWithExn(err, `EE802: Error creating Swap entity history table`)->Promise.resolve
  })
  await TrackTables.trackAllTables()->Promise.catch(err => {
    Logging.errorWithExn(err, `EE803: Error tracking tables`)->Promise.resolve
  })
  if shouldExit {
    process->exit(exitCode.contents)
  }
  exitCode.contents
}

let runDownMigrations = async (~shouldExit, ~shouldDropRawEvents) => {
  let exitCode = ref(Success)

  //
  // await Swap.deleteSwapTable()
  //

  // NOTE: For now delete any remaining tables.
  if shouldDropRawEvents {
    await deleteAllTables()->Promise.catch(err => {
      exitCode := Failure
      Logging.errorWithExn(err, "EE804: Error dropping entity tables")->Promise.resolve
    })
  } else {
    await deleteAllTablesExceptRawEventsAndDynamicContractRegistry()->Promise.catch(err => {
      exitCode := Failure
      Logging.errorWithExn(
        err,
        "EE805: Error dropping entity tables except for raw events",
      )->Promise.resolve
    })
  }
  if shouldExit {
    process->exit(exitCode.contents)
  }
  exitCode.contents
}

let setupDb = async (~shouldDropRawEvents) => {
  Logging.info("Provisioning Database")
  // TODO: we should make a hash of the schema file (that gets stored in the DB) and either drop the tables and create new ones or keep this migration.
  //       for now we always run the down migration.
  // if (process.env.MIGRATE === "force" || hash_of_schema_file !== hash_of_current_schema)
  let exitCodeDown = await runDownMigrations(~shouldExit=false, ~shouldDropRawEvents)
  // else
  //   await clearDb()

  let exitCodeUp = await runUpMigrations(~shouldExit=false)

  let exitCode = switch (exitCodeDown, exitCodeUp) {
  | (Success, Success) => Success
  | _ => Failure
  }

  process->exit(exitCode)
}
