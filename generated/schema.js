export let gContext = undefined;

export function setContext(context) {
  gContext = context;
}

let Swap = class {
  constructor(id) {
    this.id = id;
    this.context = gContext;
  }
  load(id) {
    // return context.Swap.get(id); // will need to be async to avoid the loader function 🤔 or more likely synchronous loaderless
  }
  save() {
    let swap = { ...this };

    this.context.Swap.set(swap);
  }
};

module.exports = { Swap, setContext };
