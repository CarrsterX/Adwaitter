# Navigation

Adaptive split views, navigation stacks, tab views, carousels, sidebars, and
view switchers matching GNOME Libadwaita 1.10+.

## Key Widgets

* `AdwNavigationSplitView` & `AdwOverlaySplitView` — Adaptive two-pane
  sidebar/content layouts that collapse smoothly on narrow viewports.
* `AdwNavigationView` — Push/pop navigation stack with 1:1 swipe-back and
  Android predictive back spring physics.
* `AdwTabView`, `AdwTabBar`, & `AdwTabOverview` — Dynamic tabbed browsing with
  drag-to-reorder, pinning, and overview grid.
* `AdwViewSwitcher` & `AdwViewSwitcherBar` — Top/bottom view switchers for
  sibling pages.
* `AdwCarousel`, `AdwCarouselIndicatorDots`, & `AdwCarouselIndicatorLines` —
  Spring-physics horizontal/vertical page carousels.
* `AdwSidebar` & `AdwSidebarItem` — GNOME navigation sidebar lists.

## Known Limitations (Mobile Web)

On mobile web browsers (Chromium/Brave/Chrome on Android 14+ and Safari on iOS),
physical screen-edge swipes are controlled by the browser/OS for Back/Forward
history transitions and cannot be disabled or intercepted by web applications.
To avoid gesture collisions, `AdwNavigationView` reserves a `72px` edge safe
zone on Web and disables system predictive-back listeners on Web; in-app
swipe-back remains available from the center of the view alongside the
`AdwHeaderBar` back button. Native Android builds support full Android 14+
Predictive Back without restriction.

