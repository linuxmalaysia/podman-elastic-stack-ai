/* ==============================================================================
 * Tests for extra.js - Theme Mode Controller (Light / Dark / Auto)
 *
 * This script is a self-invoking function that manipulates the browser DOM
 * (no module exports, no bundler, no npm dependencies). It is executed here
 * via Node's built-in vm module against a lightweight, purpose-built DOM
 * stub that implements only the subset of the DOM API the script relies on:
 * document.querySelector/createElement/addEventListener, element
 * classList/getAttribute/setAttribute/innerHTML/addEventListener,
 * window.matchMedia, and localStorage.
 *
 * Run with: node --test docs/javascripts/extra.test.js
 * (Node's built-in test runner and assert module require no dependencies.)
 * ==============================================================================
 */
"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const SCRIPT_PATH = path.join(__dirname, "extra.js");
const SCRIPT_SOURCE = fs.readFileSync(SCRIPT_PATH, "utf8");

/* ---------------------------------------------------------------------- *
 * Minimal DOM stub
 * ---------------------------------------------------------------------- */

class ClassList {
  constructor() {
    this._set = new Set();
  }
  add(cls) {
    this._set.add(cls);
  }
  remove(cls) {
    this._set.delete(cls);
  }
  contains(cls) {
    return this._set.has(cls);
  }
}

class MockElement {
  constructor(tag) {
    this.tagName = tag;
    this._attrs = {};
    this.classList = new ClassList();
    this.children = [];
    this._listeners = {};
    this.nextSibling = null;
    this._innerHTML = "";
    this._buttons = [];
  }

  set className(value) {
    this._attrs["class"] = value;
  }

  get className() {
    return this._attrs["class"];
  }

  setAttribute(name, value) {
    this._attrs[name] = value;
  }

  getAttribute(name) {
    return Object.prototype.hasOwnProperty.call(this._attrs, name)
      ? this._attrs[name]
      : null;
  }

  set innerHTML(html) {
    this._innerHTML = html;
    // Parse out <button ... data-mode="X"> tags in document order, matching
    // the fixed template rendered by extra.js.
    this._buttons = [];
    const re = /<button[^>]*data-mode="(\w+)"[^>]*>/g;
    let match;
    while ((match = re.exec(html)) !== null) {
      const btn = new MockElement("button");
      btn.setAttribute("class", "theme-mode-btn");
      btn.setAttribute("data-mode", match[1]);
      this._buttons.push(btn);
    }
  }

  get innerHTML() {
    return this._innerHTML;
  }

  querySelectorAll(selector) {
    if (selector === ".theme-mode-btn") return this._buttons.slice();
    return [];
  }

  querySelector() {
    return null;
  }

  appendChild(child) {
    this.children.push(child);
  }

  insertBefore(node, referenceNode) {
    const idx = this.children.indexOf(referenceNode);
    if (idx === -1) {
      this.children.push(node);
    } else {
      this.children.splice(idx, 0, node);
    }
  }

  addEventListener(event, callback) {
    (this._listeners[event] = this._listeners[event] || []).push(callback);
  }

  dispatchEvent(event) {
    (this._listeners[event] || []).forEach((cb) => cb());
  }
}

/** Builds a ".md-header__inner" mock element with an optional title child. */
function createHeader({ withTitle = true, withNextSibling = true } = {}) {
  const header = new MockElement("div");
  if (withTitle) {
    const title = new MockElement("div");
    title.setAttribute("class", "md-header__title");
    if (withNextSibling) {
      const sibling = new MockElement("div");
      title.nextSibling = sibling;
      header.children.push(title, sibling);
    } else {
      header.children.push(title);
    }
    header.querySelector = (selector) =>
      selector === ".md-header__title" ? title : null;
  }
  return header;
}

