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
  AutoScroll: {
    mounted() {
      this.scrollToBottom()

      // Track if we've pushed a scroll-away event to avoid spamming
      this.scrolledAway = false

      // Listen for user scroll to detect scroll-away intent
      this.el.addEventListener("scroll", () => {
        const nearBottom = this.isNearBottom()

        // If user scrolled away from bottom and auto-scroll is still enabled, notify server
        if (!nearBottom && this.el.dataset.autoScroll === "true" && !this.scrolledAway) {
          this.scrolledAway = true
          this.pushEvent("scroll_position", { near_bottom: false })
        }

        // Reset scrolledAway flag when user returns to bottom
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

