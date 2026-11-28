export const CredentialVisibility = {
  mounted() {
    this.revealed = false
    this.handleClick = event => {
      if (!event.target.closest("[data-toggle-credential]")) return
      this.revealed = !this.revealed
      this.renderVisibility()
    }
    this.el.addEventListener("click", this.handleClick)
  },
  updated() {
    this.renderVisibility()
  },
  destroyed() {
    this.el.removeEventListener("click", this.handleClick)
  },
  renderVisibility() {
    this.el.querySelector("input").type = this.revealed ? "text" : "password"
    const button = this.el.querySelector("[data-toggle-credential]")
    button.setAttribute("aria-pressed", String(this.revealed))
    button.setAttribute("aria-label", this.revealed ? "Hide API key" : "Show API key")
    this.el.querySelector("[data-show-icon]").hidden = this.revealed
    this.el.querySelector("[data-hide-icon]").hidden = !this.revealed
  },
}
