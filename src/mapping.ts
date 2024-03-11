// subgraph assembly script handlers

// The goal is to index this data without editing any of this code
// cheat: passing the context, change to only pass the event, get schema api to allow entity setting

import { Swap as SwapEvent } from "../generated/Swap/Swap";
import { Swap } from "../generated/schema";

export function handleSwap(event: SwapEvent): void {
  let swap = new Swap(event.transaction.hash.toHexString());
  swap.recipient = event.params.recipient;
  swap.sender = event.params.sender;
  swap.amount0 = event.params.amount0;
  swap.amount1 = event.params.amount1;
  swap.sqrtPriceX96 = event.params.sqrtPriceX96;
  swap.liquidity = event.params.liquidity;
  swap.tick = event.params.tick;
  swap.save();
}
