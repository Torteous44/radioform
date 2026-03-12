
## [2.1.2] - 2026-03-12

### Bug Fixes

- First-frame jump and add hysteresis to precise mode
- Expand quit button clickable area
- Use knob-local coordinate space for precise-drag threshold calculation
- Retry volume listener registration with backoff after sleep/wake to handle slow coreaudiod restarts
- Skip mute listener registration when volume listener fails to prevent leak on wake retry

### Documentation

- Patch README with accurate runtime behavior
- Patch readme accuracy and fix inline comments

### Miscellaneous Tasks

- Standardize script output
- Simplify bug/feature issue templates
- Centralize generation in script, wire make target, and document usage

### Other

- Merge pull request #71 from Torteous44/dev

Dev
- Round dB values
- Implement precise dB dragging
- Use tabular numerals for slider dB text
- Fix duplicate assignment
- Merge pull request #74 from Torteous44/pr-72

Implement precise slider dragging
- Merge pull request #75 from Torteous44/fix-quit-button

Fix quit button clickable area
- Merge pull request #76 from Torteous44/dev

Dev
- Merge pull request #77 from Torteous44/dev

fix: retry volume listener registration with backoff after sleep/wake…

## [2.1.1] - 2026-03-01

### Bug Fixes

- Re-register HAL volume listener after sleep/wake to restore volume key control
- Forward proxy mute control to physical device so keyboard mute key works
- Harden Safari path with spec-safe HAL clocking, adaptive/timestamp-aware ring writes, RT-safe callback behavior, and increased shared-buffer headroom
- Resolve Copilot review findings

### Documentation

- Correct README for lifecycle, IO behavior, and RFSharedAudio layout offsets/sizing
- Correct Swift usage
- Fix README for device/sample-rate behavior, runtime flow, IPC paths, and cleanup semantics

### Other

- Merge pull request #70 from Torteous44/dev

Dev

## [2.1.0] - 2026-02-27

### Bug Fixes

- Prebuffer 20ms silence on connect to prevent Safari cold-start underruns

### Other

- Merge pull request #69 from Torteous44/dev

fix: prebuffer 20ms silence on connect to prevent Safari cold-start u…

## [2.0.9] - 2026-02-19

### Bug Fixes

- Keep HAL clock continuous across IO restarts to eliminate Safari cold-start underrun
- Defensive mach_timebase_info init and monotonic clock re-anchor on sample rate change

### Other

- Merge pull request #66 from Torteous44/dev

fix: keep HAL clock continuous across IO restarts to eliminate Safari…

## [2.0.8] - 2026-02-17

### Bug Fixes

- Resolve Safari audio stuttering with correct HAL clock
- Zero-timestamp safety guards and correct host buffer-duration docs

### Other

- Merge pull request #62 from Torteous44/fix/issue60-2

Fix/issue60 2
- Merge pull request #63 from Torteous44/dev

Dev

## [2.0.7] - 2026-02-14

### Other

- Merge pull request #61 from Torteous44/fix/issue60

fix: reduce virtual device clock period, ring buffer duration, and ov…

## [2.0.6] - 2026-02-14

### Bug Fixes

- Reduce virtual device clock period, ring buffer duration, and overflow handling to resolve Safari audio stuttering

### Documentation

- Update ring buffer references from 40ms to 20ms and consolidate duration constant

## [2.0.5] - 2026-02-13

### Bug Fixes

- Proxy volume curve by removing driver-side proxy attenuation and forwarding proxy volume to physical output as single gain path
- Fix ProxyDeviceManager volume forwarding lifecycle by preserving listeners through cooldown, syncing immediately on proxy attach, and hardening listener registration/removal
- ProxyDeviceManager stale volume forwarding by stopping on unmanaged device switches, validating callback device IDs, and serializing/coalescing proxy-volume forwarding
- Proxy volume forwarding races by queue-serializing updates, setting active physical device on auto-switch, and replacing magic epsilon with a named constant
- Stale proxy forwarding state on switch failures and missing mappings
- Guard DSP pipeline against NaN/Inf propagation and quit app when host crashes

### Documentation

- Rmv docs

### Other

- Remove harmful control-path code + adjust DSP/preset defaults causing fuzz/compression
- Merge pull request #56 from Torteous44/fix/issue55

Fix/issue55
- Merge pull request #59 from Torteous44/dev

Dev

## [2.0.3] - 2026-02-09

### Other

- Produce universal binaries (arm64 + x86_64) for Intel Mac support
- Merge pull request #52 from Torteous44/dev

