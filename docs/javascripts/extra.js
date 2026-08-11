/* ==============================================================================
 * Protocol    : Deep State of Mind (DSOM) For My AI
 * Script      : Theme Mode Controller (Light / Dark / Auto)
 * Author      : Harisfazillah Jamel (LinuxMalaysia)
 * License     : GNU General Public License v3.0
 * ==============================================================================
 */

(function () {
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

    function syncButtonsToPalette() {
      // Find the currently checked palette input
      const checkedInput = document.querySelector("input[name='__palette']:checked");
      if (!checkedInput) return;

      const media = checkedInput.getAttribute("data-md-color-media");
      let activeMode = "auto";
      if (media === "(prefers-color-scheme: light)") {
        activeMode = "light";
      } else if (media === "(prefers-color-scheme: dark)") {
        activeMode = "dark";
      }

      buttons.forEach((btn) => {
        const mode = btn.getAttribute("data-mode");
        if (mode === activeMode) {
          btn.classList.add("active");
          btn.setAttribute("aria-pressed", "true");
        } else {
          btn.classList.remove("active");
          btn.setAttribute("aria-pressed", "false");
        }
      });
    }

    // Event listeners for custom buttons
    buttons.forEach((btn) => {
      btn.addEventListener("click", () => {
        const mode = btn.getAttribute("data-mode");
        let media = "(prefers-color-scheme)";
        if (mode === "light") {
          media = "(prefers-color-scheme: light)";
        } else if (mode === "dark") {
          media = "(prefers-color-scheme: dark)";
        }
        const input = document.querySelector(`input[name="__palette"][data-md-color-media="${media}"]`);
        if (input) {
          input.click();
        }
      });
    });

    // Sync initially
    syncButtonsToPalette();

    // Synchronize custom buttons when Material palette changes
    const inputs = document.querySelectorAll("input[name='__palette']");
    inputs.forEach((input) => {
      input.addEventListener("change", syncButtonsToPalette);
    });

    // Observe body for changes to attributes (e.g. scheme) to ensure synchronization
    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.attributeName === "data-md-color-scheme") {
          syncButtonsToPalette();
        }
      });
    });
    observer.observe(document.body, { attributes: true });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initThemeToggle);
  } else {
    initThemeToggle();
  }
})();
