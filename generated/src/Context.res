type entityGetters = {getSwap: Types.id => promise<array<Types.swapEntity>>}

@genType
type genericContextCreatorFunctions<'loaderContext, 'handlerContextSync, 'handlerContextAsync> = {
  logger: Pino.t,
  log: Logs.userLogger,
  getLoaderContext: unit => 'loaderContext,
  getHandlerContextSync: unit => 'handlerContextSync,
  getHandlerContextAsync: unit => 'handlerContextAsync,
  getEntitiesToLoad: unit => array<Types.entityRead>,
  getAddedDynamicContractRegistrations: unit => array<Types.dynamicContractRegistryEntity>,
}

type contextCreator<'eventArgs, 'loaderContext, 'handlerContext, 'handlerContextAsync> = (
  ~inMemoryStore: IO.InMemoryStore.t,
  ~chainId: int,
  ~event: Types.eventLog<'eventArgs>,
  ~logger: Pino.t,
  ~asyncGetters: entityGetters,
) => genericContextCreatorFunctions<'loaderContext, 'handlerContext, 'handlerContextAsync>

exception UnableToLoadNonNullableLinkedEntity(string)
exception LinkedEntityNotAvailableInSyncHandler(string)

module SwapContractContract = {
  module SwapEvent = {
    type loaderContext = Types.SwapContractContract.SwapEvent.loaderContext
    type handlerContext = Types.SwapContractContract.SwapEvent.handlerContext
    type handlerContextAsync = Types.SwapContractContract.SwapEvent.handlerContextAsync
    type context = genericContextCreatorFunctions<
      loaderContext,
      handlerContext,
      handlerContextAsync,
    >

    let contextCreator: contextCreator<
      Types.SwapContractContract.SwapEvent.eventArgs,
      loaderContext,
      handlerContext,
      handlerContextAsync,
    > = (~inMemoryStore, ~chainId, ~event, ~logger, ~asyncGetters) => {
      // NOTE: we could optimise this code to onle create a logger if there was a log called.
      let logger = logger->Logging.createChildFrom(
        ~logger=_,
        ~params={
          "context": "SwapContract.Swap",
          "chainId": chainId,
          "block": event.blockNumber,
          "logIndex": event.logIndex,
          "txHash": event.transactionHash,
        },
      )

      let contextLogger: Logs.userLogger = {
        info: (message: string) => logger->Logging.uinfo(message),
        debug: (message: string) => logger->Logging.udebug(message),
        warn: (message: string) => logger->Logging.uwarn(message),
        error: (message: string) => logger->Logging.uerror(message),
        errorWithExn: (exn: option<Js.Exn.t>, message: string) =>
          logger->Logging.uerrorWithExn(exn, message),
      }

      let optSetOfIds_swap: Set.t<Types.id> = Set.make()

      let entitiesToLoad: array<Types.entityRead> = []

      let addedDynamicContractRegistrations: array<Types.dynamicContractRegistryEntity> = []

      //Loader context can be defined as a value and the getter can return that value

      @warning("-16")
      let loaderContext: loaderContext = {
        log: contextLogger,
        contractRegistration: {
          //TODO only add contracts we've registered for the event in the config
          addSwapContract: (contractAddress: Ethers.ethAddress) => {
            let eventId = EventUtils.packEventIndex(
              ~blockNumber=event.blockNumber,
              ~logIndex=event.logIndex,
            )
            let dynamicContractRegistration: Types.dynamicContractRegistryEntity = {
              chainId,
              eventId,
              contractAddress,
              contractType: "SwapContract",
            }

            addedDynamicContractRegistrations->Js.Array2.push(dynamicContractRegistration)->ignore

            inMemoryStore.dynamicContractRegistry->IO.InMemoryStore.DynamicContractRegistry.set(
              ~key={chainId, contractAddress},
              ~entity=dynamicContractRegistration,
              ~dbOp=Set,
            )
          },
        },
        swap: {
          load: (id: Types.id) => {
            let _ = optSetOfIds_swap->Set.add(id)
            let _ = Js.Array2.push(entitiesToLoad, Types.SwapRead(id))
          },
        },
      }

      //handler context must be defined as a getter functoin so that it can construct the context
      //without stale values whenever it is used
      let getHandlerContextSync: unit => handlerContext = () => {
        {
          log: contextLogger,
          swap: {
            set: entity => {
              inMemoryStore.swap->IO.InMemoryStore.Swap.set(
                ~key=entity.id,
                ~entity,
                ~dbOp=Types.Set,
              )
            },
            delete: id =>
              Logging.warn(`[unimplemented delete] can't delete entity(swap) with ID ${id}.`),
            get: (id: Types.id) => {
              if optSetOfIds_swap->Set.has(id) {
                inMemoryStore.swap->IO.InMemoryStore.Swap.get(id)
              } else {
                Logging.warn(
                  `The loader for a "Swap" of entity with id "${id}" was not used please add it to your default loader function (ie. place 'context.swap.load("${id}")' inside your loader) to avoid unexpected behaviour. This is a runtime validation check.`,
                )

                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                inMemoryStore.swap->IO.InMemoryStore.Swap.get(id)

                // TODO: add a further step to synchronously try fetch this from the DB if it isn't in the in-memory store - similar to this PR: https://github.com/Float-Capital/indexer/pull/759
              }
            },
          },
        }
      }

      let getHandlerContextAsync = (): handlerContextAsync => {
        {
          log: contextLogger,
          swap: {
            set: entity => {
              inMemoryStore.swap->IO.InMemoryStore.Swap.set(
                ~key=entity.id,
                ~entity,
                ~dbOp=Types.Set,
              )
            },
            delete: id =>
              Logging.warn(`[unimplemented delete] can't delete entity(swap) with ID ${id}.`),
            get: async (id: Types.id) => {
              if optSetOfIds_swap->Set.has(id) {
                inMemoryStore.swap->IO.InMemoryStore.Swap.get(id)
              } else {
                // NOTE: this will still return the value if it exists in the in-memory store (despite the loader not being run).
                switch inMemoryStore.swap->IO.InMemoryStore.Swap.get(id) {
                | Some(entity) => Some(entity)
                | None =>
                  let entities = await asyncGetters.getSwap(id)

                  switch entities->Belt.Array.get(0) {
                  | Some(entity) =>
                    // TODO: make this work with the test framework too.
                    IO.InMemoryStore.Swap.set(
                      inMemoryStore.swap,
                      ~key=entity.id,
                      ~dbOp=Types.Read,
                      ~entity,
                    )
                    Some(entity)
                  | None => None
                  }
                }
              }
            },
          },
        }
      }

      {
        logger,
        log: contextLogger,
        getEntitiesToLoad: () => entitiesToLoad,
        getAddedDynamicContractRegistrations: () => addedDynamicContractRegistrations,
        getLoaderContext: () => loaderContext,
        getHandlerContextSync,
        getHandlerContextAsync,
      }
    }
  }
}

@deriving(accessors)
type eventAndContext =
  | SwapContractContract_SwapWithContext(
      Types.eventLog<Types.SwapContractContract.SwapEvent.eventArgs>,
      SwapContractContract.SwapEvent.context,
    )

type eventRouterEventAndContext = {
  chainId: int,
  event: eventAndContext,
}
