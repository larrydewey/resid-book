---
title: The intro
description: How resid-book turns a directory of Markdown into a site with no build step.
---

A book is a `content` directory of Markdown plus a `book.toml`. There is no
build step and no Node: the server reads the pages and renders them on
request, so editing a page and reloading is the whole loop.

## What the server adds

Markdown in CommonMark is only half a page. The server adds:

- a sidebar from the book's `nav` array, scoped to the current topic;
- an *On this page* list built from the page's `##` and `###` headings,
  with anchors that match the ones the Markdown renderer emits;
- previous and next links along the book's page order;
- live search, over the whole book, as you type;
- a theme toggle and an off-canvas sidebar on small screens.

## A code block

```resid
// Comments, strings, numbers and keywords are tagged.
Str greet(Str who) { return "hello, " + who; }
Int main() {
    println(greet("world"));
    return 0;
}
```

```text title="Output"
hello, world
```

Inline `code` works too.

## Relative links

A [relative link](./numbers) resolves against the page's own URL, so it
works without knowing where the book is mounted.