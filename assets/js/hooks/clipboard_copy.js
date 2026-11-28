export const ClipboardCopy = {
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
