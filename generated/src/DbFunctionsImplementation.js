// db operations for raw_events:
const MAX_ITEMS_PER_QUERY = 500;

module.exports.readLatestSyncedEventOnChainId = (sql, chainId) => sql`
  SELECT *
  FROM public.event_sync_state
  WHERE chain_id = ${chainId}`;

module.exports.batchSetEventSyncState = (sql, entityDataArray) => {
  return sql`
    INSERT INTO public.event_sync_state
  ${sql(
    entityDataArray,
    "chain_id",
    "block_number",
    "log_index",
    "transaction_index",
    "block_timestamp"
  )}
    ON CONFLICT(chain_id) DO UPDATE
    SET
    "chain_id" = EXCLUDED."chain_id",
    "block_number" = EXCLUDED."block_number",
    "log_index" = EXCLUDED."log_index",
    "transaction_index" = EXCLUDED."transaction_index",
    "block_timestamp" = EXCLUDED."block_timestamp";
    `;
};

module.exports.readLatestChainMetadataState = (sql, chainId) => sql`
  SELECT *
  FROM public.chain_metadata
  WHERE chain_id = ${chainId}`;

module.exports.batchSetChainMetadata = (sql, entityDataArray) => {
  return (sql`
    INSERT INTO public.chain_metadata
  ${sql(
    entityDataArray,
    "chain_id",
    "start_block", // this is left out of the on conflict below as it only needs to be set once
    "block_height",
    "first_event_block_number",
    "latest_processed_block",
    "num_events_processed",
  )}
  ON CONFLICT(chain_id) DO UPDATE
  SET
  "chain_id" = EXCLUDED."chain_id",
  "first_event_block_number" = EXCLUDED."first_event_block_number",
  "latest_processed_block" = EXCLUDED."latest_processed_block",
  "num_events_processed" = EXCLUDED."num_events_processed",
  "block_height" = EXCLUDED."block_height";`).then(res => {

  }).catch(err => {
    console.log("errored", err)
  });
};

module.exports.setChainMetadataBlockHeight = (sql, entityDataArray) => {
  return (sql`
    INSERT INTO public.chain_metadata
  ${sql(
    entityDataArray,
    "chain_id",
    "start_block", // this is left out of the on conflict below as it only needs to be set once
    "block_height"
  )}
  ON CONFLICT(chain_id) DO UPDATE
  SET
  "chain_id" = EXCLUDED."chain_id",
  "block_height" = EXCLUDED."block_height";`).then(res => {

  }).catch(err => {
    console.log("errored", err)
  });
};

module.exports.readLatestRawEventsBlockNumberProcessedOnChainId = (
  sql,
  chainId
) => sql`
  SELECT block_number
  FROM "public"."raw_events"
  WHERE chain_id = ${chainId}
  ORDER BY event_id DESC
  LIMIT 1;`;

module.exports.readRawEventsEntities = (sql, entityIdArray) => sql`
  SELECT *
  FROM "public"."raw_events"
  WHERE (chain_id, event_id) IN ${sql(entityIdArray)}`;

module.exports.getRawEventsPageGtOrEqEventId = (
  sql,
  chainId,
  eventId,
  limit,
  contractAddresses
) => sql`
  SELECT *
  FROM "public"."raw_events"
  WHERE "chain_id" = ${chainId}
  AND "event_id" >= ${eventId}
  AND "src_address" IN ${sql(contractAddresses)}
  ORDER BY "event_id" ASC
  LIMIT ${limit}
`;

module.exports.getRawEventsPageWithinEventIdRangeInclusive = (
  sql,
  chainId,
  fromEventIdInclusive,
  toEventIdInclusive,
  limit,
  contractAddresses
) => sql`
  SELECT *
  FROM public.raw_events
  WHERE "chain_id" = ${chainId}
  AND "event_id" >= ${fromEventIdInclusive}
  AND "event_id" <= ${toEventIdInclusive}
  AND "src_address" IN ${sql(contractAddresses)}
  ORDER BY "event_id" ASC
  LIMIT ${limit}
`;

const batchSetRawEventsCore = (sql, entityDataArray) => {
  return sql`
    INSERT INTO "public"."raw_events"
  ${sql(
    entityDataArray,
    "chain_id",
    "event_id",
    "block_number",
    "log_index",
    "transaction_index",
    "transaction_hash",
    "src_address",
    "block_hash",
    "block_timestamp",
    "event_type",
    "params"
  )}
    ON CONFLICT(chain_id, event_id) DO UPDATE
    SET
    "chain_id" = EXCLUDED."chain_id",
    "event_id" = EXCLUDED."event_id",
    "block_number" = EXCLUDED."block_number",
    "log_index" = EXCLUDED."log_index",
    "transaction_index" = EXCLUDED."transaction_index",
    "transaction_hash" = EXCLUDED."transaction_hash",
    "src_address" = EXCLUDED."src_address",
    "block_hash" = EXCLUDED."block_hash",
    "block_timestamp" = EXCLUDED."block_timestamp",
    "event_type" = EXCLUDED."event_type",
    "params" = EXCLUDED."params";`;
};

