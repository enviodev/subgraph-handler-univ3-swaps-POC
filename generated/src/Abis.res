// TODO: move to `eventFetching`

let swapContractAbi = `
[{"type":"event","name":"Swap","inputs":[{"name":"sender","type":"address","indexed":true},{"name":"recipient","type":"address","indexed":true},{"name":"amount0","type":"int256","indexed":false},{"name":"amount1","type":"int256","indexed":false},{"name":"sqrtPriceX96","type":"uint160","indexed":false},{"name":"liquidity","type":"uint128","indexed":false},{"name":"tick","type":"int24","indexed":false}],"anonymous":false}]
`->Js.Json.parseExn
