// subgraph assembly script handlers

// The goal is to index this data without editing any of this code

import { Swap as SwapEvent } from "../generated/Swap/Swap";
import { Swap } from "../generated/schema";

export function handleSwap(event: SwapEvent): void {
  let swap = new Swap(event.params.id.toHex());
  swap.owner = event.params.owner;
  swap.displayName = event.params.displayName;
  swap.imageUrl = event.params.imageUrl;
  swap.save();
}