const chunkBatchQuery = (
  sql,
  entityDataArray,
  queryToExecute
) => {
  const promises = [];

  // Split entityDataArray into chunks of MAX_ITEMS_PER_QUERY
  for (let i = 0; i < entityDataArray.length; i += MAX_ITEMS_PER_QUERY) {
    const chunk = entityDataArray.slice(i, i + MAX_ITEMS_PER_QUERY);

    promises.push(queryToExecute(sql, chunk));
  }

  // Execute all promises
  return Promise.all(promises).catch(e => {
    console.error("Sql query failed", e);
    throw e;
    });
};

module.exports.batchSetRawEvents = (sql, entityDataArray) => {
  return chunkBatchQuery(
    sql,
    entityDataArray,
    batchSetRawEventsCore
  );
};

module.exports.batchDeleteRawEvents = (sql, entityIdArray) => sql`
  DELETE
  FROM "public"."raw_events"
  WHERE (chain_id, event_id) IN ${sql(entityIdArray)};`;
// end db operations for raw_events

module.exports.readDynamicContractsOnChainIdAtOrBeforeBlock = (
  sql,
  chainId,
  block_number
) => sql`
  SELECT c.contract_address, c.contract_type, c.event_id
  FROM "public"."dynamic_contract_registry" as c
  JOIN raw_events e ON c.chain_id = e.chain_id
  AND c.event_id = e.event_id
  WHERE e.block_number <= ${block_number} AND e.chain_id = ${chainId};`;

//Start db operations dynamic_contract_registry
module.exports.readDynamicContractRegistryEntities = (
  sql,
  entityIdArray
) => sql`
  SELECT *
  FROM "public"."dynamic_contract_registry"
  WHERE (chain_id, contract_address) IN ${sql(entityIdArray)}`;

const batchSetDynamicContractRegistryCore = (sql, entityDataArray) => {
  return sql`
    INSERT INTO "public"."dynamic_contract_registry"
  ${sql(
    entityDataArray,
    "chain_id",
    "event_id",
    "contract_address",
    "contract_type"
  )}
    ON CONFLICT(chain_id, contract_address) DO UPDATE
    SET
    "chain_id" = EXCLUDED."chain_id",
    "event_id" = EXCLUDED."event_id",
    "contract_address" = EXCLUDED."contract_address",
    "contract_type" = EXCLUDED."contract_type";`;
};

module.exports.batchSetDynamicContractRegistry = (sql, entityDataArray) => {
  return chunkBatchQuery(
    sql,
    entityDataArray,
    batchSetDynamicContractRegistryCore
  );
};

module.exports.batchDeleteDynamicContractRegistry = (sql, entityIdArray) => sql`
  DELETE
  FROM "public"."dynamic_contract_registry"
  WHERE (chain_id, contract_address) IN ${sql(entityIdArray)};`;
// end db operations for dynamic_contract_registry

//////////////////////////////////////////////
// DB operations for Swap:
//////////////////////////////////////////////

module.exports.readSwapEntities = (sql, entityIdArray) => sql`
SELECT 
"amount0",
"amount1",
"id",
"liquidity",
"recipient",
"sender",
"sqrtPriceX96",
"tick"
FROM "public"."Swap"
WHERE id IN ${sql(entityIdArray)};`;

const batchSetSwapCore = (sql, entityDataArray) => {
  return sql`
    INSERT INTO "public"."Swap"
${sql(entityDataArray,
    "amount0",
    "amount1",
    "id",
    "liquidity",
    "recipient",
    "sender",
    "sqrtPriceX96",
    "tick"
  )}
  ON CONFLICT(id) DO UPDATE
  SET
  "amount0" = EXCLUDED."amount0",
  "amount1" = EXCLUDED."amount1",
  "id" = EXCLUDED."id",
  "liquidity" = EXCLUDED."liquidity",
  "recipient" = EXCLUDED."recipient",
  "sender" = EXCLUDED."sender",
  "sqrtPriceX96" = EXCLUDED."sqrtPriceX96",
  "tick" = EXCLUDED."tick"
  `;
}

module.exports.batchSetSwap = (sql, entityDataArray) => {

  return chunkBatchQuery(
    sql, 
    entityDataArray, 
    batchSetSwapCore
  );
}

module.exports.batchDeleteSwap = (sql, entityIdArray) => sql`
DELETE
FROM "public"."Swap"
WHERE id IN ${sql(entityIdArray)};`
// end db operations for Swap

