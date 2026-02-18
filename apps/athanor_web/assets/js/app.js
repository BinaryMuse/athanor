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
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/athanor_web"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

// Custom hooks
const Hooks = {
  ConfigFormHook: {
    mounted() {
      this.schema = JSON.parse(this.el.dataset.schema)
      this.state = this.initStateFromSchema(this.schema)
      this.render()
      this.bindEvents()
    },

    handleEvent(event, payload) {
      if (event === "config_schema_changed") {
        this.schema = JSON.parse(payload.schema_json)
        this.state = this.initStateFromSchema(this.schema)
        this.render()
      }
    },

    bindEvents() {
      // Track input changes
      this.el.addEventListener("input", (e) => {
        if (e.target.dataset.fieldPath) {
          const path = JSON.parse(e.target.dataset.fieldPath)
          const type = e.target.dataset.fieldType
          this.updateState(path, this.coerceValue(e.target.value, type))
        }
      })

      // Handle checkbox changes
      this.el.addEventListener("change", (e) => {
        if (e.target.type === "checkbox" && e.target.dataset.fieldPath) {
          const path = JSON.parse(e.target.dataset.fieldPath)
          this.updateState(path, e.target.checked)
        }
      })

      // Set hidden input before form submits
      const form = this.el.closest("form")
      if (form) {
        form.addEventListener("submit", () => {
          const hiddenInput = document.getElementById("config-json-input")
          if (hiddenInput) hiddenInput.value = JSON.stringify(this.state)
        })
      }
    },

    coerceValue(rawValue, type) {
      if (type === "integer") return parseInt(rawValue, 10) || 0
      if (type === "number") return parseFloat(rawValue) || 0
      return rawValue
    },

    initStateFromSchema(schema) {
      return schema.properties.reduce((acc, {name, definition}) => {
        if (definition.type === "list") {
          acc[name] = []
        } else if (definition.type === "group") {
          acc[name] = this.initStateFromSchema(definition.sub_schema)
        } else {
          acc[name] = definition.default ?? null
        }
        return acc
      }, {})
    },

    updateState(path, value) {
      let obj = this.state
      for (let i = 0; i < path.length - 1; i++) {
        obj = obj[path[i]]
      }
      obj[path[path.length - 1]] = value
    },

    render() {
      // Keep the hidden input, render fields after it
      const hiddenInput = this.el.querySelector("#config-json-input")
      const fragment = document.createDocumentFragment()
      this.renderProperties(fragment, this.schema.properties, [])

      // Clear and re-add
      this.el.innerHTML = ""
      this.el.appendChild(hiddenInput.cloneNode())
      this.el.appendChild(fragment)
    },

    renderProperties(parent, properties, path) {
      for (const {name, definition} of properties) {
        const fieldPath = [...path, name]
        const value = this.getStateValue(fieldPath)

        if (definition.type === "list") {
          // Plan 03 will handle lists - render placeholder
          parent.appendChild(this.createListPlaceholder(name, definition, fieldPath))
        } else if (definition.type === "group") {
          parent.appendChild(this.renderGroup(name, definition, fieldPath))
        } else {
          parent.appendChild(this.renderScalarField(name, definition, fieldPath, value))
        }
      }
    },

    getStateValue(path) {
      let obj = this.state
      for (const key of path) {
        if (obj === undefined || obj === null) return undefined
        obj = obj[key]
      }
      return obj
    },

    renderGroup(name, definition, path) {
      const card = document.createElement("div")
      card.className = "card bg-base-200 mb-4"

      const body = document.createElement("div")
      body.className = "card-body gap-4"

      const title = document.createElement("h3")
      title.className = "card-title text-base"
      title.textContent = definition.label || this.humanize(name)
      body.appendChild(title)

      if (definition.description) {
        const desc = document.createElement("p")
        desc.className = "text-sm text-base-content/70"
        desc.textContent = definition.description
        body.appendChild(desc)
      }

      this.renderProperties(body, definition.sub_schema.properties, path)
      card.appendChild(body)
      return card
    },

    renderScalarField(name, definition, path, value) {
      const wrapper = document.createElement("div")
      wrapper.className = "fieldset mb-2"

      const label = document.createElement("label")
      const labelSpan = document.createElement("span")
      labelSpan.className = "label mb-1"
      labelSpan.textContent = definition.label || this.humanize(name)

      if (definition.required) {
        const asterisk = document.createElement("span")
        asterisk.className = "text-error ml-1"
        asterisk.textContent = "*"
        labelSpan.appendChild(asterisk)
      }
      label.appendChild(labelSpan)

      if (definition.description) {
        const desc = document.createElement("p")
        desc.className = "text-xs text-base-content/60 mb-1"
        desc.textContent = definition.description
        label.appendChild(desc)
      }

      const input = this.createInput(name, definition, path, value)
      label.appendChild(input)
      wrapper.appendChild(label)

      return wrapper
    },

    createInput(name, definition, path, value) {
      const pathJson = JSON.stringify(path)

      // Boolean -> checkbox
      if (definition.type === "boolean") {
        const container = document.createElement("div")
        container.className = "flex items-center gap-2"
        const checkbox = document.createElement("input")
        checkbox.type = "checkbox"
        checkbox.className = "checkbox"
        checkbox.checked = value === true
        checkbox.dataset.fieldPath = pathJson
        container.appendChild(checkbox)
        return container
      }

      // Enum -> select
      if (definition.type === "enum" && definition.options) {
        const select = document.createElement("select")
        select.className = "select w-full"
        select.dataset.fieldPath = pathJson
        select.dataset.fieldType = "string"

        for (const opt of definition.options) {
          const option = document.createElement("option")
          option.value = opt
          option.textContent = this.humanize(opt)
          if (value === opt) option.selected = true
          select.appendChild(option)
        }
        return select
      }

      // Textarea format
      if (definition.format === "textarea") {
        const textarea = document.createElement("textarea")
        textarea.className = "textarea w-full"
        textarea.value = value ?? ""
        textarea.dataset.fieldPath = pathJson
        textarea.dataset.fieldType = "string"
        return textarea
      }

      // Integer/number
      if (definition.type === "integer" || definition.type === "number") {
        const input = document.createElement("input")
        input.type = "number"
        input.className = "input w-full"
        input.value = value ?? ""
        input.dataset.fieldPath = pathJson
        input.dataset.fieldType = definition.type
        if (definition.min !== undefined) input.min = definition.min
        if (definition.max !== undefined) input.max = definition.max
        if (definition.step !== undefined) input.step = definition.step
        return input
      }

      // String with format hints
      const input = document.createElement("input")
      input.className = "input w-full"
      input.value = value ?? ""
      input.dataset.fieldPath = pathJson
      input.dataset.fieldType = "string"

      switch (definition.format) {
        case "email":
          input.type = "email"
          break
        case "url":
          input.type = "url"
          break
        default:
          input.type = "text"
      }

      return input
    },

    createListPlaceholder(name, definition, path) {
      const div = document.createElement("div")
      div.className = "border border-base-300 rounded-lg p-4 mb-4"
      div.dataset.listPath = JSON.stringify(path)

      const header = document.createElement("div")
      header.className = "flex items-center justify-between mb-2"

      const label = document.createElement("span")
      label.className = "font-semibold"
      label.textContent = definition.label || this.humanize(name)
      header.appendChild(label)

      div.appendChild(header)

      const placeholder = document.createElement("p")
      placeholder.className = "text-sm text-base-content/60"
      placeholder.textContent = "List fields will be enabled in the next update."
      div.appendChild(placeholder)

      return div
    },

    humanize(str) {
      return str
        .replace(/_/g, " ")
        .replace(/\b\w/g, c => c.toUpperCase())
    }
  },
  ReconnectionTracker: {
    mounted() {
      this.attempts = 0
      this.attemptInterval = null
    },
    disconnected() {
      this.attempts = 0
      // Count attempts every 2s as rough approximation
      // Phoenix socket uses exponential backoff internally
      this.attemptInterval = setInterval(() => {
        this.attempts += 1
        this.pushEvent("reconnecting", { attempt: this.attempts })
      }, 2000)
    },
    reconnected() {
      clearInterval(this.attemptInterval)
      this.attemptInterval = null
      this.pushEvent("reconnected", {})
    },
    destroyed() {
      clearInterval(this.attemptInterval)
    }
  },
  AutoScroll: {
    mounted() {
      this.scrollToBottom()

      // Track if we've pushed a scroll-away event to avoid spamming
      this.scrolledAway = false

      // Listen for user scroll to detect scroll-away intent
      this.el.addEventListener("scroll", () => {
        const nearBottom = this.isNearBottom()

        // If user scrolled away from bottom and auto-scroll is enabled, notify server
        if (!nearBottom && this.el.dataset.autoScroll === "true" && !this.scrolledAway) {
          this.scrolledAway = true
          this.pushEvent("disable_auto_scroll", {})
        }

        // Reset flag when user returns to bottom
        if (nearBottom) {
          this.scrolledAway = false
        }
      })

      this.observer = new MutationObserver(() => {
        if (this.el.dataset.autoScroll === "true" && this.isNearBottom()) {
          this.scrollToBottom()
        }
      })
      this.observer.observe(this.el, { childList: true, subtree: true })
    },
    updated() {
      // Called when data-auto-scroll attribute changes via server push.
      // If user just enabled auto-scroll, jump to bottom immediately and reset flag.
      if (this.el.dataset.autoScroll === "true") {
        this.scrollToBottom()
        this.scrolledAway = false
      }
    },
    destroyed() {
      if (this.observer) {
        this.observer.disconnect()
      }
    },
    isNearBottom() {
      const threshold = 100 // pixels from bottom
      return this.el.scrollHeight - this.el.scrollTop - this.el.clientHeight <= threshold
    },
    scrollToBottom() {
      this.el.scrollTop = this.el.scrollHeight
    }
  }
}

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, ...Hooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

