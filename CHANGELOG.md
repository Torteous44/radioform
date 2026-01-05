
## [Unreleased]

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

