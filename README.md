# Run

`pnpm i && pnpm convert && (cd generated && pnpm build) && pnpm envio dev`

Relevant files
- src/mapping.ts - the subgraph assemblyscript handler
- generated/schema.js - the api conversion
- src/EventHandler.js - the event object conversion


> Note: the `pnpm convert` command will give an error that can be ignored, it will still create a valid mapping.js file
