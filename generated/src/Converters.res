exception UndefinedEvent(string)
let eventStringToEvent = (eventName: string, contractName: string): Types.eventName => {
  switch (eventName, contractName) {
  | ("Swap", "SwapContract") => SwapContract_Swap
  | _ => UndefinedEvent(eventName)->raise
  }
}

module SwapContract = {
  let convertSwapViemDecodedEvent: Viem.decodedEvent<'a> => Viem.decodedEvent<
    Types.SwapContractContract.SwapEvent.eventArgs,
  > = Obj.magic

  let convertSwapLogDescription = (log: Ethers.logDescription<'a>): Ethers.logDescription<
    Types.SwapContractContract.SwapEvent.eventArgs,
  > => {
    //Convert from the ethersLog type with indexs as keys to named key value object
    let ethersLog: Ethers.logDescription<Types.SwapContractContract.SwapEvent.ethersEventArgs> =
      log->Obj.magic
    let {args, name, signature, topic} = ethersLog

    {
      name,
      signature,
      topic,
      args: {
        sender: args.sender,
        recipient: args.recipient,
        amount0: args.amount0,
        amount1: args.amount1,
        sqrtPriceX96: args.sqrtPriceX96,
        liquidity: args.liquidity,
        tick: args.tick,
      },
    }
  }

  let convertSwapLog = (
    logDescription: Ethers.logDescription<Types.SwapContractContract.SwapEvent.eventArgs>,
    ~log: Ethers.log,
    ~blockTimestamp: int,
    ~chainId: int,
    ~txOrigin: option<Ethers.ethAddress>,
  ) => {
    let params: Types.SwapContractContract.SwapEvent.eventArgs = {
      sender: logDescription.args.sender,
      recipient: logDescription.args.recipient,
      amount0: logDescription.args.amount0,
      amount1: logDescription.args.amount1,
      sqrtPriceX96: logDescription.args.sqrtPriceX96,
      liquidity: logDescription.args.liquidity,
      tick: logDescription.args.tick,
    }

    let swapLog: Types.eventLog<Types.SwapContractContract.SwapEvent.eventArgs> = {
      params,
      chainId,
      txOrigin,
      blockNumber: log.blockNumber,
      blockTimestamp,
      blockHash: log.blockHash,
      srcAddress: log.address,
      transactionHash: log.transactionHash,
      transactionIndex: log.transactionIndex,
      logIndex: log.logIndex,
    }

    Types.SwapContractContract_Swap(swapLog)
  }
  let convertSwapLogViem = (
    decodedEvent: Viem.decodedEvent<Types.SwapContractContract.SwapEvent.eventArgs>,
    ~log: Ethers.log,
    ~blockTimestamp: int,
    ~chainId: int,
    ~txOrigin: option<Ethers.ethAddress>,
  ) => {
    let params: Types.SwapContractContract.SwapEvent.eventArgs = {
      sender: decodedEvent.args.sender,
      recipient: decodedEvent.args.recipient,
      amount0: decodedEvent.args.amount0,
      amount1: decodedEvent.args.amount1,
      sqrtPriceX96: decodedEvent.args.sqrtPriceX96,
      liquidity: decodedEvent.args.liquidity,
      tick: decodedEvent.args.tick,
    }

    let swapLog: Types.eventLog<Types.SwapContractContract.SwapEvent.eventArgs> = {
      params,
      chainId,
      txOrigin,
      blockNumber: log.blockNumber,
      blockTimestamp,
      blockHash: log.blockHash,
      srcAddress: log.address,
      transactionHash: log.transactionHash,
      transactionIndex: log.transactionIndex,
      logIndex: log.logIndex,
    }

    Types.SwapContractContract_Swap(swapLog)
  }

  let convertSwapDecodedEventParams = (
    decodedEvent: HyperSyncClient.Decoder.decodedEvent,
  ): Types.SwapContractContract.SwapEvent.eventArgs => {
    open Belt
    let fields = ["sender", "recipient", "amount0", "amount1", "sqrtPriceX96", "liquidity", "tick"]
    let values =
      Array.concat(decodedEvent.indexed, decodedEvent.body)->Array.map(
        HyperSyncClient.Decoder.toUnderlying,
      )
    Array.zip(fields, values)->Js.Dict.fromArray->Obj.magic
  }
}

exception ParseError(Ethers.Interface.parseLogError)
exception UnregisteredContract(Ethers.ethAddress)

let parseEventEthers = (
  ~log,
  ~blockTimestamp,
  ~contractInterfaceManager,
  ~chainId,
  ~txOrigin,
): Belt.Result.t<Types.event, _> => {
  let logDescriptionResult = contractInterfaceManager->ContractInterfaceManager.parseLogEthers(~log)
  switch logDescriptionResult {
  | Error(e) =>
    switch e {
    | ParseError(parseError) => ParseError(parseError)
    | UndefinedInterface(contractAddress) => UnregisteredContract(contractAddress)
    }->Error

  | Ok(logDescription) =>
    switch contractInterfaceManager->ContractInterfaceManager.getContractNameFromAddress(
      ~contractAddress=log.address,
    ) {
    | None => Error(UnregisteredContract(log.address))
    | Some(contractName) =>
      let event = switch eventStringToEvent(logDescription.name, contractName) {
      | SwapContract_Swap =>
        logDescription
        ->SwapContract.convertSwapLogDescription
        ->SwapContract.convertSwapLog(~log, ~blockTimestamp, ~chainId, ~txOrigin)
      }

      Ok(event)
    }
  }
}

let makeEventLog = (
  params: 'args,
  ~log: Ethers.log,
  ~blockTimestamp: int,
  ~chainId: int,
  ~txOrigin: option<Ethers.ethAddress>,
): Types.eventLog<'args> => {
  chainId,
  params,
  txOrigin,
  blockNumber: log.blockNumber,
  blockTimestamp,
  blockHash: log.blockHash,
  srcAddress: log.address,
  transactionHash: log.transactionHash,
  transactionIndex: log.transactionIndex,
  logIndex: log.logIndex,
}