/** Builds a document mock rooted at an optional ".md-header__inner" element. */
function createDocument({ readyState = "complete", header = null } = {}) {
  const docListeners = {};
  const body = new MockElement("body");
  return {
    readyState,
    body,
    createElement: (tag) => new MockElement(tag),
    querySelector(selector) {
      if (selector === ".md-header__inner") return header;
      if (selector === ".theme-mode-toggle-container") {
        if (!header) return null;
        return (
          header.children.find(
            (c) => c._attrs && c._attrs["class"] === "theme-mode-toggle-container"
          ) || null
        );
      }
      return null;
    },
    addEventListener(event, callback) {
      (docListeners[event] = docListeners[event] || []).push(callback);
    },
    _fireDOMContentLoaded() {
      (docListeners["DOMContentLoaded"] || []).forEach((cb) => cb());
    },
  };
}

/** Builds a window mock exposing a single, reusable MediaQueryList. */
function createWindow({ prefersDark = false } = {}) {
  const listeners = {};
  const mql = {
    matches: prefersDark,
    addEventListener(event, callback) {
      (listeners[event] = listeners[event] || []).push(callback);
    },
  };
  return {
    matchMedia: () => mql,
    _fireChange(newMatches) {
      if (typeof newMatches === "boolean") mql.matches = newMatches;
      (listeners["change"] || []).forEach((cb) => cb());
    },
  };
}

function createLocalStorage(initial = {}) {
  const store = Object.assign({}, initial);
  return {
    getItem: (key) =>
      Object.prototype.hasOwnProperty.call(store, key) ? store[key] : null,
    setItem: (key, value) => {
      store[key] = String(value);
    },
    _store: store,
  };
}

/** Runs extra.js in a fresh sandbox built from the given mocks. */
function runExtraJs({ document, window, localStorage }) {
  const sandbox = { document, window, localStorage, console };
  vm.createContext(sandbox);
  vm.runInContext(SCRIPT_SOURCE, sandbox);
  return sandbox;
}

function getToggleContainer(header) {
  return header.children.find(
    (c) => c._attrs && c._attrs["class"] === "theme-mode-toggle-container"
  );
}

/* ---------------------------------------------------------------------- *
 * Tests
 * ---------------------------------------------------------------------- */

test("inserts the toggle container into the header immediately before the title's next sibling", () => {
  const header = createHeader({ withTitle: true, withNextSibling: true });
  const doc = createDocument({ header });
  const win = createWindow();
  const ls = createLocalStorage();

  runExtraJs({ document: doc, window: win, localStorage: ls });

  const container = getToggleContainer(header);
  assert.ok(container, "toggle container should be inserted into the header");
  const idx = header.children.indexOf(container);
  assert.equal(idx, 1, "container should be inserted right after the title element");
});

test("appends the container to the header when the title has no next sibling", () => {
  const header = createHeader({ withTitle: true, withNextSibling: false });
  const doc = createDocument({ header });
  runExtraJs({ document: doc, window: createWindow(), localStorage: createLocalStorage() });

  const container = getToggleContainer(header);
  assert.ok(container);
  assert.equal(header.children[header.children.length - 1], container);
});

test("appends the container to the header when there is no title element at all", () => {
  const header = createHeader({ withTitle: false });
  const doc = createDocument({ header });
  runExtraJs({ document: doc, window: createWindow(), localStorage: createLocalStorage() });

  const container = getToggleContainer(header);
  assert.ok(container);
  assert.equal(header.children[0], container);
});

test("does nothing when .md-header__inner is not found on the page", () => {
  const doc = createDocument({ header: null });
  assert.doesNotThrow(() => {
    runExtraJs({ document: doc, window: createWindow(), localStorage: createLocalStorage() });
  });
  assert.equal(doc.body.getAttribute("data-md-color-scheme"), null);
});

test("does not insert a duplicate toggle container if one already exists in the header", () => {
  const header = createHeader({ withTitle: true, withNextSibling: true });
  const doc = createDocument({ header });
  const sandbox = { document: doc, window: createWindow(), localStorage: createLocalStorage(), console };
  vm.createContext(sandbox);

  vm.runInContext(SCRIPT_SOURCE, sandbox);
  vm.runInContext(SCRIPT_SOURCE, sandbox);

  const containers = header.children.filter(
    (c) => c._attrs && c._attrs["class"] === "theme-mode-toggle-container"
  );
  assert.equal(containers.length, 1, "running the script twice must not duplicate the toggle container");
});

