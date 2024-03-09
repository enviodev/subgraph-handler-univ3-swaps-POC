import {
  SwapContractContract_Swap_loader,
  SwapContractContract_Swap_handler,
} from "../generated/src/Handlers.gen";
import { swapEntity } from "./src/Types.gen";

SwapContractContract_Swap_loader(({ event, context }) => {});

SwapContractContract_Swap_handler(({ event, context }) => {
  const swap: swapEntity = {
    id: event.transactionHash + event.logIndex,
    recipient: event.params.recipient,
    sender: event.params.sender,
    amount0: event.params.amount0,
    amount1: event.params.amount1,
    sqrtPriceX96: event.params.sqrtPriceX96,
    liquidity: event.params.liquidity,
    tick: event.params.tick,
    blockNumber: event.blockNumber,
    blockTimestamp: event.blockTimestamp,
    transactionHash: event.transactionHash,
    liquidityPool: event.srcAddress.toString(),
  };

  context.Swap.set(swap);
});
