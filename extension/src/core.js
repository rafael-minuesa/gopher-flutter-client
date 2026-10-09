/* Shared, versioned document data. Contains no DOM or browser API access. */
(() => {
  const schemes = new Set(["http:", "https:", "gopher:"]);
  const kinds = new Set(["paragraph", "heading", "quote", "pre", "listItem", "table", "image"]);
  function safeUrl(value, base) {
    if (typeof value !== "string" || value.length > 4096) return null;
    try {
      const url = new URL(value, base);
      return schemes.has(url.protocol) && url.hostname && !url.username && !url.password ? url.href : null;
    } catch { return null; }
  }
  function validate(doc) {
    if (!doc || doc.schemaVersion !== 1 || !doc.source ||
        !safeUrl(doc.source.url) || typeof doc.source.title !== "string" ||
        !Array.isArray(doc.links) || doc.links.length > 2000) throw new Error("This reading copy is not valid.");
    for (const view of [doc.article, doc.page]) {
      if (!view || !Array.isArray(view.blocks) || view.blocks.length > 5000) throw new Error("This reading copy is not valid.");
      for (const block of view.blocks) {
        if (!kinds.has(block.kind)) throw new Error("This reading copy contains an unsupported block.");
      }
    }
    for (const link of doc.links) {
      if (!safeUrl(link.url) || typeof link.label !== "string" || !Number.isSafeInteger(link.id)) {
        throw new Error("This reading copy contains an invalid link.");
      }
    }
    return doc;
  }
  function inlineText(inlines = [], used) {
    return inlines.map(part => {
      if (part.link) used?.add(part.link);
      return part.text + (part.link ? ` [${part.link}]` : "");
    }).join("");
  }
  function plainText(doc, mode = "article") {
    validate(doc);
    const used = new Set();
    const lines = [doc.source.title, "=".repeat(Math.min(doc.source.title.length, 72)), doc.source.url, ""];
    if (Array.isArray(doc.notices) && doc.notices.length) {
      for (const notice of doc.notices) if (typeof notice === "string") lines.push(`Note: ${notice}`);
      lines.push("");
    }
    if (mode !== "links") {
      const view = mode === "page" ? doc.page : doc.article;
      for (const block of view.blocks) {
        if (block.kind === "pre") lines.push(block.text);
        else if (block.kind === "image") lines.push(`[Image: ${block.text}]`);
        else if (block.kind === "table") {
          for (const row of block.rows) lines.push(row.map(cell => inlineText(cell.inlines, used)).join("\t"));
        } else {
          const text = inlineText(block.inlines, used);
          if (block.kind === "heading") lines.push(text, (block.level === 1 ? "=" : "-").repeat(Math.min(text.length, 72)));
          else if (block.kind === "quote") lines.push(text.split("\n").map(line => `> ${line}`).join("\n"));
          else if (block.kind === "listItem") lines.push("  ".repeat(block.depth || 0) + block.prefix + text);
          else lines.push(text);
        }
        lines.push("");
      }
    }
    const links = mode === "links" ? doc.links : doc.links.filter(link => used.has(link.id));
    if (links.length) {
      lines.push("Links", "-----");
      for (const link of links) lines.push(`[${link.id}] ${link.label}\n    ${link.url}`);
    }
    return lines.join("\n");
  }
  function prefs(value = {}) {
    if (!value || typeof value !== "object") value = {};
    return {
      fontSize: Math.min(26, Math.max(14, Number(value.fontSize) || 18)),
      theme: ["system", "light", "dark"].includes(value.theme) ? value.theme : "system",
      wrap: value.wrap !== false,
      mode: ["article", "page", "links"].includes(value.mode) ? value.mode : "article"
    };
  }
  globalThis.GopherDocument = Object.freeze({safeUrl, validate, inlineText, plainText, prefs});
})();
