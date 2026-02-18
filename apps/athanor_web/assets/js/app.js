// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { hooks as colocatedHooks } from "phoenix-colocated/athanor_web";
import topbar from "../vendor/topbar";

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

// Custom hooks
const Hooks = {
  ConfigFormHook: {
    mounted() {
      this.schema = JSON.parse(this.el.dataset.schema);
      this.state = this.initStateFromSchema(this.schema);
      this.touched = new Set();
      this.errors = new Map();

      // Merge existing values (edit mode) — data-initial-values set by ConfigFormComponent
      if (this.el.dataset.initialValues) {
        try {
          const initialValues = JSON.parse(this.el.dataset.initialValues);
          this.state = this.deepMerge(this.state, initialValues);
        } catch (e) {
          // Ignore invalid JSON — fall back to schema defaults
        }
      }

      this.render();
      this.bindEvents();
    },

    handleEvent(event, payload) {
      if (event === "config_schema_changed") {
        this.schema = JSON.parse(payload.schema_json);
        this.state = this.initStateFromSchema(this.schema);
        this.touched = new Set();
        this.errors = new Map();
        this.render();
      }
    },

    bindEvents() {
      // Track input changes
      this.el.addEventListener("input", (e) => {
        if (e.target.dataset.fieldPath) {
          const path = JSON.parse(e.target.dataset.fieldPath);
          const type = e.target.dataset.fieldType;
          this.updateState(path, this.coerceValue(e.target.value, type));
        }
      });

      // Handle checkbox changes
      this.el.addEventListener("change", (e) => {
        if (e.target.type === "checkbox" && e.target.dataset.fieldPath) {
          const path = JSON.parse(e.target.dataset.fieldPath);
          this.updateState(path, e.target.checked);
        }
      });

      // Track blur for validation
      this.el.addEventListener(
        "blur",
        (e) => {
          if (e.target.dataset.fieldPath) {
            const path = e.target.dataset.fieldPath;
            this.touched.add(path);
            this.validateField(path);
            this.renderFieldError(path);
          }
        },
        true,
      ); // capture phase for blur

      // List item click handlers
      this.el.addEventListener("click", (e) => {
        const addBtn = e.target.closest("[data-add-list-item]");
        if (addBtn) {
          e.preventDefault();
          const path = JSON.parse(addBtn.dataset.addListItem);
          this.addListItem(path);
        }

        const removeBtn = e.target.closest("[data-remove-list-item]");
        if (removeBtn) {
          e.preventDefault();
          const { path, index } = JSON.parse(removeBtn.dataset.removeListItem);
          this.removeListItem(path, index);
        }

        const moveBtn = e.target.closest("[data-move-item]");
        if (moveBtn) {
          e.preventDefault();
          const { path, index, direction } = JSON.parse(
            moveBtn.dataset.moveItem,
          );
          this.moveListItem(path, index, direction);
        }

        const toggleBtn = e.target.closest("[data-toggle-item]");
        if (toggleBtn) {
          e.preventDefault();
          this.toggleItemCollapse(toggleBtn);
        }
      });

      // Set hidden input before form submits
      const form = this.el.closest("form");
      if (form) {
        form.addEventListener("submit", (e) => {
          // Mark all fields as touched
          this.touchAllFields();

          // Validate all
          this.validateAll();

          // If errors, prevent submit and show all errors
          if (this.errors.size > 0) {
            e.preventDefault();
            this.renderAllErrors();
            // Scroll to first error
            const firstError = this.el.querySelector(
              ".input-error, .select-error, .textarea-error",
            );
            if (firstError)
              firstError.scrollIntoView({
                behavior: "smooth",
                block: "center",
              });
            return;
          }

          const hiddenInput = document.getElementById("config-json-input");
          if (hiddenInput) hiddenInput.value = JSON.stringify(this.state);
        });
      }
    },

    coerceValue(rawValue, type) {
      if (type === "integer") return parseInt(rawValue, 10) || 0;
      if (type === "number") return parseFloat(rawValue) || 0;
      return rawValue;
    },

    initStateFromSchema(schema) {
      return schema.properties.reduce((acc, { name, definition }) => {
        if (definition.type === "list") {
          acc[name] = [];
        } else if (definition.type === "group") {
          acc[name] = this.initStateFromSchema(definition.sub_schema);
        } else {
          acc[name] = definition.default ?? null;
        }
        return acc;
      }, {});
    },

    updateState(path, value) {
      let obj = this.state;
      for (let i = 0; i < path.length - 1; i++) {
        obj = obj[path[i]];
      }
      obj[path[path.length - 1]] = value;
    },

    render() {
      // Keep the hidden input, render fields after it
      const hiddenInput = this.el.querySelector("#config-json-input");
      const fragment = document.createDocumentFragment();
      this.renderProperties(fragment, this.schema.properties, []);

      // Clear and re-add
      this.el.innerHTML = "";
      this.el.appendChild(hiddenInput.cloneNode());
      this.el.appendChild(fragment);
    },

    renderProperties(parent, properties, path) {
      for (const { name, definition } of properties) {
        const fieldPath = [...path, name];
        const value = this.getStateValue(fieldPath);

        if (definition.type === "list") {
          parent.appendChild(this.renderListField(name, definition, fieldPath));
        } else if (definition.type === "group") {
          parent.appendChild(this.renderGroup(name, definition, fieldPath));
        } else {
          parent.appendChild(
            this.renderScalarField(name, definition, fieldPath, value),
          );
        }
      }
    },

    renderListField(name, definition, path) {
      const container = document.createElement("div");
      container.className = "border border-base-300 rounded-lg p-4 mb-4";
      container.dataset.listContainer = JSON.stringify(path);

      // Header with label and add button
      const header = document.createElement("div");
      header.className = "flex items-center justify-between mb-4";

      const label = document.createElement("span");
      label.className = "font-semibold";
      label.textContent = definition.label || this.humanize(name);
      header.appendChild(label);

      const addBtn = document.createElement("button");
      addBtn.type = "button";
      addBtn.className = "btn btn-sm btn-outline";
      addBtn.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-4"><path stroke-linecap="round" stroke-linejoin="round" d="M12 4.5v15m7.5-7.5h-15" /></svg> Add`;
      addBtn.dataset.addListItem = JSON.stringify(path);
      header.appendChild(addBtn);

      container.appendChild(header);

      if (definition.description) {
        const desc = document.createElement("p");
        desc.className = "text-sm text-base-content/60 mb-3";
        desc.textContent = definition.description;
        container.appendChild(desc);
      }

      // Items container
      const itemsContainer = document.createElement("div");
      itemsContainer.className = "space-y-3";
      itemsContainer.dataset.itemsContainer = JSON.stringify(path);

      const items = this.getStateValue(path) || [];
      items.forEach((item, index) => {
        itemsContainer.appendChild(
          this.renderListItem(
            definition.item_schema,
            path,
            index,
            items.length,
          ),
        );
      });

      if (items.length === 0) {
        const empty = document.createElement("p");
        empty.className = "text-sm text-base-content/60 text-center py-4";
        empty.textContent = 'No items yet. Click "Add" to add one.';
        itemsContainer.appendChild(empty);
      }

      container.appendChild(itemsContainer);
      return container;
    },

    renderListItem(itemSchema, listPath, index, totalItems) {
      const itemPath = [...listPath, index];

      const card = document.createElement("div");
      card.className = "card bg-base-200";
      card.dataset.itemCard = JSON.stringify(itemPath);

      const body = document.createElement("div");
      body.className = "card-body p-3 gap-2";

      // Header row with toggle, reorder, and remove buttons
      const headerRow = document.createElement("div");
      headerRow.className = "flex items-center gap-2";

      // Toggle button with summary
      const toggleBtn = document.createElement("button");
      toggleBtn.type = "button";
      toggleBtn.className =
        "flex-1 text-left text-sm font-medium flex items-center gap-2";
      toggleBtn.dataset.toggleItem = JSON.stringify(itemPath);

      const chevron = document.createElement("span");
      chevron.className = "text-base-content/40 text-xs transition-transform";
      chevron.dataset.chevron = "true";
      chevron.textContent = "▼";
      toggleBtn.appendChild(chevron);

      const summary = document.createElement("span");
      summary.textContent = `Item ${index + 1}`;
      toggleBtn.appendChild(summary);

      headerRow.appendChild(toggleBtn);

      // Reorder buttons
      const reorderGroup = document.createElement("div");
      reorderGroup.className = "flex gap-1";

      const upBtn = document.createElement("button");
      upBtn.type = "button";
      upBtn.className = "btn btn-ghost btn-xs";
      upBtn.disabled = index === 0;
      upBtn.innerHTML = "↑";
      upBtn.dataset.moveItem = JSON.stringify({
        path: listPath,
        index,
        direction: "up",
      });
      reorderGroup.appendChild(upBtn);

      const downBtn = document.createElement("button");
      downBtn.type = "button";
      downBtn.className = "btn btn-ghost btn-xs";
      downBtn.disabled = index === totalItems - 1;
      downBtn.innerHTML = "↓";
      downBtn.dataset.moveItem = JSON.stringify({
        path: listPath,
        index,
        direction: "down",
      });
      reorderGroup.appendChild(downBtn);

      headerRow.appendChild(reorderGroup);

      // Remove button
      const removeBtn = document.createElement("button");
      removeBtn.type = "button";
      removeBtn.className = "btn btn-ghost btn-xs";
      removeBtn.innerHTML = "✕";
      removeBtn.dataset.removeListItem = JSON.stringify({
        path: listPath,
        index,
      });
      headerRow.appendChild(removeBtn);

      body.appendChild(headerRow);

      // Detail section (collapsible)
      const detail = document.createElement("div");
      detail.className = "space-y-2 pl-6 mt-2";
      detail.dataset.itemDetail = "true";

      // Render item schema fields
      this.renderItemFields(detail, itemSchema.properties, itemPath);

      body.appendChild(detail);
      card.appendChild(body);

      return card;
    },

    renderItemFields(parent, properties, basePath) {
      for (const { name, definition } of properties) {
        const fieldPath = [...basePath, name];
        const value = this.getStateValue(fieldPath);

        if (definition.type === "list") {
          // Nested list - recursive
          parent.appendChild(this.renderListField(name, definition, fieldPath));
        } else if (definition.type === "group") {
          parent.appendChild(this.renderGroup(name, definition, fieldPath));
        } else {
          parent.appendChild(
            this.renderScalarField(name, definition, fieldPath, value),
          );
        }
      }
    },

    addListItem(path) {
      const list = this.getStateValue(path);
      const definition = this.getDefinitionForPath(path);
      const newItem = this.initStateFromSchema(definition.item_schema);
      list.push(newItem);
      this.render();
    },

    removeListItem(path, index) {
      const list = this.getStateValue(path);
      list.splice(index, 1);
      this.render();
    },

    moveListItem(path, index, direction) {
      const list = this.getStateValue(path);
      const newIndex = direction === "up" ? index - 1 : index + 1;
      if (newIndex < 0 || newIndex >= list.length) return;
      const [item] = list.splice(index, 1);
      list.splice(newIndex, 0, item);
      this.render();
    },

    toggleItemCollapse(toggleBtn) {
      const itemCard = toggleBtn.closest("[data-item-card]");
      const detail = itemCard.querySelector("[data-item-detail]");
      const chevron = toggleBtn.querySelector("[data-chevron]");

      detail.classList.toggle("hidden");
      chevron.textContent = detail.classList.contains("hidden") ? "▶" : "▼";
    },

    getDefinitionForPath(path) {
      // Return the definition for the last segment of path
      // Walk through schema following the path
      const parentPath = path.slice(0, -1);
      let parentSchema = this.schema;
      for (const key of parentPath) {
        if (typeof key === "number") continue;
        const prop = parentSchema.properties.find((p) => p.name === key);
        if (!prop) return null;
        if (prop.definition.type === "list") {
          parentSchema = prop.definition.item_schema;
        } else if (prop.definition.type === "group") {
          parentSchema = prop.definition.sub_schema;
        }
      }
      const lastKey = path[path.length - 1];
      if (typeof lastKey === "number") {
        // Path ends in a numeric index, return the parent list's item_schema wrapper
        // We need the list definition itself - walk path one more level up
        const listPath = path.slice(0, -1);
        const listParentPath = listPath.slice(0, -1);
        let listParentSchema = this.schema;
        for (const key of listParentPath) {
          if (typeof key === "number") continue;
          const prop = listParentSchema.properties.find((p) => p.name === key);
          if (!prop) return null;
          if (prop.definition.type === "list") {
            listParentSchema = prop.definition.item_schema;
          } else if (prop.definition.type === "group") {
            listParentSchema = prop.definition.sub_schema;
          }
        }
        const listKey = listPath[listPath.length - 1];
        const listProp = listParentSchema.properties.find(
          (p) => p.name === listKey,
        );
        return listProp?.definition;
      }
      const finalProp = parentSchema.properties.find((p) => p.name === lastKey);
      return finalProp?.definition;
    },

    getStateValue(path) {
      let obj = this.state;
      for (const key of path) {
        if (obj === undefined || obj === null) return undefined;
        obj = obj[key];
      }
      return obj;
    },

    renderGroup(name, definition, path) {
      const card = document.createElement("div");
      card.className = "card bg-base-200 mb-4";

      const body = document.createElement("div");
      body.className = "card-body gap-4";

      const title = document.createElement("h3");
      title.className = "card-title text-base";
      title.textContent = definition.label || this.humanize(name);
      body.appendChild(title);

      if (definition.description) {
        const desc = document.createElement("p");
        desc.className = "text-sm text-base-content/70";
        desc.textContent = definition.description;
        body.appendChild(desc);
      }

      this.renderProperties(body, definition.sub_schema.properties, path);
      card.appendChild(body);
      return card;
    },

    renderScalarField(name, definition, path, value) {
      const wrapper = document.createElement("div");
      wrapper.className = "fieldset mb-2";

      const label = document.createElement("label");
      const labelSpan = document.createElement("span");
      labelSpan.className = "label mb-1";
      labelSpan.textContent = definition.label || this.humanize(name);

      if (definition.required) {
        const asterisk = document.createElement("span");
        asterisk.className = "text-error ml-1";
        asterisk.textContent = "*";
        labelSpan.appendChild(asterisk);
      }
      label.appendChild(labelSpan);

      if (definition.description) {
        const desc = document.createElement("p");
        desc.className = "text-xs text-base-content/60 mb-1";
        desc.textContent = definition.description;
        label.appendChild(desc);
      }

      const input = this.createInput(name, definition, path, value);
      label.appendChild(input);
      wrapper.appendChild(label);

      return wrapper;
    },

    createInput(name, definition, path, value) {
      const pathJson = JSON.stringify(path);

      // Boolean -> checkbox
      if (definition.type === "boolean") {
        const container = document.createElement("div");
        container.className = "flex items-center gap-2";
        const checkbox = document.createElement("input");
        checkbox.type = "checkbox";
        checkbox.className = "checkbox";
        checkbox.checked = value === true;
        checkbox.dataset.fieldPath = pathJson;
        container.appendChild(checkbox);
        return container;
      }

      // Enum -> select
      if (definition.type === "enum" && definition.options) {
        const select = document.createElement("select");
        select.className = "select w-full";
        select.dataset.fieldPath = pathJson;
        select.dataset.fieldType = "string";

        for (const opt of definition.options) {
          const option = document.createElement("option");
          option.value = opt;
          option.textContent = this.humanize(opt);
          if (value === opt) option.selected = true;
          select.appendChild(option);
        }
        return select;
      }

      // Textarea format
      if (definition.format === "textarea") {
        const textarea = document.createElement("textarea");
        textarea.className = "textarea w-full";
        textarea.value = value ?? "";
        textarea.dataset.fieldPath = pathJson;
        textarea.dataset.fieldType = "string";
        return textarea;
      }

      // Integer/number
      if (definition.type === "integer" || definition.type === "number") {
        const input = document.createElement("input");
        input.type = "number";
        input.className = "input w-full";
        input.value = value ?? "";
        input.dataset.fieldPath = pathJson;
        input.dataset.fieldType = definition.type;
        if (definition.min !== undefined) input.min = definition.min;
        if (definition.max !== undefined) input.max = definition.max;
        if (definition.step !== undefined) input.step = definition.step;
        return input;
      }

      // String with format hints
      const input = document.createElement("input");
      input.className = "input w-full";
      input.value = value ?? "";
      input.dataset.fieldPath = pathJson;
      input.dataset.fieldType = "string";

      switch (definition.format) {
        case "email":
          input.type = "email";
          break;
        case "url":
          input.type = "url";
          break;
        default:
          input.type = "text";
      }

      return input;
    },

    validateField(pathJson) {
      const path = JSON.parse(pathJson);
      const value = this.getStateValue(path);
      const definition = this.getFieldDefinition(path);

      if (!definition) return;

      // Required check
      if (
        definition.required &&
        (value === null || value === undefined || value === "")
      ) {
        this.errors.set(pathJson, "This field is required");
        return;
      }

      // Min/max for numbers
      if (
        (definition.type === "integer" || definition.type === "number") &&
        value !== null &&
        value !== ""
      ) {
        const num = Number(value);
        if (definition.min !== undefined && num < definition.min) {
          this.errors.set(pathJson, `Minimum value is ${definition.min}`);
          return;
        }
        if (definition.max !== undefined && num > definition.max) {
          this.errors.set(pathJson, `Maximum value is ${definition.max}`);
          return;
        }
      }

      // Enum options check
      if (definition.type === "enum" && definition.options && value) {
        if (!definition.options.includes(value)) {
          this.errors.set(pathJson, "Please select a valid option");
          return;
        }
      }

      // Clear error if valid
      this.errors.delete(pathJson);
    },

    getFieldDefinition(path) {
      let schema = this.schema;
      for (let i = 0; i < path.length; i++) {
        const key = path[i];
        if (typeof key === "number") {
          // Skip numeric indices, we're already at item_schema level
          continue;
        }
        const prop = schema.properties.find((p) => p.name === key);
        if (!prop) return null;

        if (i === path.length - 1) {
          return prop.definition;
        }

        if (prop.definition.type === "list") {
          schema = prop.definition.item_schema;
        } else if (prop.definition.type === "group") {
          schema = prop.definition.sub_schema;
        }
      }
      return null;
    },

    validateAll() {
      this.errors.clear();
      this.validateSchemaFields(this.schema, []);
    },

    validateSchemaFields(schema, basePath) {
      for (const { name, definition } of schema.properties) {
        const path = [...basePath, name];

        if (definition.type === "list") {
          const items = this.getStateValue(path) || [];
          items.forEach((_, index) => {
            this.validateSchemaFields(definition.item_schema, [...path, index]);
          });
        } else if (definition.type === "group") {
          this.validateSchemaFields(definition.sub_schema, path);
        } else {
          const pathJson = JSON.stringify(path);
          this.validateField(pathJson);
        }
      }
    },

    touchAllFields() {
      this.touchSchemaFields(this.schema, []);
    },

    touchSchemaFields(schema, basePath) {
      for (const { name, definition } of schema.properties) {
        const path = [...basePath, name];

        if (definition.type === "list") {
          const items = this.getStateValue(path) || [];
          items.forEach((_, index) => {
            this.touchSchemaFields(definition.item_schema, [...path, index]);
          });
        } else if (definition.type === "group") {
          this.touchSchemaFields(definition.sub_schema, path);
        } else {
          this.touched.add(JSON.stringify(path));
        }
      }
    },

    renderFieldError(pathJson) {
      const input = this.el.querySelector(`[data-field-path='${pathJson}']`);
      if (!input) return;

      const wrapper = input.closest(".fieldset");
      if (!wrapper) return;

      // Remove existing error
      const existingError = wrapper.querySelector(".field-error");
      if (existingError) existingError.remove();

      // Remove error styling from input
      input.classList.remove(
        "input-error",
        "select-error",
        "textarea-error",
        "checkbox-error",
      );

      // If touched and has error, show it
      if (this.touched.has(pathJson) && this.errors.has(pathJson)) {
        const errorClass =
          input.tagName === "SELECT"
            ? "select-error"
            : input.tagName === "TEXTAREA"
              ? "textarea-error"
              : input.type === "checkbox"
                ? "checkbox-error"
                : "input-error";
        input.classList.add(errorClass);

        const errorEl = document.createElement("p");
        errorEl.className =
          "field-error mt-1 flex gap-2 items-center text-sm text-error";
        errorEl.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="size-5"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v3.75m9-.75a9 9 0 1 1-18 0 9 9 0 0 1 18 0Zm-9 3.75h.008v.008H12v-.008Z" /></svg><span>${this.errors.get(pathJson)}</span>`;
        wrapper.appendChild(errorEl);
      }
    },

    renderAllErrors() {
      for (const [pathJson] of this.errors) {
        this.renderFieldError(pathJson);
      }
    },

    humanize(str) {
      return str.replace(/_/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
    },

    deepMerge(target, source) {
      // Deep merge source into target, returning a new object.
      // Arrays are replaced entirely (not merged), which matches
      // how the config hook manages list state.
      const result = { ...target };
      for (const key of Object.keys(source)) {
        if (
          source[key] !== null &&
          typeof source[key] === "object" &&
          !Array.isArray(source[key]) &&
          typeof target[key] === "object" &&
          target[key] !== null &&
          !Array.isArray(target[key])
        ) {
          result[key] = this.deepMerge(target[key], source[key]);
        } else {
          result[key] = source[key];
        }
      }
      return result;
    },
  },
  ReconnectionTracker: {
    mounted() {
      this.attempts = 0;
      this.attemptInterval = null;
    },
    disconnected() {
      this.attempts = 0;
      // Count attempts every 2s as rough approximation
      // Phoenix socket uses exponential backoff internally
      this.attemptInterval = setInterval(() => {
        this.attempts += 1;
        this.pushEvent("reconnecting", { attempt: this.attempts });
      }, 2000);
    },
    reconnected() {
      clearInterval(this.attemptInterval);
      this.attemptInterval = null;
      this.pushEvent("reconnected", {});
    },
    destroyed() {
      clearInterval(this.attemptInterval);
    },
  },
  AutoScroll: {
    mounted() {
      this.scrollToBottom();

      // Track if we've pushed a scroll-away event to avoid spamming
      this.scrolledAway = false;

      // Listen for user scroll to detect scroll-away intent
      this.el.addEventListener("scroll", () => {
        const nearBottom = this.isNearBottom();

        // If user scrolled away from bottom and auto-scroll is enabled, notify server
        if (
          !nearBottom &&
          this.el.dataset.autoScroll === "true" &&
          !this.scrolledAway
        ) {
          this.scrolledAway = true;
          this.pushEvent("disable_auto_scroll", {});
        }

        // Reset flag when user returns to bottom
        if (nearBottom) {
          this.scrolledAway = false;
        }
      });

      this.observer = new MutationObserver(() => {
        if (this.el.dataset.autoScroll === "true" && this.isNearBottom()) {
          this.scrollToBottom();
        }
      });
      this.observer.observe(this.el, { childList: true, subtree: true });
    },
    updated() {
      // Called when data-auto-scroll attribute changes via server push.
      // If user just enabled auto-scroll, jump to bottom immediately and reset flag.
      if (this.el.dataset.autoScroll === "true") {
        this.scrollToBottom();
        this.scrolledAway = false;
      }
    },
    destroyed() {
      if (this.observer) {
        this.observer.disconnect();
      }
    },
    isNearBottom() {
      const threshold = 100; // pixels from bottom
      return (
        this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight <=
        threshold
      );
    },
    scrollToBottom() {
      this.el.scrollTop = this.el.scrollHeight;
    },
  },
};

const liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: { ...colocatedHooks, ...Hooks },
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (_info) => topbar.show(300));
window.addEventListener("phx:page-loading-stop", (_info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener(
    "phx:live_reload:attached",
    ({ detail: reloader }) => {
      // Enable server log streaming to client.
      // Disable with reloader.disableServerLogs()
      reloader.enableServerLogs();

      // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
      //
      //   * click with "c" key pressed to open at caller location
      //   * click with "d" key pressed to open at function component definition location
      let keyDown;
      window.addEventListener("keydown", (e) => (keyDown = e.key));
      window.addEventListener("keyup", (_e) => (keyDown = null));
      window.addEventListener(
        "click",
        (e) => {
          if (keyDown === "c") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtCaller(e.target);
          } else if (keyDown === "d") {
            e.preventDefault();
            e.stopImmediatePropagation();
            reloader.openEditorAtDef(e.target);
          }
        },
        true,
      );

      window.liveReloader = reloader;
    },
  );
}