build: produce universal binaries (arm64 + x86_64) for Intel Mac support

## [2.0.4] - 2026-02-08

### Bug Fixes

- Site touchups

### Documentation

- Change readme banner and update packages docs

### Other

- Merge pull request #50 from Torteous44/dev

docs: change readme banner and update packages docs
- Merge pull request #51 from Torteous44/fix/web

fix: site touchups

## [2.0.2] - 2026-02-08

### Bug Fixes

- Pre-allocate audio buffers on realtime thread and remove V2 naming

### Documentation

- Add driver documentation

### Features

- Reuse render buffer, lock shared memory, and switch preset monitor to timer in host

### Other

- Merge pull request #49 from Torteous44/dev

Dev

### Refactor

- Restyle advanced band controls with icon sections and compact filter chips

## [2.0.1] - 2026-02-07

### Bug Fixes

- Update image on website
- Update copy in readme and website

### Features

- Update readme banner and adjust marketing site

### Other

- Merge branch 'main' of https://github.com/Torteous44/radioform into dev
- Merge pull request #48 from Torteous44/dev

Dev

## [2.0.0] - 2026-02-06

### Bug Fixes

- Allow double clicking frequency/Q value to edit by typing
- Ensure EQ disable bypasses preamp and limiter

### Features

- Add per-band frequency slider, filter type picker to contextual band controls, with dynamic frequency labels and preset persistence for custom band settings

### Other

- Merge pull request #47 from Torteous44/dev

RADIOFORM 2.0

## [2.0.0-internal] - 2026-02-06

### Bug Fixes

- Sync proxy device volume to physical device on startup to prevent volume jump
- Prevent infinite loop in device switching callbacks
- Remove filter types from UI
- Add device discovery/proxy management and expand host audio/DSP pipeline handling
- Move preamp to left side of GUI

### Features

- Advanced settings ui

## [1.1.11] - 2026-02-02

### Bug Fixes

- Image loading
- Fix: removed the JS isMobile layout toggle and
  relying on CSS breakpoints
- Documentation
- Refactor web
- Image file path
- Use shelving filters on edge bands and standardize Q factors to octave-band convention

### Features

- Web font switch to instrument serif
- Painting
- 3dots
- Website SEO/GEO

### Other

- Merge pull request #40 from Torteous44/fixes/website

fix: removed the JS isMobile layout toggle and
- Merge pull request #41 from Torteous44/fixes/miscDocs

fix: documentation
- Merge pull request #42 from Torteous44/fixes/web

Fixes/web
- Merge pull request #43 from Torteous44/feat/seo

feat: website SEO/GEO
- Merge pull request #44 from Torteous44/feat/presets

fix: use shelving filters on edge bands and standardize Q factors to …

### Performance

- Images fix

## [1.1.10] - 2026-01-31

### Other

- Merge pull request #39 from Torteous44/fix/misc

Fix/misc

## [1.1.9] - 2026-01-31

### Bug Fixes

- Readme
- About page design
- Fix: zipper noise on band parameter changes via coefficient interpolation and make peak meter decay
  sample-rate independent
- Improve dsp portability, remove dead code, and fix README accuracy

## [1.1.8] - 2026-01-30

### Bug Fixes

- Re-lock physical device volume to 100% on drift and device switch

### Features

- Landing page mobile
- Landing page design updates
- Web design changes
- Vercel analytics
- Technology page

### Other

- Button py fix
- Initial plan
- Add comprehensive documentation for volume control architecture

Co-authored-by: Torteous44 <141182949+Torteous44@users.noreply.github.com>
- Add quick reference guide for volume control documentation

Co-authored-by: Torteous44 <141182949+Torteous44@users.noreply.github.com>
- Merge pull request #38 from Torteous44/copilot/find-max-volume-range

Document volume control architecture and physical device volume handling

## [1.1.7] - 2026-01-24

### Other

- Merge pull request #37 from Torteous44/redesign/simple-landing-page

Redesign/simple landing page

## [1.1.6] - 2026-01-24

### Bug Fixes

- Auto-detect macOS 26 SDK for glassEffect API compatibility
- Paper texture preloading (marketing)
- Improve memory safety in PluginV2 (unique_ptr, mmap bounds check, switch default)
- Improve popover responsiveness with caching, batched updates, and disabled animations
- Lint errors

### Features

- Marketing site

### Other

- Redesign marketing site to minimal single-page layout
- Merge pull request #36 from Torteous44/fixes/misc

