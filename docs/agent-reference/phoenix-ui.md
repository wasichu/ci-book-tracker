# Phoenix UI conventions

Read this reference when changing LiveViews, HEEx, forms, JavaScript, or CSS.
For framework API details, also consult the relevant sections of
[framework-rules.md](framework-rules.md).

## Layouts and components

- Begin LiveView templates with `<Layouts.app flash={@flash} workspace={@workspace}>`.
  `Layouts` is already aliased by `CiBookTrackerWeb`.
- Keep workspace LiveViews in the `:workspace` live session with the
  `CiBookTrackerWeb.Workspace` mount hook. This application has no authentication
  scopes; do not copy generic `current_scope` instructions into it.
- Only `layouts.ex` may call `<.flash_group>`. Routine success notifications are
  intentionally suppressed; retain useful error feedback.
- Use the imported `<.icon name="hero-..." />` component, not Heroicons modules.
- Use the imported `<.input>` component where available. Supplying a custom input
  class replaces its default classes, so fully style custom inputs.

## Assets

- Preserve Tailwind v4's import/source syntax in `assets/css/app.css`:

  ```css
  @import "tailwindcss" source(none);
  @source "../css";
  @source "../js";
  @source "../../lib/ci_book_tracker_web";
  ```

- Use Tailwind utilities and custom CSS; do not use `@apply` or add daisyUI components.
- Only the `app.js` and `app.css` entry bundles are supported. Import dependencies
  through these bundles, not external script or stylesheet tags in layouts.
- Do not put inline custom `<script>` tags in templates. Use LiveView hooks for
  browser behavior that needs JavaScript.

## Design

- Reuse the existing Slate and Iris Workbench styles and `workspace-*` components.
  Action buttons should match the dashboard's outlined treatment, without pastel
  filled backgrounds or bright white decorative icons.
- Keep the library in a compact workspace with collapsible navigation and inspector;
  use tabs and pagination rather than introducing a long scrolling library page.
- Preserve clear typography, aligned fields, readable contrast, keyboard navigation,
  visible focus, loading feedback, and subtle hover transitions.
