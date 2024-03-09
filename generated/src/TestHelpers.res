open Belt

/***** TAKE NOTE ******
This is a hack to get genType to work!

In order for genType to produce recursive types, it needs to be at the 
root module of a file. If it's defined in a nested module it does not 
work. So all the MockDb types and internal functions are defined in TestHelpers_MockDb
and only public functions are recreated and exported from this module.

the following module:
```rescript
module MyModule = {
  @genType
  type rec a = {fieldB: b}
  @genType and b = {fieldA: a}
}
```

produces the following in ts:
```ts
// tslint:disable-next-line:interface-over-type-literal
export type MyModule_a = { readonly fieldB: b };

// tslint:disable-next-line:interface-over-type-literal
export type MyModule_b = { readonly fieldA: MyModule_a };
```

fieldB references type b which doesn't exist because it's defined
as MyModule_b
*/

module MockDb = {
  @genType
  let createMockDb = TestHelpers_MockDb.createMockDb
}

module EventFunctions = {
  //Note these are made into a record to make operate in the same way
  //for Res, JS and TS.

  /**
  The arguements that get passed to a "processEvent" helper function
  */
  @genType
  type eventProcessorArgs<'eventArgs> = {
    event: Types.eventLog<'eventArgs>,
    mockDb: TestHelpers_MockDb.t,
    chainId?: int,
  }

  /**
  The default chain ID to use (ethereum mainnet) if a user does not specify int the 
  eventProcessor helper
  */
  let \"DEFAULT_CHAIN_ID" = 1

  /**
  A function composer to help create individual processEvent functions
  */
  let makeEventProcessor = (
    ~contextCreator: Context.contextCreator<
      'eventArgs,
      'loaderContext,
      'handlerContextSync,
      'handlerContextAsync,
    >,
    ~getLoader: unit => Handlers.loader<_>,
    ~eventWithContextAccessor: (
      Types.eventLog<'eventArgs>,
      Context.genericContextCreatorFunctions<
        'loaderContext,
        'handlerContextSync,
        'handlerContextAsync,
      >,
    ) => Context.eventAndContext,
    ~eventName: Types.eventName,
    ~cb: TestHelpers_MockDb.t => unit,
  ) => {
    ({event, mockDb, ?chainId}) => {
      RegisterHandlers.registerAllHandlers()
      //The user can specify a chainId of an event or leave it off
      //and it will default to "DEFAULT_CHAIN_ID"
      let chainId = chainId->Option.getWithDefault(\"DEFAULT_CHAIN_ID")

      //Create an individual logging context for traceability
      let logger = Logging.createChild(
        ~params={
          "Context": `Test Processor for ${eventName
            ->Types.eventName_encode
            ->Js.Json.stringify} Event`,
          "Chain ID": chainId,
          "event": event,
        },
      )

      //Deep copy the data in mockDb, mutate the clone and return the clone
      //So no side effects occur here and state can be compared between process
      //steps
      let mockDbClone = mockDb->TestHelpers_MockDb.cloneMockDb

      let asyncGetters: Context.entityGetters = {
        getSwap: async id =>
          mockDbClone.entities.swap.get(id)->Belt.Option.mapWithDefault([], entity => [entity]),
      }

      //Construct a new instance of an in memory store to run for the given event
      let inMemoryStore = IO.InMemoryStore.make()

      //Construct a context with the inMemory store for the given event to run
      //loaders and handlers
      let context = contextCreator(~event, ~inMemoryStore, ~chainId, ~logger, ~asyncGetters)

      let loaderContext = context.getLoaderContext()

      let loader = getLoader()

      //Run the loader, to get all the read values/contract registrations
      //into the context
      loader({event, context: loaderContext})

      //Get all the entities are requested to be loaded from the mockDB
      let entityBatch = context.getEntitiesToLoad()

      //Load requested entities from the cloned mockDb into the inMemoryStore
      mockDbClone->TestHelpers_MockDb.loadEntitiesToInMemStore(~entityBatch, ~inMemoryStore)

      //Run the event and handler context through the eventRouter
      //With inMemoryStore
      let eventAndContext: Context.eventRouterEventAndContext = {
        chainId,
        event: eventWithContextAccessor(event, context),
      }

      eventAndContext->EventProcessing.eventRouter(
        ~latestProcessedBlocks=EventProcessing.EventsProcessed.makeEmpty(),
        ~inMemoryStore,
        ~cb=res =>
          switch res {
          | Ok(_latestProcessedBlocks) =>
            //Now that the processing is finished. Simulate writing a batch
            //(Although in this case a batch of 1 event only) to the cloned mockDb
            mockDbClone->TestHelpers_MockDb.writeFromMemoryStore(~inMemoryStore)

            //Return the cloned mock db
            cb(mockDbClone)

          | Error(errHandler) =>
            errHandler->ErrorHandling.log
            errHandler->ErrorHandling.raiseExn
          },
      )
    }
  }

  /**Creates a mock event processor, wrapping the callback in a Promise for async use*/
  let makeAsyncEventProcessor = (
    ~contextCreator,
    ~getLoader,
    ~eventWithContextAccessor,
    ~eventName,
    eventProcessorArgs,
  ) => {
    Promise.make((res, _rej) => {
      makeEventProcessor(
        ~contextCreator,
        ~getLoader,
        ~eventWithContextAccessor,
        ~eventName,
        ~cb=mockDb => res(. mockDb),
        eventProcessorArgs,
      )
    })
  }

  /**
  Creates a mock event processor, exposing the return of the callback in the return,
  raises an exception if the handler is async
  */
  let makeSyncEventProcessor = (
    ~contextCreator,
    ~getLoader,
    ~eventWithContextAccessor,
    ~eventName,
    eventProcessorArgs,
  ) => {
    //Dangerously set to None, nextMockDb will be set in the callback
    let nextMockDb = ref(None)
    makeEventProcessor(
      ~contextCreator,
      ~getLoader,
      ~eventWithContextAccessor,
      ~eventName,
      ~cb=mockDb => nextMockDb := Some(mockDb),
      eventProcessorArgs,
    )

    //The callback is called synchronously so nextMockDb should be set.
    //In the case it's not set it would mean that the user is using an async handler
    //in which case we want to error and alert the user.
    switch nextMockDb.contents {
    | Some(mockDb) => mockDb
    | None =>
      Js.Exn.raiseError(
        "processEvent failed because handler is not synchronous, please use processEventAsync instead",
      )
    }
  }

  /**
  Optional params for all additional data related to an eventLog
  */
  @genType
  type mockEventData = {
    blockNumber?: int,
    blockTimestamp?: int,
    blockHash?: string,
    chainId?: int,
    srcAddress?: Ethers.ethAddress,
    transactionHash?: string,
    transactionIndex?: int,
    txOrigin?: option<Ethers.ethAddress>,
    logIndex?: int,
  }

  /**
  Applies optional paramters with defaults for all common eventLog field
  */
  let makeEventMocker = (
    ~params: 'eventParams,
    ~mockEventData: option<mockEventData>,
  ): Types.eventLog<'eventParams> => {
    let {
      ?blockNumber,
      ?blockTimestamp,
      ?blockHash,
      ?srcAddress,
      ?chainId,
      ?transactionHash,
      ?transactionIndex,
      ?logIndex,
      ?txOrigin,
    } =
      mockEventData->Belt.Option.getWithDefault({})

    {
      params,
      txOrigin: txOrigin->Belt.Option.flatMap(i => i),
      chainId: chainId->Belt.Option.getWithDefault(1),
      blockNumber: blockNumber->Belt.Option.getWithDefault(0),
      blockTimestamp: blockTimestamp->Belt.Option.getWithDefault(0),
      blockHash: blockHash->Belt.Option.getWithDefault(Ethers.Constants.zeroHash),
      srcAddress: srcAddress->Belt.Option.getWithDefault(Ethers.Addresses.defaultAddress),
      transactionHash: transactionHash->Belt.Option.getWithDefault(Ethers.Constants.zeroHash),
      transactionIndex: transactionIndex->Belt.Option.getWithDefault(0),
      logIndex: logIndex->Belt.Option.getWithDefault(0),
    }
  }
}

