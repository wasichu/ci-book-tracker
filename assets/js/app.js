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
import {hooks as colocatedHooks} from "phoenix-colocated/ci_book_tracker"
import topbar from "../vendor/topbar"

const AutoDismissFlash = {
  mounted() {
    this.scheduleDismiss()
  },

  updated() {
    this.el.classList.remove("opacity-0")
    this.scheduleDismiss()
  },

  destroyed() {
    this.clearTimers()
  },

  scheduleDismiss() {
    this.clearTimers()

    this.dismissTimer = window.setTimeout(() => {
      this.el.classList.add("opacity-0")
      this.removeTimer = window.setTimeout(() => this.el.click(), 200)
    }, 3000)
  },

  clearTimers() {
    window.clearTimeout(this.dismissTimer)
    window.clearTimeout(this.removeTimer)
  },
}

const ClipboardCopy = {
  mounted() {
    this.defaultLabel = this.el.querySelector("[data-copy-label]").textContent

    this.handleClick = async () => {
      const text = this.el.dataset.copyText

      try {
        await this.copy(text)
        this.showStatus("Copied")
      } catch (_error) {
        this.showStatus("Copy failed")
      }
    }

    this.el.addEventListener("click", this.handleClick)
  },

  destroyed() {
    this.el.removeEventListener("click", this.handleClick)
    window.clearTimeout(this.statusTimer)
  },

  async copy(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text)
    }

    const input = document.createElement("textarea")
    input.value = text
    input.setAttribute("readonly", "")
    input.style.position = "fixed"
    input.style.opacity = "0"
    document.body.appendChild(input)
    input.select()

    const copied = document.execCommand("copy")
    document.body.removeChild(input)

    if (!copied) throw new Error("Clipboard copy failed")
  },

  showStatus(status) {
    const label = this.el.querySelector("[data-copy-label]")
    label.textContent = status
    window.clearTimeout(this.statusTimer)

    this.statusTimer = window.setTimeout(() => {
      label.textContent = this.defaultLabel
    }, 2000)
  },
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, AutoDismissFlash, ClipboardCopy},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#d97706"}, shadowColor: "rgba(15, 23, 42, .2)"})
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
    window.addEventListener("keyup", e => keyDown = null)
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