test("defaults to auto mode and applies the dark (slate) scheme when the system prefers dark and nothing is saved", () => {
  const header = createHeader();
  const doc = createDocument({ header });
  const ls = createLocalStorage();
  runExtraJs({ document: doc, window: createWindow({ prefersDark: true }), localStorage: ls });

  assert.equal(doc.body.getAttribute("data-md-color-scheme"), "slate");
  assert.equal(ls.getItem("dsom-theme-mode"), "auto");
  const container = getToggleContainer(header);
  const autoBtn = container._buttons.find((b) => b.getAttribute("data-mode") === "auto");
  assert.ok(autoBtn.classList.contains("active"));
});

test("defaults to auto mode and applies the light (default) scheme when the system prefers light and nothing is saved", () => {
  const header = createHeader();
  const doc = createDocument({ header });
  const ls = createLocalStorage();
  runExtraJs({ document: doc, window: createWindow({ prefersDark: false }), localStorage: ls });

  assert.equal(doc.body.getAttribute("data-md-color-scheme"), "default");
});

test("uses the previously saved mode from localStorage instead of the system preference", () => {
  const header = createHeader();
  const doc = createDocument({ header });
  const ls = createLocalStorage({ "dsom-theme-mode": "dark" });
  // System prefers light, but the explicit saved "dark" mode should win.
  runExtraJs({ document: doc, window: createWindow({ prefersDark: false }), localStorage: ls });

  assert.equal(doc.body.getAttribute("data-md-color-scheme"), "slate");
  const container = getToggleContainer(header);
  const darkBtn = container._buttons.find((b) => b.getAttribute("data-mode") === "dark");
  assert.ok(darkBtn.classList.contains("active"));
});

test("clicking a mode button applies that mode's scheme, persists it, and marks only that button active", () => {
  const header = createHeader();
  const doc = createDocument({ header });
  const ls = createLocalStorage();
  runExtraJs({ document: doc, window: createWindow({ prefersDark: false }), localStorage: ls });

  const container = getToggleContainer(header);
  const lightBtn = container._buttons.find((b) => b.getAttribute("data-mode") === "light");
  const darkBtn = container._buttons.find((b) => b.getAttribute("data-mode") === "dark");

  darkBtn.dispatchEvent("click");

  assert.equal(doc.body.getAttribute("data-md-color-scheme"), "slate");
  assert.equal(ls.getItem("dsom-theme-mode"), "dark");
  assert.ok(darkBtn.classList.contains("active"));
  assert.ok(!lightBtn.classList.contains("active"));
});

test("system color-scheme change updates the theme when the saved mode is auto", () => {
  const header = createHeader();
  const doc = createDocument({ header });
  const ls = createLocalStorage();
  const win = createWindow({ prefersDark: false });
  runExtraJs({ document: doc, window: win, localStorage: ls });

  assert.equal(doc.body.getAttribute("data-md-color-scheme"), "default");

  win._fireChange(true); // system switches to dark while still in "auto" mode

  assert.equal(doc.body.getAttribute("data-md-color-scheme"), "slate");
});

test("system color-scheme change is ignored once the user has explicitly chosen light or dark", () => {
  const header = createHeader();
  const doc = createDocument({ header });
  const ls = createLocalStorage();
  const win = createWindow({ prefersDark: false });
  runExtraJs({ document: doc, window: win, localStorage: ls });

  const container = getToggleContainer(header);
  const darkBtn = container._buttons.find((b) => b.getAttribute("data-mode") === "dark");
  darkBtn.dispatchEvent("click");
  assert.equal(doc.body.getAttribute("data-md-color-scheme"), "slate");

  // System flips back to light, but the explicit "dark" choice must persist.
  win._fireChange(false);
  assert.equal(doc.body.getAttribute("data-md-color-scheme"), "slate");
});

test("defers initialization until DOMContentLoaded when the document is still loading", () => {
  const header = createHeader();
  const doc = createDocument({ readyState: "loading", header });
  runExtraJs({ document: doc, window: createWindow(), localStorage: createLocalStorage() });

  assert.equal(getToggleContainer(header), undefined, "must not initialize before DOMContentLoaded fires");

  doc._fireDOMContentLoaded();

  assert.ok(getToggleContainer(header), "must initialize once DOMContentLoaded fires");
});