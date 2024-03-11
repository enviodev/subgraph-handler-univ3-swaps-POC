import { SwapContractContract } from "../generated/src/Handlers.bs";

import { handleSwap } from "./mapping.js";

import { setContext } from "../generated/schema";

const mapEnvioEventToSubgraphEventAPI = (event) => {
  return {
    ...event,
    transaction: {
      hash: {
        toHexString: () => event.transactionHash,
        toString: () => event.transactionHash,
      },
    },
    block: {
      number: { toString: () => event.blockNumber },
      hash: { toStringHex: () => event.blockHash },
    },
  };
};

SwapContractContract.Swap.loader(({ event, context }) => {});

SwapContractContract.Swap.handler(({ event, context }) => {
  let subgraphEvent = mapEnvioEventToSubgraphEventAPI(event);
  setContext(context);
  handleSwap(subgraphEvent);
});
