# Layout

Adaptive application shell, windowing, header bars, toolbars, breakpoints, and
responsive layout containers following the GNOME Human Interface Guidelines
(HIG).

## Key Widgets

* `AdwApplication` — Root application widget managing theming, localization,
  and navigation without `material.dart`.
* `AdwWindow` & `AdwSubWindow` — Client-Side Decorated (CSD) windows with
  adaptive safe-area handling and multi-window support.
* `AdwHeaderBar`, `AdwWindowTitle`, & `AdwWindowControls` — GNOME header bars
  with centered titles and native window buttons.
* `AdwToolbarView` — Content view with top/bottom bars and scroll-undershoot
  shades.
* `AdwClamp` & `AdwClampScrollable` — Maximum-width responsive content clamps.
* `AdwBreakpointBin`, `AdwMultiLayoutView`, & `AdwWrapBox` — Responsive
  breakpoint switching and flowing layouts.

