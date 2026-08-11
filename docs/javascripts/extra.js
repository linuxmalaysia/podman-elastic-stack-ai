/* ==============================================================================
 * Protocol    : Deep State of Mind (DSOM) For My AI
 * Script      : Theme Mode Controller (Light / Dark / Auto)
 * Author      : Harisfazillah Jamel (LinuxMalaysia)
 * License     : GNU General Public License v3.0
 * ==============================================================================
 */

(function () {
  /**
   * Initializes the header control for selecting Light, Dark, or Auto theme modes.
   * Persists the selected mode and updates the theme when the system color preference changes.
   */
  function initThemeToggle() {
    const header = document.querySelector(".md-header__inner");
    if (!header || document.querySelector(".theme-mode-toggle-container")) return;

    const container = document.createElement("div");
    container.className = "theme-mode-toggle-container";
    container.innerHTML = `
      <span class="theme-mode-label">MODE :</span>
      <div class="theme-mode-segmented-control">
        <button type="button" class="theme-mode-btn" data-mode="light">☀️ LIGHT</button>
        <button type="button" class="theme-mode-btn" data-mode="dark">🌙 DARK</button>
        <button type="button" class="theme-mode-btn" data-mode="auto">💻 AUTO</button>
      </div>
    `;

    // Insert into header right before the search/repo section
    const searchOrTitle = header.querySelector(".md-header__title");
    if (searchOrTitle && searchOrTitle.nextSibling) {
      header.insertBefore(container, searchOrTitle.nextSibling);
    } else {
      header.appendChild(container);
    }

    const buttons = container.querySelectorAll(".theme-mode-btn");

    function getSystemScheme() {
      return window.matchMedia("(prefers-color-scheme: dark)").matches ? "slate" : "default";
    }

    function applyMode(mode) {
      let scheme = "default";
      if (mode === "dark") {
        scheme = "slate";
      } else if (mode === "light") {
        scheme = "default";
      } else {
        // Auto
        scheme = getSystemScheme();
      }

      document.body.setAttribute("data-md-color-scheme", scheme);

      // Sync with Material's palette state
      const palette = __md_get("__palette");
      if (palette && palette.color) {
        palette.color.scheme = scheme;
        __md_set("__palette", palette);
      }

      // Store the mode selection (not the scheme) for custom controller state
      localStorage.setItem("dsom-theme-mode", mode);

      buttons.forEach((btn) => {
        const isActive = btn.getAttribute("data-mode") === mode;
        if (isActive) {
          btn.classList.add("active");
          btn.setAttribute("aria-pressed", "true");
        } else {
          btn.classList.remove("active");
          btn.setAttribute("aria-pressed", "false");
        }
      });
    }

    // Read saved mode or default to auto
    const savedMode = localStorage.getItem("dsom-theme-mode") || "auto";
    applyMode(savedMode);

    // Event listeners
    buttons.forEach((btn) => {
      btn.addEventListener("click", () => {
        const mode = btn.getAttribute("data-mode");
        applyMode(mode);
      });
    });

    // Watch system color preference changes if in AUTO mode
    window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
      const currentSaved = localStorage.getItem("dsom-theme-mode") || "auto";
      if (currentSaved === "auto") {
        applyMode("auto");
      }
    });

    // Sync with Material's palette toggle if it changes
    const paletteInputs = document.querySelectorAll("input[data-md-color-scheme]");
    paletteInputs.forEach((input) => {
      input.addEventListener("change", () => {
        const scheme = document.body.getAttribute("data-md-color-scheme");
        // Update custom controller to reflect Material's change
        let mode = "auto";
        if (scheme === "slate") {
          mode = "dark";
        } else if (scheme === "default") {
          mode = "light";
        }
        // Only update button states if user clicked Material's toggle
        const currentSaved = localStorage.getItem("dsom-theme-mode") || "auto";
        if (currentSaved !== mode) {
          applyMode(mode);
        }
      });
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initThemeToggle);
  } else {
    initThemeToggle();
  }
})();