Fixes/misc
- Merge branch 'main' of https://github.com/Torteous44/radioform into redesign/simple-landing-page

## [1.1.5] - 2026-01-18

### Bug Fixes

- Wrap glassEffect API in compiler check for SDK compatibility

### Other

- Merge pull request #35 from Torteous44/fix/issue-34-invalid-audio-device

fix: Crash on startup when default output is a monitor audio device w…

## [1.1.3] - 2026-01-18

### Bug Fixes

- Crash on startup when default output is a monitor audio device with no functional speakers

## [1.1.4] - 2026-01-07

### Other

- Update readme banner
- Update web hover styles and components
- Adjust card image styling for mobile responsiveness

### Performance

- Marketing site

## [1.1.2] - 2026-01-06

### Bug Fixes

- Onboarding prompt split across two lines
- Preset bundle path resolution and physical device volume control on startup

### Features

- Update card hover functionality with videos and new content
- Add apple logo to marketing site download button

### Other

- Merge pull request #30 from Torteous44/feat/web-hover-updates

feat(web): update card hover functionality with videos and new content
- Merge main into feat/web-hover-updates

Resolved conflicts in Card.tsx by keeping feature branch changes:
- Text-only hover tooltips for Radioform (DOWNLOAD) and fully open source (VIEW GITHUB)
- Radioform as download link instead of image hover
- Updated handleTextHover to support 4 parameters with text option
- Merge pull request #31 from Torteous44/feat/web-hover-updates

### Performance

- Marketing site

## [1.1.1] - 2026-01-05

### Bug Fixes

- Install create-dmg before creating the dmg in release

## [1.1.0] - 2026-01-05

### Features

- Update card hover functionality with videos and new content
- Add text hover tooltips and README image

### Other

- Optimize website images: use AVIF format and fix favicon location

- Move favicon.ico to src/app/ (Next.js convention)
- Replace PNG images with AVIF format for better compression:
  - manilafolder.png → manilafolder.avif
  - radioform.png → radioform.avif
  - paperclip.png → paperclip.avif
- Update all component references to use AVIF files
- Remove old PNG files from public directory
- Remove manual icon metadata (Next.js auto-detects favicon.ico)
- Add custom background support to DMG creation

- Update create_dmg.sh to use create-dmg tool for better DMG layout
- Add support for custom background image (tools/dmg/dmg-background.png)
- Configure window size, icon positioning, and app drop link
- Add fallback to basic hdiutil method if create-dmg is not installed
- Improve error messages and user feedback
- Prepare for release
- Merge pull request #28 from Torteous44/feat/website-optimize-images

Optimize website images: use AVIF format and fix favicon location
- Merge pull request #29 from Torteous44/feat/dmg-custom-background

Add custom background support to DMG creation
- Merge branch 'main' of https://github.com/Torteous44/radioform

## [1.0.35] - 2026-01-05

### Bug Fixes

- Driver update version comparison and simplify update prompt UI
- Production build by wrapping Preview in DEBUG guard
- Decouple driver and app versioning to prevent unnecessary update prompts

### Miscellaneous Tasks

- Remove unused files and components

### Other

- Update marketing site: fix interactions, center instructions, switch nav items, remove test pages
- Merge pull request #24 from Torteous44/cleanup/remove-unused-files

Cleanup/remove unused files / fix web
- Add website metadata: favicon, social preview, title and description
- Merge pull request #25 from Torteous44/feat/website-metadata

app icons, website meta data, styling
- Merge main into refactor/update-app-icons

- Resolved conflict in apps/mac/RadioformApp/Info.plist: preserved CFBundleIconFile
- packages/driver/Info.plist auto-merged successfully (matches main)
- Merge pull request #27 from Torteous44/refactor/update-app-icons

Refactor/update app icons - test PR

## [1.0.34] - 2026-01-04

### Testing

- Test release

## [1.0.33] - 2026-01-04

### Features

- Trigger a version check in background on launch

## [1.0.32] - 2026-01-04

### Testing

- Dummy commit

## [1.0.31] - 2026-01-04

### Bug Fixes

- Keep CFBundleVersion in sync with release version for Sparkle updates

## [1.0.30] - 2026-01-04

### Testing

- Test sparkle auto update with dummy commit

## [1.0.29] - 2026-01-04

### Bug Fixes

- No longer base64‑decodes the Sparkle key

## [1.0.28] - 2026-01-04

### Bug Fixes

- Generate_appcast invocation by using Sparkle’s --ed-key-file flag

## [1.0.27] - 2026-01-04

