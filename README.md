# QuickPeek

QuickPeek is a tiny macOS menu bar app for people who keep wasting attention on the same pages over and over.

GitHub stars. YouTube subscribers. Bluesky followers. npm downloads. That one post you know is not moving every five minutes, but you still check anyway.

QuickPeek keeps the numbers in your menu bar so you can stop donating focus to platforms that love being checked.

## Why It Exists

Some metrics matter. Constantly opening five tabs to see whether they changed does not.

QuickPeek gives you one fast place to monitor the public numbers you actually care about, without turning your day into a loop of "just checking something quickly".

## What It Tracks

- GitHub: stars, forks, watchers, open issues, open pull requests
- Reddit: subreddit subscribers, user karma, post upvotes
- YouTube: channel subscribers
- X: followers, post likes
- Bluesky: followers, posts
- npm: weekly downloads
- Discord: member count, online count
- Instagram: followers, likes, comments

## Why It Feels Safe

- No backend, no account system, no tracking
- Tracker data stays on-device in `UserDefaults`
- Optional API credentials are stored in the macOS Keychain
- Most sources work without login; optional keys simply improve reliability for supported services

## Requirements

- macOS 14.0 or newer
- Xcode 16.3 or newer if you want to build from source

## Build From Source

```bash
git clone https://github.com/dodo-reach/QuickPeek.git
cd QuickPeek
./script/build_and_run.sh
```

If `xcodebuild` is pointing at Command Line Tools instead of full Xcode, the script will tell you what to fix.

## Packaging A Release Build

```bash
./script/package_release.sh
```

That generates `dist/QuickPeek-macOS.zip`.

## Notes

- QuickPeek is designed for public metrics, not private dashboard access
- Some platforms use scraping fallbacks, so they may occasionally break when a site changes
- If you ship public binaries, notarization is still the right final step for the smoothest first-launch experience on users' Macs

## License

MIT. See [LICENSE](LICENSE).
