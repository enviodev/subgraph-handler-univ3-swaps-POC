"use strict";
// subgraph assembly script handlers
Object.defineProperty(exports, "__esModule", { value: true });
exports.handleSwap = void 0;
var schema_1 = require("../generated/schema");
function handleSwap(event) {
    var swap = new schema_1.Swap(event.transaction.hash.toHexString());
    swap.recipient = event.params.recipient;
    swap.sender = event.params.sender;
    swap.amount0 = event.params.amount0;
    swap.amount1 = event.params.amount1;
    swap.sqrtPriceX96 = event.params.sqrtPriceX96;
    swap.liquidity = event.params.liquidity;
    swap.tick = event.params.tick;
    swap.save();
}
exports.handleSwap = handleSwap;
