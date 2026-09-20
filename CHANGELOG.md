# Changelog

All notable changes to SleepBar will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.3.0](https://github.com/nateships/sleepbar/compare/v1.2.0...v1.3.0) (2026-09-20)


### Features

* sleep when the current media item ends ([3098313](https://github.com/nateships/sleepbar/commit/3098313039ffdcd5b0fedb9c00d8c7d37c6a3c44))
* sleep when the current media item ends ([95c788a](https://github.com/nateships/sleepbar/commit/95c788abc3ac431eb628d5d7190f0ba8fdb78764))


### Bug Fixes

* keep the provisioning profile off Swift package targets ([833deea](https://github.com/nateships/sleepbar/commit/833deeac36bcecb34470998fda56ad1f99ff61ad))

## [1.2.0] - 09-13-2026

#### Added
- **Open at Login**: New toggle in the menu to start SleepBar automatically when you log in

#### Bug Fixes
- Custom timer values are remembered as you type them

#### Updated
- Updated Sparkle auto-update framework to 2.9.6

#### Under the Hood
- The app is notarized and stapled on its own, so first launch and Sparkle updates verify offline

## [1.1.0] - 03-08-2026

#### Added
- **Anonymous Analytics**: Opt-out usage analytics via Apple's iCloud (CloudKit) to help improve SleepBar — no personal data collected
- **License Self-Service**: Manage your license directly from the About window — activate, deactivate, or purchase
- **Privacy Policy**: Published at [sleepbar.app/privacy](https://sleepbar.app/privacy)

#### Improved
- **About Window**: Now appears above other windows and dismisses the menu bar popover when opened
- **License Validation**: Improved reliability of license validation, especially on unreliable network connections
- **Drive Ejection**: Improved reliability of external drive ejection before system sleep

#### Bug Fixes
- Fixed extra spacing in the settings area of the main menu
- Fixed "Sleep Now" from the pre-sleep alert incorrectly logging as a timer cancellation

#### Under the Hood
- Added unit test suite covering timer logic, license management, and input validation
- General code quality and stability improvements

## [1.0.6] - 02-26-2026

#### Bug Fixes
- **License Validation**: Fixed an issue where a valid license could show as an expired trial after a few days if a background re-validation encountered a network error

#### Updated
- Updated Sparkle auto-update framework to 2.9.0

## [1.0.5] - 11-25-2025

#### Added
- **Sleep Now Button**: Bypass the countdown and sleep immediately from the pre-sleep alert
- **Movable Alert Window**: Drag the pre-sleep alert window anywhere on screen
- **Remember Last Settings**: App now remembers your last used timer settings, sleep mode, and custom timer inputs

#### Improved
- **Redesigned Pre-Sleep Alert**: Larger, more colorful buttons with icons for better visibility
- Blue snooze buttons, orange Sleep Now, and red Cancel for clear visual hierarchy

## [1.0.4] - 11-20-2025

#### Added
- **Configurable Pre-Sleep Alert**: Customize when you receive the warning before sleep
- **Toggle Alert On/Off**: Option to enable or disable pre-sleep alerts entirely

## [1.0.3] - 11-05-2025

#### Added
- Eject removable drives before sleeping when selecting system sleep. Thanks /u/snarky_one

## [1.0.2] - 11-04-2025

#### Bug Fixes
- Fix target time not updating properly

## [1.0.1] - 11-03-2025

### 🎉 Initial Release

#### Added
- Quick timer presets (15, 30, 60, 120 minutes)
- Custom duration timer with hours and minutes
- Schedule sleep at a specific time
- Choose between system sleep or display-only sleep
- Pre-sleep warning notification (1 minute before timer expires)
- Option to cancel or snooze timer from warning popup
- Beautiful liquid glass design following Apple's guidelines
- Menu bar integration with active timer display
- Automatic updates via Sparkle framework
- 7-day free trial
- License activation via Lemon Squeezy

---

## Future Releases

Have a feature request? [Open an issue](https://github.com/nateships/sleepbar/issues) or email [hi@sleepbar.app](mailto:hi@sleepbar.app)!

---

[1.0.0]: https://github.com/nateships/sleepbar/releases/tag/v1.0.0
