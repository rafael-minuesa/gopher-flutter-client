/* Injected into the isolated content-script world only after a user action. */
(() => {
  const MAX_ELEMENTS = 50000;
  const MAX_TEXT = 220000;
  const MAX_BLOCKS = 4500;
  const OMIT = new Set(["SCRIPT", "STYLE", "NOSCRIPT", "TEMPLATE", "FORM", "INPUT", "SELECT", "TEXTAREA", "BUTTON", "SVG", "CANVAS"]);
  const BLOCK = new Set(["P", "DIV", "SECTION", "MAIN", "ARTICLE", "NAV", "HEADER", "FOOTER", "ASIDE", "BLOCKQUOTE", "PRE", "UL", "OL", "LI", "TABLE", "DL", "DT", "DD", "FIGURE", "FIGCAPTION", "H1", "H2", "H3", "H4", "H5", "H6", "HR"]);
  const tagName = node => (node.localName || "").toUpperCase();
  const clean = value => String(value || "").replace(/\s+/g, " ").trim();

  function capture() {
    if (!/^https?:$/.test(location.protocol) || !document.body) throw new Error("Open an ordinary web page to read it as text.");
    const live = Array.from(document.querySelectorAll("*"));
    if (live.length > MAX_ELEMENTS) throw new Error("This page is too large to convert. Try a smaller article or document.");
    const clone = document.cloneNode(true);
    const copies = Array.from(clone.querySelectorAll("*"));
    for (let i = 0; i < live.length; i++) {
      const original = live[i], copy = copies[i];
      if (OMIT.has(tagName(original)) || original.hidden || original.hasAttribute("inert") ||
          original.getAttribute("aria-hidden") === "true" || original.isContentEditable) {
        Element.prototype.remove.call(copy);
        continue;
      }
      if (original.closest("head")) continue;
      const style = getComputedStyle(original);
      if (style.display === "none" || style.visibility === "hidden" || style.visibility === "collapse" ||
          style.contentVisibility === "hidden" || style.opacity === "0") Element.prototype.remove.call(copy);
    }
    const base = document.baseURI;
    const baseElement = clone.createElement("base");
    baseElement.href = base;
    clone.head.append(baseElement);
    const links = [], linkIds = new Map();
    let shortened = false;
    function register(value, label) {
      const url = GopherDocument.safeUrl(value, base);
      if (!url) return null;
      if (linkIds.has(url)) return linkIds.get(url);
      if (links.length >= 2000) { shortened = true; return null; }
      const id = links.length + 1;
      linkIds.set(url, id);
      links.push({id, url, label: clean(label).slice(0, 300) || url});
      return id;
    }
    function inlines(node) {
      const result = [];
      function visit(child) {
        if (child.nodeType === Node.TEXT_NODE) {
          result.push({text: child.nodeValue.replace(/\s+/g, " ")});
        } else if (child.nodeType === Node.ELEMENT_NODE) {
          if (OMIT.has(tagName(child))) return;
          if (tagName(child) === "BR") result.push({text: "\n"});
          else if (tagName(child) === "IMG") {
            if (clean(child.alt)) result.push({text: `[Image: ${clean(child.alt)}]`});
          } else if (tagName(child) === "A" && child.hasAttribute("href")) {
            const label = clean(child.textContent) || clean(child.querySelector("img")?.alt) || clean(child.title) || child.getAttribute("href");
            result.push({text: label, link: register(child.getAttribute("href"), label)});
          } else {
            const separate = BLOCK.has(tagName(child));
            if (separate && result.length && !result[result.length - 1].text.endsWith("\n")) result.push({text: "\n"});
            for (const item of child.childNodes) visit(item);
            if (separate && result.length && !result[result.length - 1].text.endsWith("\n")) result.push({text: "\n"});
          }
        }
      }
      for (const child of node.childNodes) visit(child);
      if (result.length) {
        result[0].text = result[0].text.trimStart();
        result[result.length - 1].text = result[result.length - 1].text.trimEnd();
      }
      return result.filter(part => part.text);
    }
    function blocks(root) {
      const result = [];
      let characters = 0;
      let anchors = [];
      function append(block) {
        if (result.length >= MAX_BLOCKS) { shortened = true; return; }
        let textLength = JSON.stringify(block).length;
        if (characters + textLength > MAX_TEXT) {
          shortened = true;
          let remaining = MAX_TEXT - characters - 1200;
          if (remaining < 100) return;
          if (typeof block.text === "string") block.text = block.text.slice(0, remaining) + "…";
          else if (block.inlines) {
            const parts = [];
            for (const part of block.inlines) {
              if (remaining <= 0) break;
              const text = part.text.slice(0, remaining);
              parts.push({...part, text}); remaining -= text.length + 80;
            }
            if (!parts.length) return;
            parts[parts.length - 1].text += "…";
            block.inlines = parts;
          } else if (block.rows) {
            while (block.rows.length && JSON.stringify(block).length > MAX_TEXT - characters) block.rows.pop();
            if (!block.rows.length) return;
          } else return;
          textLength = JSON.stringify(block).length;
          if (characters + textLength > MAX_TEXT) return;
        }
        characters += textLength;
        block.sourceIds = anchors.slice(0, 32);
        anchors = [];
        result.push(block);
      }
      function visit(node, depth = 0) {
        if (result.length >= MAX_BLOCKS || characters >= MAX_TEXT) { shortened = true; return; }
        if (node.nodeType !== Node.ELEMENT_NODE || OMIT.has(tagName(node))) return;
        if (node.id) anchors.push(node.id.slice(0, 300));
        if (tagName(node) === "A" && node.getAttribute("name")) anchors.push(node.getAttribute("name").slice(0, 300));
        const tag = tagName(node);
        if (/^H[1-6]$/.test(tag)) append({kind: "heading", level: Number(tag[1]), inlines: inlines(node)});
        else if (tag === "PRE") append({kind: "pre", text: node.textContent.replace(/\r\n?/g, "\n").slice(0, MAX_TEXT)});
        else if (tag === "IMG") {
          if (clean(node.alt)) append({kind: "image", text: clean(node.alt).slice(0, 1000)});
        } else if (tag === "TABLE") {
          const rows = Array.from(node.rows).slice(0, 200).map(row => Array.from(row.cells).slice(0, 20).map(cell => ({header: tagName(cell) === "TH", inlines: inlines(cell)})));
          if (node.rows.length > 200) shortened = true;
          if (node.caption) append({kind: "paragraph", inlines: inlines(node.caption)});
          if (rows.length) append({kind: "table", rows});
        } else if (tag === "UL" || tag === "OL") {
          let index = tagName(node) === "OL" ? node.start : 1;
          for (const child of node.children) {
            if (tagName(child) !== "LI") continue;
            const own = child.cloneNode(true);
            for (const nested of own.querySelectorAll("ul, ol")) nested.remove();
            if (child.id) anchors.push(child.id.slice(0, 300));
            const value = Number(child.getAttribute("value"));
            if (child.hasAttribute("value") && Number.isFinite(value)) index = value;
            append({kind: "listItem", depth: Math.min(depth, 8), prefix: tag === "OL" ? `${index++}. ` : "- ", inlines: inlines(own)});
            for (const nested of child.children) {
              if (tagName(nested) === "UL" || tagName(nested) === "OL") visit(nested, depth + 1);
            }
          }
        } else if (tag === "P" || tag === "BLOCKQUOTE" || tag === "FIGCAPTION" || tag === "DT" || tag === "DD") {
          const parts = inlines(node);
          if (parts.length) append({kind: tag === "BLOCKQUOTE" ? "quote" : "paragraph", inlines: parts});
        } else if (["IFRAME", "VIDEO", "AUDIO"].includes(tag)) {
          append({kind: "paragraph", inlines: [{text: "[Embedded content: open the original page to use it.]"}]});
        } else {
          let group = [];
          function flush() {
            if (!group.length) return;
            const container = clone.createElement("div");
            for (const child of group) container.append(child.cloneNode(true));
            const parts = inlines(container);
            if (parts.length) append({kind: "paragraph", inlines: parts});
            group = [];
          }
          for (const child of node.childNodes) {
            if (child.nodeType === Node.ELEMENT_NODE && (BLOCK.has(tagName(child)) || ["IMG", "IFRAME", "VIDEO", "AUDIO"].includes(tagName(child)))) {
              flush(); visit(child, depth);
            } else group.push(child);
          }
          flush();
        }
      }
      if (root) visit(root);
      return result.filter(block => !block.inlines || block.inlines.length);
    }
    let article;
    try {
      article = new Readability(clone.cloneNode(true), {
        serializer: element => element,
        disableJSONLD: true,
        charThreshold: 250,
        maxElemsToParse: MAX_ELEMENTS
      }).parse();
    } catch { article = null; }
    if (article && article.length < 250) article = null;
    const fallback = clone.querySelector("main, [role='main'], article") || clone.body;
    const articleBlocks = blocks(article?.content || fallback);
    const pageBlocks = blocks(clone.body);
    if (!pageBlocks.length) throw new Error("This page has no readable text. Forms and browser-controlled pages cannot be converted.");
    const title = clean(article?.title || document.title || clone.querySelector("h1")?.textContent) || location.hostname;
    const dir = article?.dir || document.documentElement.dir;
    const doc = {
      schemaVersion: 1,
      source: {url: location.href, title: title.slice(0, 1000), capturedAt: new Date().toISOString(),
        byline: clean(article?.byline).slice(0, 300), lang: (article?.lang || document.documentElement.lang || "").slice(0, 40), dir: dir === "rtl" ? "rtl" : "ltr"},
      article: {blocks: articleBlocks.length ? articleBlocks : pageBlocks, fallback: !article},
      page: {blocks: pageBlocks}, links,
      notices: shortened ? ["Some content was shortened because this page is large."] : []
    };
    GopherDocument.validate(doc);
    if (new TextEncoder().encode(JSON.stringify(doc)).length > 1800000) throw new Error("This reading copy is too large. Try a smaller page.");
    return doc;
  }
  globalThis.GopherReader = Object.freeze({capture});
})();