let convertDecodedEvent = (
  event: HyperSyncClient.Decoder.decodedEvent,
  ~contractInterfaceManager,
  ~log: Ethers.log,
  ~blockTimestamp,
  ~chainId,
  ~txOrigin: option<Ethers.ethAddress>,
): result<Types.event, _> => {
  switch contractInterfaceManager->ContractInterfaceManager.getContractNameFromAddress(
    ~contractAddress=log.address,
  ) {
  | None => Error(UnregisteredContract(log.address))
  | Some(contractName) =>
    let event = switch Types.eventTopicToEventName(contractName, log.topics[0]) {
    | SwapContract_Swap =>
      event
      ->SwapContract.convertSwapDecodedEventParams
      ->makeEventLog(~log, ~blockTimestamp, ~chainId, ~txOrigin)
      ->Types.SwapContractContract_Swap
    }
    Ok(event)
  }
}

let parseEvent = (
  ~log,
  ~blockTimestamp,
  ~contractInterfaceManager,
  ~chainId,
  ~txOrigin,
): Belt.Result.t<Types.event, _> => {
  let decodedEventResult = contractInterfaceManager->ContractInterfaceManager.parseLogViem(~log)
  switch decodedEventResult {
  | Error(e) =>
    switch e {
    | ParseError(parseError) => ParseError(parseError)
    | UndefinedInterface(contractAddress) => UnregisteredContract(contractAddress)
    }->Error

  | Ok(decodedEvent) =>
    switch contractInterfaceManager->ContractInterfaceManager.getContractNameFromAddress(
      ~contractAddress=log.address,
    ) {
    | None => Error(UnregisteredContract(log.address))
    | Some(contractName) =>
      let event = switch eventStringToEvent(decodedEvent.eventName, contractName) {
      | SwapContract_Swap =>
        decodedEvent
        ->SwapContract.convertSwapViemDecodedEvent
        ->SwapContract.convertSwapLogViem(~log, ~blockTimestamp, ~chainId, ~txOrigin)
      }

      Ok(event)
    }
  }
}

let decodeRawEventWith = (
  rawEvent: Types.rawEventsEntity,
  ~decoder: Spice.decoder<'a>,
  ~variantAccessor: Types.eventLog<'a> => Types.event,
  ~chain,
  ~txOrigin: option<Ethers.ethAddress>,
): Spice.result<Types.eventBatchQueueItem> => {
  switch rawEvent.params->Js.Json.parseExn {
  | exception exn =>
    let message =
      exn
      ->Js.Exn.asJsExn
      ->Belt.Option.flatMap(jsexn => jsexn->Js.Exn.message)
      ->Belt.Option.getWithDefault("No message on exn")

    Spice.error(`Failed at JSON.parse. Error: ${message}`, rawEvent.params->Obj.magic)
  | v => Ok(v)
  }
  ->Belt.Result.flatMap(json => {
    json->decoder
  })
  ->Belt.Result.map(params => {
    let event = {
      chainId: rawEvent.chainId,
      txOrigin,
      blockNumber: rawEvent.blockNumber,
      blockTimestamp: rawEvent.blockTimestamp,
      blockHash: rawEvent.blockHash,
      srcAddress: rawEvent.srcAddress,
      transactionHash: rawEvent.transactionHash,
      transactionIndex: rawEvent.transactionIndex,
      logIndex: rawEvent.logIndex,
      params,
    }->variantAccessor

    let queueItem: Types.eventBatchQueueItem = {
      timestamp: rawEvent.blockTimestamp,
      chain,
      blockNumber: rawEvent.blockNumber,
      logIndex: rawEvent.logIndex,
      event,
    }

    queueItem
  })
}

let parseRawEvent = (
  rawEvent: Types.rawEventsEntity,
  ~chain,
  ~txOrigin: option<Ethers.ethAddress>,
): Spice.result<Types.eventBatchQueueItem> => {
  rawEvent.eventType
  ->Types.eventName_decode
  ->Belt.Result.flatMap(eventName => {
    switch eventName {
    | SwapContract_Swap =>
      rawEvent->decodeRawEventWith(
        ~decoder=Types.SwapContractContract.SwapEvent.eventArgs_decode,
        ~variantAccessor=Types.swapContractContract_Swap,
        ~chain,
        ~txOrigin,
      )
    }
  })
}
