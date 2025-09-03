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

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

let Hooks = {}

Hooks.CursorTracker = {
  mounted() {
    this.lastUpdate = 0
    this.throttleMs = 50 // Throttle updates to 20fps

    this.handleMouseMove = (event) => {
      const now = Date.now()
      if (now - this.lastUpdate < this.throttleMs) return

      const board = event.currentTarget
      const rect = board.getBoundingClientRect()

      const x = event.clientX - rect.left
      const y = event.clientY - rect.top

      if (x >= 0 && x <= rect.width && y >= 0 && y <= rect.height) {
        const svgX = (x / rect.width) * 300
        const svgY = (y / rect.height) * 300

        this.pushEvent("cursor_move", {x: svgX, y: svgY})
        this.lastUpdate = now
      }
    }

    this.el.addEventListener("mousemove", this.handleMouseMove)
  },

  destroyed() {
    if (this.handleMouseMove) {
      this.el.removeEventListener("mousemove", this.handleMouseMove)
    }
  }
}

Hooks.CopyToClipboard = {
  mounted() {
    this.el.addEventListener("click", () => {
      const gameId = this.el.dataset.gameId
      if (gameId && navigator.clipboard) {
        navigator.clipboard.writeText(gameId).then(() => {
          // The button text and color will be updated via LiveView
        }).catch(err => {
          console.error('Failed to copy: ', err)
        })
      }
    })
  }
}

let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
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