module SwapContract = {
  module Swap = {
    @genType
    let processEvent = EventFunctions.makeSyncEventProcessor(
      ~contextCreator=Context.SwapContractContract.SwapEvent.contextCreator,
      ~getLoader=Handlers.SwapContractContract.Swap.getLoader,
      ~eventWithContextAccessor=Context.swapContractContract_SwapWithContext,
      ~eventName=Types.SwapContract_Swap,
    )

    @genType
    let processEventAsync = EventFunctions.makeAsyncEventProcessor(
      ~contextCreator=Context.SwapContractContract.SwapEvent.contextCreator,
      ~getLoader=Handlers.SwapContractContract.Swap.getLoader,
      ~eventWithContextAccessor=Context.swapContractContract_SwapWithContext,
      ~eventName=Types.SwapContract_Swap,
    )

    @genType
    type createMockArgs = {
      sender?: Ethers.ethAddress,
      recipient?: Ethers.ethAddress,
      amount0?: Ethers.BigInt.t,
      amount1?: Ethers.BigInt.t,
      sqrtPriceX96?: Ethers.BigInt.t,
      liquidity?: Ethers.BigInt.t,
      tick?: Ethers.BigInt.t,
      mockEventData?: EventFunctions.mockEventData,
    }

    @genType
    let createMockEvent = args => {
      let {
        ?sender,
        ?recipient,
        ?amount0,
        ?amount1,
        ?sqrtPriceX96,
        ?liquidity,
        ?tick,
        ?mockEventData,
      } = args

      let params: Types.SwapContractContract.SwapEvent.eventArgs = {
        sender: sender->Belt.Option.getWithDefault(Ethers.Addresses.defaultAddress),
        recipient: recipient->Belt.Option.getWithDefault(Ethers.Addresses.defaultAddress),
        amount0: amount0->Belt.Option.getWithDefault(Ethers.BigInt.zero),
        amount1: amount1->Belt.Option.getWithDefault(Ethers.BigInt.zero),
        sqrtPriceX96: sqrtPriceX96->Belt.Option.getWithDefault(Ethers.BigInt.zero),
        liquidity: liquidity->Belt.Option.getWithDefault(Ethers.BigInt.zero),
        tick: tick->Belt.Option.getWithDefault(Ethers.BigInt.zero),
      }

      EventFunctions.makeEventMocker(~params, ~mockEventData)
    }
  }
}
