const safely = (operation, fallback = null) => {
  try { return operation() } catch (_) { return fallback }
}

export const Workspace = {
  mounted() {
    this.root = this.el.closest("[data-workspace]")
    this.setSidebar(safely(() => localStorage.getItem("ci.sidebar")) ?? (matchMedia("(max-width: 900px)").matches ? "closed" : "open"))
    this.setProgress(safely(() => localStorage.getItem("ci.progress")) ?? "open")
    this.click = event => {
      if (event.target.closest("[data-toggle-sidebar]")) this.setSidebar(this.root.dataset.sidebar === "closed" ? "open" : "closed")
      if (event.target.closest("[data-toggle-progress]")) this.setProgress(this.root.dataset.progress === "closed" ? "open" : "closed")
      if (event.target.closest("[data-open-commands]")) this.openCommands()
      if (event.target.closest("[data-close-commands],[data-command]")) this.dialog()?.close()
    }
    this.keydown = event => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault()
        this.dialog()?.open ? this.dialog().close() : this.openCommands()
        return
      }
      if (event.metaKey || event.ctrlKey || event.altKey || event.isComposing) return
      if (this.dialog()?.open) {
        const command = [...this.dialog().querySelectorAll("[data-command-key]")]
          .find(link => link.dataset.commandKey === event.key.toLowerCase())
        if (command) { event.preventDefault(); command.click() }
        return
      }
      const typing = event.target.closest("input,textarea,select,[contenteditable=true]")
      if (event.key === "Escape" && !typing) {
        this.root.querySelector("#close-book-inspector")?.click()
        if (matchMedia("(max-width: 900px)").matches) this.setSidebar("closed")
      }
      if (typing) return
      if (event.key === "/") {
        const search = this.root.querySelector("#book-search-form input")
        if (search) { event.preventDefault(); search.focus() }
      }
      if (event.key.toLowerCase() === "n") this.root.querySelector("#add-book")?.click()
      if (["ArrowDown", "ArrowUp", "j", "k"].includes(event.key)) {
        const books = [...this.root.querySelectorAll("[data-book-row] button[phx-click=select_book]")]
        if (!books.length) return
        event.preventDefault()
        const index = books.findIndex(button => button.getAttribute("aria-pressed") === "true")
        const next = index + (["ArrowDown", "j"].includes(event.key) ? 1 : -1)
        if (books[next]) books[next].click()
        else this.root.querySelector(next < 0 ? "#previous-book-page:not(:disabled)" : "#next-book-page:not(:disabled)")?.click()
      }
    }
    this.root.addEventListener("click", this.click)
    window.addEventListener("keydown", this.keydown)
  },
  dialog() { return this.root.querySelector("#workspace-commands") },
  openCommands() {
    const dialog = this.dialog()
    if (!dialog || dialog.open) return
    dialog.showModal()
    dialog.querySelector("[data-command]")?.focus()
  },
  setSidebar(value) {
    this.root.dataset.sidebar = value
    this.root.querySelector("[data-toggle-sidebar]")?.setAttribute("aria-expanded", String(value === "open"))
    safely(() => localStorage.setItem("ci.sidebar", value))
  },
  setProgress(value) {
    this.root.dataset.progress = value
    this.root.querySelector("[data-toggle-progress]")?.setAttribute("aria-expanded", String(value === "open"))
    safely(() => localStorage.setItem("ci.progress", value))
  },
  destroyed() {
    this.dialog()?.close()
    this.root.removeEventListener("click", this.click)
    window.removeEventListener("keydown", this.keydown)
  },
}

// Only measures server-rendered content. The LiveView owns the list and pagination.
export const BookViewport = {
  mounted() {
    this.measure = () => {
      cancelAnimationFrame(this.frame)
      this.frame = requestAnimationFrame(() => {
        const heading = this.el.querySelector(".workbench-table-heading")
        const row = this.el.querySelector("[data-book-row]")
        const height = row?.getBoundingClientRect().height || 64
        const rows = Math.max(1, Math.min(30, Math.floor((this.el.clientHeight - (heading?.offsetHeight || 32) - 1) / height)))
        if (rows !== this.rows) {
          this.rows = rows
          this.pushEvent("resize_books", {rows})
        }
      })
    }
    this.observer = new ResizeObserver(this.measure)
    this.observer.observe(this.el)
    this.measure()
  },
  updated() { this.measure() },
  destroyed() { this.observer.disconnect(); cancelAnimationFrame(this.frame) },
}
