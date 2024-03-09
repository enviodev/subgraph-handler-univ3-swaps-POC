//*************
//***ENTITIES**
//*************
@spice @genType.as("Id")
type id = string

@@warning("-30")
@genType
type rec swapLoaderConfig = bool

@@warning("+30")
@genType
type entityRead = SwapRead(id)

@genType
type rawEventsEntity = {
  @as("chain_id") chainId: int,
  @as("event_id") eventId: string,
  @as("block_number") blockNumber: int,
  @as("log_index") logIndex: int,
  @as("transaction_index") transactionIndex: int,
  @as("transaction_hash") transactionHash: string,
  @as("src_address") srcAddress: Ethers.ethAddress,
  @as("block_hash") blockHash: string,
  @as("block_timestamp") blockTimestamp: int,
  @as("event_type") eventType: Js.Json.t,
  params: string,
}

@genType
type dynamicContractRegistryEntity = {
  @as("chain_id") chainId: int,
  @as("event_id") eventId: Ethers.BigInt.t,
  @as("contract_address") contractAddress: Ethers.ethAddress,
  @as("contract_type") contractType: string,
}

@spice @genType.as("SwapEntity")
type swapEntity = {
  amount0: Ethers.BigInt.t,
  amount1: Ethers.BigInt.t,
  blockNumber: int,
  blockTimestamp: int,
  id: id,
  liquidity: Ethers.BigInt.t,
  liquidityPool: string,
  recipient: string,
  sender: string,
  sqrtPriceX96: Ethers.BigInt.t,
  tick: Ethers.BigInt.t,
  transactionHash: string,
}

type entity = SwapEntity(swapEntity)

type dbOp = Read | Set | Delete

@genType
type inMemoryStoreRow<'a> = {
  dbOp: dbOp,
  entity: 'a,
}

//*************
//**CONTRACTS**
//*************

@genType.as("EventLog")
type eventLog<'a> = {
  params: 'a,
  chainId: int,
  txOrigin: option<Ethers.ethAddress>,
  blockNumber: int,
  blockTimestamp: int,
  blockHash: string,
  srcAddress: Ethers.ethAddress,
  transactionHash: string,
  transactionIndex: int,
  logIndex: int,
}

module SwapContractContract = {
  module SwapEvent = {
    //Note: each parameter is using a binding of its index to help with binding in ethers
    //This handles both unamed params and also named params that clash with reserved keywords
    //eg. if an event param is called "values" it will clash since eventArgs will have a '.values()' iterator
    type ethersEventArgs = {
      @as("0") sender: Ethers.ethAddress,
      @as("1") recipient: Ethers.ethAddress,
      @as("2") amount0: Ethers.BigInt.t,
      @as("3") amount1: Ethers.BigInt.t,
      @as("4") sqrtPriceX96: Ethers.BigInt.t,
      @as("5") liquidity: Ethers.BigInt.t,
      @as("6") tick: Ethers.BigInt.t,
    }

    @spice @genType
    type eventArgs = {
      sender: Ethers.ethAddress,
      recipient: Ethers.ethAddress,
      amount0: Ethers.BigInt.t,
      amount1: Ethers.BigInt.t,
      sqrtPriceX96: Ethers.BigInt.t,
      liquidity: Ethers.BigInt.t,
      tick: Ethers.BigInt.t,
    }

    @genType.as("SwapContractContract_Swap_EventLog")
    type log = eventLog<eventArgs>

    // Entity: Swap
    type swapEntityHandlerContext = {
      get: id => option<swapEntity>,
      set: swapEntity => unit,
      delete: id => unit,
    }

    type swapEntityHandlerContextAsync = {
      get: id => promise<option<swapEntity>>,
      set: swapEntity => unit,
      delete: id => unit,
    }

    @genType
    type handlerContext = {
      log: Logs.userLogger,
      @as("Swap") swap: swapEntityHandlerContext,
    }
    @genType
    type handlerContextAsync = {
      log: Logs.userLogger,
      @as("Swap") swap: swapEntityHandlerContextAsync,
    }

    @genType
    type swapEntityLoaderContext = {load: id => unit}

    @genType
    type contractRegistrations = {
      //TODO only add contracts we've registered for the event in the config
      addSwapContract: Ethers.ethAddress => unit,
    }
    @genType
    type loaderContext = {
      log: Logs.userLogger,
      contractRegistration: contractRegistrations,
      @as("Swap") swap: swapEntityLoaderContext,
    }
  }
}

@deriving(accessors)
type event = SwapContractContract_Swap(eventLog<SwapContractContract.SwapEvent.eventArgs>)

@spice
type eventName = | @spice.as("SwapContract_Swap") SwapContract_Swap

let eventNameToString = (eventName: eventName) =>
  switch eventName {
  | SwapContract_Swap => "Swap"
  }

exception UnknownEvent(string, string)
let eventTopicToEventName = (contractName, topic0) =>
  switch (contractName, topic0) {
  | ("SwapContract", "0xc42079f94a6350d7e6235f29174924f928cc2ac818eb64fed8004e115fbcca67") =>
    SwapContract_Swap
  | (contractName, topic0) => UnknownEvent(contractName, topic0)->raise
  }

@genType
type chainId = int

type eventBatchQueueItem = {
  timestamp: int,
  chain: ChainMap.Chain.t,
  blockNumber: int,
  logIndex: int,
  event: event,
  //Default to false, if an event needs to
  //be reprocessed after it has loaded dynamic contracts
  //This gets set to true and does not try and reload events
  hasRegisteredDynamicContracts?: bool,
}
