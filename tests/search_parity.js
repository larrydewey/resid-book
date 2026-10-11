// The exported book's search, run in node against stubs for the page, so
// its results can be compared with the server's for the same query.
//
//   node tests/search_parity.js <dist> <query>   prints the results' HTML
const fs = require("fs");
const [dist, query] = process.argv.slice(2);
const on = {};
const input = { value: query, parentNode: { contains: () => false }, addEventListener: (k, f) => { on[k] = f; } };
const out = { hidden: true, innerHTML: "" };
global.window = {};
global.localStorage = { getItem: () => null, setItem: () => {} };
global.document = {
    documentElement: { dataset: {} },
    body: { dataset: {} },
    getElementById: (id) => (id === "search-results" ? out : null),
    querySelector: (s) => (s === ".search input" ? input : null),
    addEventListener: () => {},
};
global.setTimeout = (f) => f();
global.clearTimeout = () => {};
eval(fs.readFileSync(dist + "/search.js", "utf8"));
eval(fs.readFileSync(dist + "/book.js", "utf8"));
on.input();
process.stdout.write(out.innerHTML + "\n");
