# FlClash Android navigation and motion

The Flutter components below contain code adapted from
[chen08209/FlClash](https://github.com/chen08209/FlClash), pinned to commit
`7fd417fb9a9a277c6a9339a8ac87f907df7c25f7` (retrieved 2026-10-28).
Copyright belongs to the respective FlClash authors. The copied portions are
licensed under GNU GPL version 3; the complete upstream license is preserved in
[flclash-LICENSE.txt](flclash-LICENSE.txt). These portions are not covered by
OmnibotApp's separate commercial license.

| OmnibotApp component | Upstream source |
| --- | --- |
| `ui/lib/widgets/flclash/navigation_dock.dart` | `lib/ui/navigation_dock.dart`, with surface/shape/type tokens adapted to Flutter Material and OmniPalette |
| `ui/lib/widgets/flclash/tab_view.dart` | `lib/pages/home.dart` (`_HomePageView` slide branch, adjacent-page warp, kept-page activity gating) |
| `ui/lib/widgets/flclash/page_activity.dart` | Activity boundary from `lib/ui/inherited.dart` (`PageActivityScope`), `lib/widgets/active_polling.dart`, and `lib/pages/home.dart`; settle-aware read scheduling is an OmnibotApp adaptation |
| `ui/lib/widgets/flclash/open_container.dart` | `lib/ui/open_container.dart` (`ListItem.open` on Android) |
| `ui/lib/widgets/flclash/drag_back.dart` | `lib/ui/drag_back.dart` |
| `ui/lib/widgets/flclash/deferred_push.dart` | `lib/ui/deferred_push.dart` |
| `ui/lib/widgets/flclash/keyboard_inset_hold.dart` | `lib/ui/keyboard_inset_hold.dart` |
| Settings row transition decoration in `ui/lib/features/home/pages/settings/settings_page.dart` | `lib/ui/list.dart` (`ListItem.open`) and `lib/ui/list_selected.dart` (`DecorationListItem`); group corners and surface adapted to the existing OmniSettingsGroup |
| `ui/lib/widgets/flclash/search_header.dart` and `search_surface.dart` | Proxy page `lib/ui/scaffold.dart`, `lib/ui/search_field.dart`, `lib/ui/button.dart`, `lib/ui/motion.dart`, and the solid surface/press portions of `lib/ui/goo.dart` and `lib/ui/navigation_dock.dart` |
| `ui/lib/widgets/flclash/popup.dart` and `popup_geometry.dart` | `lib/ui/popup.dart` (solid flat popup and source-control morph), `lib/ui/goo.dart`, `lib/ui/motion.dart`, and the solid `menuShadows` constants from `lib/ui/liquid_glass.dart` |

The navigation dock ports the upstream defaults: floating navigation enabled,
liquid glass disabled. Its layout, spring simulations, drag selection, lens
deformation and per-icon selection effects are retained. The optional glass
shader path and desktop-only integration are not included. Application-specific
icons, labels, colors, providers and destinations are supplied by OmnibotApp.

Tab motion uses FlClash's optional slide branch: the PageView moves horizontally
over `kTabScrollDuration` (300 ms) with `easeOut`, retaining the adjacent-page
warp. FlClash's upstream default remains the separate 220 ms fade branch.
OmnibotApp adds reduced-motion support and explicit kept-tab focus/semantics
gating. To avoid moving visible pages when clicks interrupt a warp, it reverses
within the current page pair from the existing offset; a third destination is
queued until landing, and only the latest requested destination continues.
The selected cold destination gets one layout frame before its slide starts,
adapting the upstream `DeferredPushRouteMixin` preparation mechanism to the
PageView's adjacent cache slot. Unrequested slots remain placeholders, and
visited pages retain their state. Static settings rows are present throughout
the slide. The application's UI reads and result publication use the actual
tab activity/landing signal instead of a timer: identical pending reads merge,
and reactivation invalidates an already-issued old snapshot and schedules one
fresh read. This scheduling concerns page UI only; ACP events and lifecycle
ownership remain with the existing runtime and history services.
The settings transition follows the actual `ToolsView -> ListItem.open ->
OpenContainer` mobile path. As upstream, the container is a page-colored
rectangle, with no `closedShape` override; the closed row carries its own
group-position corners and card surface when reparented. It uses the upstream
paint-only geometry, 300 ms `fastOutSlowIn` (flipped on completed-route return),
and page fade windows of 0.2–0.4 on entry and 0.6–0.8 on return. GoRouter owns
the route, and measurements use that destination's navigator even if the source
row is inside a nested navigator.
Only Flutter pointer drags enter the ported `DragBackRouteMixin`: linear
full-page travel, then the upstream 350 ms `fastEaseInToSlowEaseOut` settle.
As in upstream, Android system back has no additional progress observer and
commits through the official Router/Navigator pop, preserving the 300 ms
contraction into the source row. Cancellation leaves the page in place.
OmnibotApp's predictive-back setting gates pointer-gesture entry, and
reduced-motion mode skips programmatic transforms.
Gesture admission also observes Navigator's departing next-route animation when
container routes do not participate in `secondaryAnimation`, so an uncovered
page cannot start dragging beneath an overlay that is still exiting.
Deferred push retains the upstream one-frame preparation before opening.
Keyboard inset holding uses the application's `TickerMode` instead of the
upstream `PageActivityScope`.

Home conversation search and the Agents contacts list share the upstream proxy
toolbar's grouped search button, spring-driven expansion/return, button-slot
collapse, field/cancel separation, and solid joining-surface geometry. They keep
their existing query/filter owners and add reduced-motion and inactive-tab focus
handling. Search uses the upstream 44 dp buttons, 72 dp toolbar and 16 dp edge
insets; it intentionally replaces the previous home-specific search animation.
The home search and menu share one 88 by 44 dp capsule. The menu retains the
upstream 44 dp source-control anchor, pointer-down admission, source snapshot,
450 ms opening spring and 500 ms return morph. Popup geometry, blur and corner
interpolation use the upstream solid path; application menu actions remain
owned by HomeDrawer. Plugin refresh updates the visible menu without delaying
its opening. The flat menu also retains the opening press across rows, including
pressed-row feedback, slide-to-select, release and cancel. Submenus and optional
liquid-glass rendering are not included.