### Bug Fixes

- Sparkle appcast step by locating generate_appcast from the installed cask before invocation

## [1.0.26] - 2026-01-04

### Features

- Wire Sparkle appcast generation into release workflow and point SUFeedURL to hosted feed

## [1.0.25] - 2026-01-04

### Testing

- Test release dummy update

## [1.0.24] - 2026-01-04

### Bug Fixes

- Onboarding crash by loading images from main bundle and copying app resources into packaged app

## [1.0.23] - 2026-01-04

### Testing

- Test release dummy update

## [1.0.22] - 2026-01-04

### Bug Fixes

- Deeply sign sparkle

## [1.0.21] - 2026-01-04

### Bug Fixes

- Invocations in notarize step

## [1.0.20] - 2026-01-04

### Bug Fixes

- Heredoc indentation fix in release.yml 2

## [1.0.19] - 2026-01-04

### Bug Fixes

- Heredoc indentation fix in release.yml

## [1.0.18] - 2026-01-04

### Bug Fixes

- Signed the bundled Sparkle framework, extended verification, and improved CI notarization logging to address the Invalid notarization result

## [1.0.17] - 2026-01-04

### Bug Fixes

- Bundle Sparkle framework and set rpath for auto-updates

## [1.0.16] - 2026-01-04

### Bug Fixes

- Presets
- Remove vintagePaperBackground reference in OnboardingWindow

### Features

- Onboarding v1
- Onboarding v1.1
- Add Sparkle auto-update support with lazy driver updates

### Other

- Add onboarding style guidelines and update web components
- Merge pull request #21 from Torteous44/feat/marketingsite

Add onboarding style guidelines and update web components
- Clean up onboarding: remove reset animation and unused multi-step code
- Merge pull request #22 from Torteous44/feat/marketingsite

Clean up onboarding: remove reset animation and unused multi-step code

## [1.0.15] - 2026-01-03

### Bug Fixes

- Driver to drop stale Radioform proxies by treating dead host heartbeats as removal-worthy and persisting cache across removals

### Features

- Enhanced prewarping, DC blocker, zero-zipper smoothing, improved limiter

## [1.0.14] - 2026-01-03

### Bug Fixes

- Website enhancements
- Fix build errors
- Remove incorrect .shm extension from shared memory path

### Miscellaneous Tasks

- Update preset values

### Other

- Add folder-based UI with Card and Logs components, update styling and navigation
- Get changelog data from github API
- Merge pull request #20 from Torteous44/feature/folder-ui-components

Add folder-based UI with Card and Logs components, update styling and…
- Refactor app icons: use padded PNGs and SVG menu icon

- Updated create_app_bundle.sh to generate MyIcon.icns from padded PNGs in Sources/Resources/icons using iconutil
- Updated RadioformApp.swift to load menu bar icon from radioform-menu.svg instead of logo.svg
- Added new icon assets in Sources/Resources/icons/ (padded PNGs and SVG)
- Removed dependency on legacy icon assets (MyIcon.icns, MyIcon.iconset, Assets.xcassets)
- Fix Info.plist: preserve CFBundleIconFile and update to v1.0.15

- Restore CFBundleIconFile key that was lost during merge conflict resolution
- Update version to 1.0.15 to match main
- Add Sparkle update configuration keys
- Critical: Without CFBundleIconFile, macOS won't use the generated MyIcon.icns

## [1.0.12] - 2026-01-03

### Bug Fixes

- Readme header
- Readme line

### Miscellaneous Tasks

- Add gpl v3 license file
- Readme update, contributing md file
- Structural docs
- Changelogs, refactor host

## [1.0.10] - 2026-01-01

### Miscellaneous Tasks

- New presets - tbd?

## [1.0.9] - 2026-01-01

### Bug Fixes

- Workflow expecting version name

## [1.0.8] - 2026-01-01

### Miscellaneous Tasks

- Remove version name from create dmg script

## [1.0.7] - 2026-01-01

### Bug Fixes

- Turn down preamp
- Sync preset UI state on launch and strip sweetening bands to keep them invisible, migrate to driver v2

### Features

- Invisible audio sweetening
- Driver v2

## [1.0.6] - 2025-12-31

### Bug Fixes

-  fix: resolve proxy device management issues on startup and shutdown
- Move SSE headers to file scope for Linux compatibility
- Move SSE headers to file scope for Linux compatibility

### Features

- Add atomic preset writes, DSP quality improvements, and audio sweetening

### Other

