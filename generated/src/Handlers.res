type functionRegister = Loader | Handler

let mapFunctionRegisterName = (functionRegister: functionRegister) => {
  switch functionRegister {
  | Loader => "Loader"
  | Handler => "Handler"
  }
}

// This set makes sure that the warning doesn't print for every event of a type, but rather only prints the first time.
let hasPrintedWarning = Set.make()

@genType
type handlerArgs<'event, 'context> = {
  event: Types.eventLog<'event>,
  context: 'context,
}

@genType
type handlerFunction<'eventArgs, 'context, 'returned> = handlerArgs<
  'eventArgs,
  'context,
> => 'returned

@genType
type handlerWithContextGetter<
  'eventArgs,
  'context,
  'returned,
  'loaderContext,
  'handlerContextSync,
  'handlerContextAsync,
> = {
  handler: handlerFunction<'eventArgs, 'context, 'returned>,
  contextGetter: Context.genericContextCreatorFunctions<
    'loaderContext,
    'handlerContextSync,
    'handlerContextAsync,
  > => 'context,
}

@genType
type handlerWithContextGetterSyncAsync<
  'eventArgs,
  'loaderContext,
  'handlerContextSync,
  'handlerContextAsync,
> = SyncAsync.t<
  handlerWithContextGetter<
    'eventArgs,
    'handlerContextSync,
    unit,
    'loaderContext,
    'handlerContextSync,
    'handlerContextAsync,
  >,
  handlerWithContextGetter<
    'eventArgs,
    'handlerContextAsync,
    promise<unit>,
    'loaderContext,
    'handlerContextSync,
    'handlerContextAsync,
  >,
>

@genType
type loader<'eventArgs, 'loaderContext> = handlerArgs<'eventArgs, 'loaderContext> => unit

let getDefaultLoaderHandler: (
  ~functionRegister: functionRegister,
  ~eventName: string,
  handlerArgs<'eventArgs, 'loaderContext>,
) => unit = (~functionRegister, ~eventName, _loaderArgs) => {
  let functionName = mapFunctionRegisterName(functionRegister)

  // Here we use this key to prevent flooding the users terminal with
  let repeatKey = `${eventName}-${functionName}`
  if !(hasPrintedWarning->Set.has(repeatKey)) {
    // Here are docs on the 'terminal hyperlink' formatting that I use to link to the docs: https://gist.github.com/egmontkob/eb114294efbcd5adb1944c9f3cb5feda
    Logging.warn(
      `Skipped ${eventName} in the ${functionName}, as there is no ${functionName} registered. You need to implement a ${eventName}${functionName} method in your handler file or ignore this warning if you don't intend to implement it. Here are our docs on this topic: \\u001b]8;;https://docs.envio.dev/docs/event-handlers\u0007https://docs.envio.dev/docs/event-handlers\u001b]8;;\u0007`,
    )
    let _ = hasPrintedWarning->Set.add(repeatKey)
  }
}

let getDefaultLoaderHandlerWithContextGetter = (~functionRegister, ~eventName) => SyncAsync.Sync({
  handler: getDefaultLoaderHandler(~functionRegister, ~eventName),
  contextGetter: ctx => ctx.getHandlerContextSync(),
})

module SwapContractContract = {
  module Swap = {
    open Types.SwapContractContract.SwapEvent

    type handlerWithContextGetter = handlerWithContextGetterSyncAsync<
      eventArgs,
      loaderContext,
      handlerContext,
      handlerContextAsync,
    >

    %%private(
      let swapLoader: ref<option<loader<eventArgs, loaderContext>>> = ref(None)
      let swapHandler: ref<option<handlerWithContextGetter>> = ref(None)
    )

    @genType
    let loader = loader => {
      swapLoader := Some(loader)
    }

    @genType
    let handler = handler => {
      swapHandler := Some(Sync({handler, contextGetter: ctx => ctx.getHandlerContextSync()}))
    }

    // Silence the "this statement never returns (or has an unsound type.)" warning in the case that the user hasn't specified `isAsync` in their config file yet.
    @warning("-21") @genType
    let handlerAsync = handler => {
      Js.Exn.raiseError("Please add 'isAsync: true' to your config.yaml file to enable Async Mode.")

      swapHandler := Some(Async({handler, contextGetter: ctx => ctx.getHandlerContextAsync()}))
    }

    let getLoader = () =>
      swapLoader.contents->Belt.Option.getWithDefault(
        getDefaultLoaderHandler(~eventName="Swap", ~functionRegister=Loader),
      )

    let getHandler = () =>
      switch swapHandler.contents {
      | Some(handler) => handler
      | None =>
        getDefaultLoaderHandlerWithContextGetter(~eventName="Swap", ~functionRegister=Handler)
      }

    let handlerIsAsync = () => getHandler()->SyncAsync.isAsync
  }
}
