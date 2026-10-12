# resid-book

A **book and documentation site server, written in Resid**, on
[resid-datastar](https://github.com/larrydewey/resid-datastar).

A book is a directory of Markdown plus one file of configuration:

```text
book.toml
src/content/docs/index.mdx      the home page
src/content/docs/intro.md       a page
src/assets/mascot.svg           images the layout asks for
```

There is no build step, no Node and no CDN. The server reads the pages and
renders them on request, so editing a page and reloading is the whole loop.

```sh
# in a resid checkout beside this one
resid-manifest depmap resid.toml deps.txt
residc src/site.resid -o resid-book -depmap deps.txt
./resid-book <book.toml> [--port N] [--port-file F] [--cdn]
```

## `book.toml`

```toml
[book]
title = "Resid"
base = "/Resid"                 # the path the site is mounted at
content = "src/content/docs"    # the Markdown root
assets = "src/assets,public"    # comma-separated directories
repository = "https://github.com/larrydewey/Resid"
edit_base = "https://github.com/larrydewey/Resid/edit/master/website/"

nav = [
    "topic|Learn Resid|learn",  # start a topic (the sidebar's scope)
    "group|Start",              # a group inside it
    "page|",                    # a page; "" is the home page
    "page|learn/hello",
    "topic|Reference|reference",
    "page|reference"
]
```

The nav is a flat array of three-part strings so that it is readable by a
human and parseable by thirty lines of code. A page's label in the sidebar
is its own frontmatter `title`; the `topic` line only says which sidebar a
page belongs to and what that topic is called.

## What a page gets

Markdown is only half a page, so the server adds the rest:

- **frontmatter** — `title`, `description`, and for the home page
  `template: splash` with a `hero` (tagline, image, actions);
- **a sidebar** — the current topic's groups and pages, plus a switcher for
  the topics, with the current page marked;
- **an on-this-page list** — from the page's `##` and `###` headings, with
  anchors that match the ones the Markdown renderer emits;
- **previous and next** links along the book's page order, and an *Edit this
  page* link built from `edit_base`;
- **search** — over the whole book as you type, the way mdbook does it:
  each `##`/`###` section is its own hit, linked to its heading; every word
  of the query must match, in any order; hits are ranked (a word in the
  heading or title beats one in the text, and more uses beat fewer); and
  each shows a snippet with the words marked. Served, a Datastar request patches the results into the search
  box; exported, the index ships as `search.js` and the browser searches
  it, so a static host (or a page opened from disk) searches too;
- **a theme toggle** and an **off-canvas sidebar** on small screens;
- **code fences highlighted** — comments, strings, numbers, keywords and
  type-like names, with a block title (` ```text title="Output" `).

### The MDX the docs use

Starlight's `CardGrid`, `Card` and `LinkCard` are understood, the
`import ... from '@astrojs/starlight/components'` line is dropped, and a
card's children are de-indented the way MDX de-indents JSX children (so
indented prose is prose, not a code block). A trusted `<img>` and `<div>`
are passed through. Nothing else is treated as markup: raw HTML is not
enabled, so a page's own text can never become a script.

### Artwork that follows the theme

`{%asset mascot.svg%}` in a page's text is replaced by the file itself.

An SVG loaded with `<img src>` is its own document, so the page's CSS cannot
reach it and artwork cannot be themed at all. Written into the page instead,
it reads the page's custom properties and follows the theme **toggle**, not
only the operating system. The bundled `mascot.svg` does this with
`--mascot-fill` and `--mascot-line`, and falls back to `prefers-color-scheme`
when it stands alone.

## An API reference from the source

A book about Resid code can carry its API reference, generated when the
book is loaded rather than written by hand, so it cannot drift from the
code:

```toml
api = "../lib"                    # the source root, beside book.toml
api_dirs = ",dev,verify"          # sub-directories; "" is the root itself
api_source = "https://github.com/o/r/blob/master/lib/"   # "Source" links
```

Every `.resid` file under those directories becomes a page at
`api/<path>/`, and `api/` is an index of them with each module's summary
and a list, per capability family, of the functions whose `@requires`
names it. The nav gains an **API** topic with a group per directory, and
the pages are searched and exported like any other.

A module page is built from the source alone:

- the module's leading `//` comment is its overview; a decorated first
  line (`// ─── lib/x.resid — what it is ───`) is its title and summary;
- every declaration an importer can see — a `pub` function, and any `type`
  or `behavior` (visible without `pub`) — is listed under Types, Behaviors
  or Functions with its annotations, its declaration as written (the body
  left out) and the `///` lines directly above it;
- private functions are left out.

The standard library is written to this shape: every such declaration has
a `///` comment, which Resid's `tools/check_doc_comments.py` enforces.

## Not yet

Against a full Starlight install, these are still missing:

- **Last updated.** Starlight dates a page from git; there is no git here,
  and the runtime has no way to stat a file's mtime, so a page carries no
  date until a build step writes one in.
- **Scroll spy.** The on-this-page list is right but does not highlight the
  heading you are reading.
- **Code block extras.** Block titles work; line highlighting
  (```` ```resid {3,5} ````) and copy buttons do not.
- **Everything unused by a plain book**: version dropdowns, banners,
  asides (`:::note`), Starlight's MDX components beyond cards.

## Layout

| Path | What |
|---|---|
| `src/site.resid` | the router, the layout, the assets, `main` |
| `src/book.resid` | `book.toml` and the nav model |
| `src/page.resid` | a page's file, frontmatter and headings |
| `src/render.resid` | a body to HTML: fences, MDX components, Markdown |
| `src/highlight.resid` | the syntax highlighter |
| `src/search.resid` | the search index and the live results |
| `src/api.resid` | the API reference, generated from a source tree |
| `src/theme.resid` | the stylesheet |
| `examples/sample/` | a book that exercises all of it |
| `tests/run.sh` | the suite: build, serve, and check the routes |
| `tests/search_parity.js` | the exported search in node, compared with the server's |

## Requirements

[resid-datastar](https://github.com/larrydewey/resid-datastar) (and through
it resid-json and resid-serial), as `resid.toml` dependencies: checkouts
beside this one, or a registry. The Datastar SDK is imported by relative
path, so in a checkout the sources must sit next to each other; the
dependency map (from `resid-manifest depmap`) resolves the rest.

The server grants itself `args`, `filesystem(readonly)` and
`network(readonly)`: it reads the book and listens on loopback. It never
writes and never reaches the network itself; Datastar's client bundle is
embedded in the binary.

## Tests

```sh
tests/run.sh          # RESIDC=/path/to/residc to pick the compiler
```

It builds the server, serves the sample book on a loopback port, and checks
the routes, the 404, the sidebar, the table of contents, the pager, the
highlighting, the code-block titles and the live search over real HTTP.

## Licence

MIT, in `LICENSE`.