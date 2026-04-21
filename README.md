# QuickPeek

QuickPeek is a tiny macOS menu bar app for people who keep wasting attention on the same pages over and over.

GitHub stars. X followers. YouTube subscribers. Bluesky followers. npm downloads. That one post you know is not moving every five minutes, but you still check anyway.

QuickPeek keeps the numbers in your menu bar so you can stop donating focus to platforms that love being checked.

## Why It Exists

Some metrics matter. Constantly opening five tabs to see whether they changed does not.

QuickPeek gives you one fast place to monitor the public numbers you actually care about, without turning your day into a loop of "just checking something quickly".

## What It Tracks

- GitHub: stars, forks, watchers, open issues, open pull requests
- Reddit: subreddit subscribers, user karma, post upvotes
- YouTube: channel subscribers, video views, video likes
- TikTok: profile followers, profile total likes, video views, video likes
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

## Download

You can grab the latest `.zip` from [GitHub Releases](https://github.com/dodo-reach/QuickPeek/releases).

### About The macOS Warning

QuickPeek is currently distributed without Apple's paid Developer ID / notarization flow.

That means macOS may show the classic "Apple could not verify this app" warning the first time you open it. That is annoying, but it does **not** mean the app is malware. It means the app was shipped directly by the developer instead of through Apple's paid trust pipeline.

If you want to use QuickPeek, you have two easy options:

- Download the zip from this repository and open the app with `Right click > Open`
- If macOS blocks it, go to `System Settings > Privacy & Security` and click `Open Anyway`

If that still feels too sketchy for you, that is fair:

- Build it yourself from source in Xcode
- Or keep opening the same apps ten times a day to check if a number changed

QuickPeek is trying to help with the second one. Do what you want now.

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
- TikTok support uses public embed pages only; private or age-restricted profiles/videos are not supported
- Facebook post/reel likes are intentionally not supported yet because the no-login public path is not stable enough for a trust-first release
- GitHub release builds are currently not notarized, so first launch on macOS may require `Open Anyway`

## License

MIT. See [LICENSE](LICENSE).
