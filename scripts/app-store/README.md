# App Store screenshots and previews

Tools that produce App Store marketing art from real on-device captures, following
Apple's [app preview guidance](https://developer.apple.com/app-store/app-previews/)
and the screenshot/preview specs in App Store Connect Help.

| File | What it does |
| --- | --- |
| `StoreArt.swift` | Frames captures on the CardLah! cream background with a headline and the mascot; renders the preview's intro, outro and caption banners. Edit `shots` and `previewCaptions` to change copy. |
| `capture_screenshots.sh` | Launches the demo store on each tab of a connected iPhone, captures it, then runs `StoreArt.swift`. |
| `record_preview.sh` | Records the iPhone's screen while you drive the demo app. |
| `make_preview.sh` | Builds the final app preview from that recording. |

Output goes to `scripts/app-store/output/` (gitignored).

## Demo data

Debug builds accept `-StoreDemo`, which swaps the real store for an in-memory one
(`CardPulse/Models/StoreDemoData.swift`): popular Singapore cards (Citi Cashback,
UOB Lady's, DBS Woman's World, HSBC Revolution), made-up merchants, a 12-day streak,
one goal hit and two ahead of pace, so the mascot smiles throughout. The real store, widget and notifications are
left alone, and every other launch argument only lasts for that launch.

## Steps

1. In Xcode, run the **TapTrack** scheme (Debug) on your iPhone once, so the build
   with `-StoreDemo` support is installed. Unlock the phone and turn on Do Not Disturb.
2. Get iPhone UDID by using `xcrun devicectl list devices`
3. Screenshots:
   ```bash
   DEVICE="My iPhone UDID" scripts/app-store/capture_screenshots.sh
   ```
   Produces `output/screenshots/6.9in` (1320×2868), `6.5in` (1284×2778) and
   `6.1in` (1206×2622): five PNGs each, no alpha.
4. App preview:
   ```bash
   DEVICE="My iPhone UDID" scripts/app-store/record_preview.sh 28
   scripts/app-store/make_preview.sh scripts/app-store/output/raw-preview.mp4
   ```
   Follow the path printed by `record_preview.sh` (Today → Cards → Recap → Me,
   about 6s each) so each caption lines up with its screen. Produces
   `output/app-preview.mp4`: 886×1920, 30 fps, H.264 High@4.0, ~11 Mbps, AAC stereo,
   about 26s.

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