- Add smooth icon transition animation for plus/x mark switching

- Add scale and opacity transition when switching between plus and x mark icons
- Animation only triggers on editing state changes, not preset switches
- Improves visual feedback when entering/exiting preset editing mode
- Onboarding ux
- Radioform naming fix
- Merge pull request #14 from Torteous44/feature/icon-transition-animation

Add smooth icon transition animation for plus/x mark switching
- Resolve race condition causing silent audio on first launch
- Merge pull request #15 from Torteous44/feat/race

resolve race condition causing silent audio on first launch
- Merge main into feature/icon-transition-animation - resolve conflicts
- Merge pull request #16 from Torteous44/feature/icon-transition-animation

Feature/icon transition animation
- Merge pull request #17 from Torteous44/feat/proxymanagement

 fix: resolve proxy device management issues on startup and shutdown
- Merge pull request #18 from Torteous44/feat/dsp

feat: add atomic preset writes, DSP quality improvements, and audio s…
- Merge pull request #19 from Torteous44/feat/dsp

fix: move SSE headers to file scope for Linux compatibility

## [1.0.5] - 2025-12-30

### Bug Fixes

- Convert to AppKit main entry point to prevent Settings window

## [1.0.4] - 2025-12-30

### Bug Fixes

- Remove LSUIElement and fix activation policy for onboarding

## [1.0.3] - 2025-12-30

### Bug Fixes

- Use proper DMG creation script with Applications symlink

## [1.0.2] - 2025-12-30

### Bug Fixes

- Add contents write permission to release workflow

## [1.0.1] - 2025-12-30

### Other

- Merge pull request #12 from Torteous44/feat/stuff

dmg ready
- Release v1
- Merge branch 'feat/releasetest'
- Merge pull request #13 from Torteous44/feat/v1

Feat/v1
- Ready for release

## [1.0.0] - 2025-12-30

### Bug Fixes

- Launch script, custom eq, eq on/off

### Features

- Add UI components and improvements
- Onboarding version 1
- Onboarding version 2

### Other

- Initial commit: project skeleton
- Working audio pipeline with HAL driver and host
- Dynamic device management, EQ MVP, Automatic proxy switching
- Fix launch script and improve host executable discovery

- Fix launch.sh to not check for devices before host starts (devices are created by host)
- Fix setup.sh to create build directory before running cmake
- Improve RadioformApp to dynamically find RadioformHost executable:
  - Search multiple possible locations (relative paths, home directory, env var)
  - Handle architecture-specific build directories (arm64-apple-macosx)
  - Support both release and debug builds
- Set RADIOFORM_ROOT environment variable in launch.sh for reliable host discovery
- Remove hardcoded user paths in favor of dynamic discovery
- Merge pull request #1 from Torteous44/fix/launch-script-improvements

Fix launch script and improve host executable discovery
- .github setup
- Merge pull request #2 from Torteous44/feat/github

.github setup
- .github fixes
- Fetch libASPL tags for driver build
- Remove pr template
- Merge pull request #3 from Torteous44/feat/githubHAL

CI: fetch libASPL tags for driver build
- Update Dropdown UI
- Merge pull request #4 from Torteous44/feat/equi

Update Dropdown UI
- UI improvements: standardized padding, improved preset dropdown, and hover states

- Removed Radioform title from header
- Standardized horizontal padding across all sections (20px for header/EQ, 8px for presets)
- Changed preset dropdown from popover to inline expandable list
- Updated hover states to use native Swift colors (separatorColor)
- Preset button shows blue fill when active and EQ is enabled
- Selected preset is excluded from dropdown list
- Improved toggle behavior to reapply preset when turning EQ back on
- Consistent padding between preset dropdown button and list items
- Ui ux improvements
- Merge pull request #5 from Torteous44/feat/all-changes-since-pr4

UI improvements: standardized padding, improved preset dropdown, and …
- Merge pull request #6 from Torteous44/feat/onboardingv1

feat: onboarding version 1
- Merge pull request #7 from Torteous44/feat/all-changes-since-pr4

marketing
- Merge pull request #8 from Torteous44/feat/onboardingv2

feat: onboarding version 2
- Code signing for max
- Merge pull request #9 from Torteous44/feat/codesigning

code signing for max
- Merge branch 'main' into feat/all-changes-since-pr4
- Merge pull request #10 from Torteous44/feat/all-changes-since-pr4

ui ux improvements
- Conflict fix
- Stuff
- Merge pull request #11 from Torteous44/feat/stuff

stuff
- Dmg ready

