@val external require: string => unit = "require"

let registerContractHandlers = (
  ~contractName,
  ~handlerPathRelativeToGeneratedSrc,
  ~handlerPathRelativeToConfig,
) => {
  try {
    require(handlerPathRelativeToGeneratedSrc)
  } catch {
  | exn =>
    let params = {
      "Contract Name": contractName,
      "Expected Handler Path": handlerPathRelativeToConfig,
      "Code": "EE500",
    }
    let logger = Logging.createChild(~params)

    let errHandler = exn->ErrorHandling.make(~msg="Failed to import handler file", ~logger)
    errHandler->ErrorHandling.log
    errHandler->ErrorHandling.raiseExn
  }
}

let registerAllHandlers = () => {
  registerContractHandlers(
    ~contractName="SwapContract",
    ~handlerPathRelativeToGeneratedSrc="../../src/EventHandlers.js",
    ~handlerPathRelativeToConfig="src/EventHandlers.js",
  )
}
