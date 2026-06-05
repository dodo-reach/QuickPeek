# QuickPeek

QuickPeek is a small macOS menu bar app for keeping useful public metrics close without repeatedly opening dashboards and social apps.

It stores trackers locally, refreshes them on demand, and opens the original source when you click a tracker.

## Supported Metrics

- GitHub: stars, forks, watchers, open issues, open pull requests
- Reddit: subreddit subscribers, user karma, post upvotes
- YouTube: channel subscribers, video views, video likes
- TikTok: profile followers, profile total likes, video views, video likes
- X: followers, post likes
- Bluesky: followers, posts
- npm: weekly downloads
- Discord: member count, online count
- Instagram: followers, likes, comments

## Privacy

- No backend, account system, analytics, or tracking
- Tracker data stays on-device in `UserDefaults`
- Optional YouTube and X credentials are stored in the macOS Keychain
- API credentials are redacted from request error logs
- Most sources work without signing in

## Requirements

- macOS 14.0 or newer
- Apple silicon or Intel Mac
- Xcode 16.3 or newer only when building from source

## Download And Install

Download the latest `QuickPeek-v*-macOS.zip` and matching `.sha256` file from [GitHub Releases](https://github.com/dodo-reach/QuickPeek/releases).

Verify the download from Terminal:

```bash
shasum -a 256 -c QuickPeek-v*-macOS.zip.sha256
```

Then unzip the archive and move `QuickPeek.app` to `Applications`.

### First Launch

QuickPeek is currently distributed with an ad-hoc signature because the project does not have a paid Apple Developer Program membership. Apple requires a Developer ID certificate for notarization, so this build cannot be notarized.

On first launch, macOS may block the app because it cannot verify the developer:

1. Right-click `QuickPeek.app` and choose **Open**.
2. If macOS still blocks it, open **System Settings > Privacy & Security**.
3. Find the QuickPeek message and choose **Open Anyway**.

The checksum published with every release lets you verify that the downloaded archive matches the one produced for that release.

## Build From Source

```bash
git clone https://github.com/dodo-reach/QuickPeek.git
cd QuickPeek
./script/build_and_run.sh
```

To build and confirm that the menu bar process starts:

```bash
./script/build_and_run.sh --verify
```

## Package A Release

```bash
./script/package_release.sh
```

The script builds a hardened universal Release app, validates its ad-hoc signature and architectures, then creates:

```text
dist/QuickPeek-v<VERSION>-macOS.zip
dist/QuickPeek-v<VERSION>-macOS.zip.sha256
```

See [docs/distribution.md](docs/distribution.md) for the current distribution model and [docs/release-checklist.md](docs/release-checklist.md) before publishing a release.

## Reliability Notes

- QuickPeek tracks public metrics, not private dashboards.
- Some sources use public-page scraping fallbacks and can temporarily break when a site changes.
- TikTok supports public profiles and videos only; private or age-restricted content is not supported.
- Optional API credentials improve reliability for supported services but are not required.

## License

MIT. See [LICENSE](LICENSE).
