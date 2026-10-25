# App Store screenshots and previews

Tools that produce App Store marketing art from real on-device captures, following
Apple's [app preview guidance](https://developer.apple.com/app-store/app-previews/)
and the screenshot/preview specs in App Store Connect Help.

| File | What it does |
| --- | --- |
| `StoreArt.swift` | Frames captures on the CardLah! cream background with a headline and the mascot; renders the header and search results creative assets; renders the preview's intro, outro and caption banners. Edit `shots`, `creativeHeadline` and `previewCaptions` to change copy. |
| `capture_screenshots.sh` | Launches the demo store on each tab of a connected iPhone, captures it, then runs `StoreArt.swift` for screenshots and creative assets. |
| `capture_duo_screenshots.sh` | Does the same on the iPhone Duo simulator, once per pose, then frames the captures at the iPhone Duo sizes. |
| `record_preview.sh` | Records the iPhone's screen while you drive the demo app. |
| `make_preview.sh` | Builds the final app preview from that recording. |

Everything is written straight into this folder:

| Path | Contents |
| --- | --- |
| `original_screenshots/` | Raw device captures (`1-today.png` … `5-today-dark.png`). |
| `original_screenshots/duo/<pose>/` | Raw iPhone Duo simulator captures, one folder per pose. |
| `appstore_screenshots/iPhone <size> (<w>x<h>)/` | Framed screenshots ready for App Store Connect. |
| `appstore_screenshots/iPhone Duo <pose> (<w>x<h>)/` | Framed iPhone Duo screenshots. |
| `creative_assets/` | Product page header and search results images (see below). |
| `app_preview/app-preview.mp4` | The finished app preview. |
| `app_preview/raw-preview.mp4`, `app_preview/cards/` | The raw recording and the intro, outro and caption images it's built from. |

Re-running a script replaces files of the same name. Older assets in these folders (e.g.
`Apple iPhone 11 (1242x2688)`, `home.png`) are left alone.

## Demo data

Debug builds accept `-StoreDemo`, which swaps the real store for an in-memory one
(`CardPulse/Models/StoreDemoData.swift`): popular Singapore cards (Citi Cashback,
UOB Lady's, DBS Woman's World, HSBC Revolution), made-up merchants, a 12-day streak,
one goal hit and two ahead of pace, so the mascot smiles throughout. The real store,
widget and notifications are left alone, and every other launch argument only lasts
for that launch.

## Steps

1. In Xcode, run the **TapTrack** scheme (Debug) on your iPhone once, so the build
   with `-StoreDemo` support is installed. Unlock the phone and turn on Do Not Disturb.
2. Get iPhone UDID by using `xcrun devicectl list devices`
3. Screenshots:
   ```bash
   DEVICE="My iPhone UDID" appstore/capture_screenshots.sh
   ```
   Saves the raw captures to `original_screenshots/` and produces
   `appstore_screenshots/iPhone 6.3in (1206x2622)` and `iPhone 6.1in (1179x2556)`:
   five portrait PNGs each, no alpha. It also renders `creative_assets/`. To re-render
   from existing captures without the phone:
   ```bash
   cd appstore
   swift StoreArt.swift screenshots original_screenshots appstore_screenshots
   swift StoreArt.swift creative original_screenshots creative_assets
   ```
4. iPhone Duo screenshots, on a Mac with Xcode 27.1 and the iPhone Duo simulator. Run the
   **TapTrack** scheme (Debug) on the simulator once, then:
   ```bash
   SIMULATOR="iPhone Duo" appstore/capture_duo_screenshots.sh
   ```
   Before each pose the script pauses: set the pose in Device Hub, then press Return. It
   captures all five tabs, with a 9:41 status bar, in each pose:

   | Pose | Display | Screenshot size |
   | --- | --- | --- |
   | `open-landscape` | Inner | 2853×2007 |
   | `open-portrait` | Inner | 2007×2853 |
   | `closed-landscape` | Outer | 2034×1398 |
   | `closed-portrait` | Outer | 1398×2034 |

   Capture fewer with `POSES="open-landscape open-portrait"`. Wide canvases put the mascot
   and headline in a column beside the device; tall ones use the phone layout. Each capture
   is fitted by its own aspect ratio, so the framing holds even if a pose's capture comes out
   the other way round (the script prints a note when it does). If `simctl` captures the
   wrong display, add `--display=<display>` to the `simctl io` line. To re-frame existing
   captures: `cd appstore && swift StoreArt.swift duo original_screenshots/duo appstore_screenshots`.
   Submitting iPhone Duo screenshots shows the iPhone Duo badge on the product page.
5. App preview:
   ```bash
   DEVICE="My iPhone UDID" appstore/record_preview.sh 28
   appstore/make_preview.sh
   ```
   Follow the path printed by `record_preview.sh` (Today → Cards → Recap → Me,
   about 6s each) so each caption lines up with its screen. Produces
   `app_preview/app-preview.mp4`: 886×1920, 30 fps, H.264 High@4.0, ~11 Mbps, AAC stereo,
   about 26s.

## Header and search results

Creative assets follow Apple's [asset best practices](https://developer.apple.com/app-store/asset-best-practices/)
and the creative asset specifications in App Store Connect Help. They show on iOS 27 and
iPadOS 27 or later, and are optional. Upload them under the version's **Product Page
Information > Header and Search Results**, or to Asset Library.

| File | Placement | Spec |
| --- | --- | --- |
| `header-21x9 (3840x1646).png` | Product page header | 21:9, 3840×1646 |
| `search-results-3x2 (3840x2560).png` | Search results | 3:2, 1920×1280 to 3840×2560 |
| `universal-16x9 (5244x2950).png` | Either; one asset for both | 16:9, 5244×2950 PNG |

- The header carries one idea: the mascot and "Never miss credit card rewards". The phones at
  the sides are decoration and can be cropped.
- Search results states the purpose at a glance and shows the real UI: Today in front,
  with Cards and Recap behind it.
- Key art for the universal asset stays inside the overlap of its centred 21:9 and 3:2
  crops.
- There's no alpha channel, logo, price, URL or award claim.
- Check the crops with App Store Connect's Preview before submitting. Apple's templates
  define the exact safe areas; these layouts keep key art centred, with margin to spare.

## Apple's rules this follows

- Footage is captured on device at native UI resolution; there are no hands, device
  shots, or zoomed-in views.
- Captions are short and stay on screen long enough to read, because previews autoplay muted.
- Transitions are only dissolves. There are no prices, dates or seasonal references.
- The preview runs 15–30s, at most 30 fps, at an accepted resolution, with a stereo
  AAC track. The track is silent unless you pass `MUSIC=` with a soundtrack you're
  licensed to use everywhere.
- App Store Connect uses 5s as the poster frame by default. In this cut that lands
  on the Today screen with its caption, which works well as a poster.
- Upload up to 3 previews and 10 screenshots per device size and language. Smaller
  sizes are scaled from the larger ones automatically.
