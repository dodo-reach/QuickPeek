# QuickPeek Release Checklist

QuickPeek is currently published as an ad-hoc signed, non-notarized GitHub release. Follow this checklist for every public build.

## Prepare

1. Confirm the intended version and build number in `QuickPeek.xcodeproj`.
2. Update the release notes for the version being published.
3. Review `git status` and commit every intended source, project, script, and documentation change.
4. Confirm no build output, credentials, diagnostics, or local Xcode state is staged.

## Verify

1. Run `git diff --check`.
2. Run the unit tests in Xcode or with:

   ```bash
   xcodebuild -project QuickPeek.xcodeproj -scheme QuickPeek -configuration Debug -destination "platform=macOS" test
   ```

3. Run a Release build and static analysis:

   ```bash
   xcodebuild -project QuickPeek.xcodeproj -scheme QuickPeek -configuration Release -destination "generic/platform=macOS" build analyze
   ```

4. Run `./script/build_and_run.sh --verify`.
5. Confirm at least one GitHub tracker and one non-GitHub tracker refresh successfully.
6. Confirm optional API keys save, reload, and can be removed.
7. Confirm dragged tracker order survives an app restart.

## Package

1. Run:

   ```bash
   ./script/package_release.sh
   ```

2. Confirm the script validates the app signature and reports both `arm64` and `x86_64`.
3. Verify the generated checksum:

   ```bash
   cd dist
   shasum -a 256 -c QuickPeek-v*-macOS.zip.sha256
   ```

4. Unzip the archive and open the packaged app on a clean macOS account or second Mac.
5. Confirm the documented **Right-click > Open** / **Open Anyway** first-launch path works.

## Publish

1. Confirm the working tree is clean.
2. Create and push the release commit.
3. Create and push an annotated version tag, for example:

   ```bash
   git tag -a v1.1.0 -m "QuickPeek v1.1.0"
   git push origin main v1.1.0
   ```

4. Create a GitHub release from the tag.
5. Paste the matching release notes.
6. Upload both the versioned `.zip` and `.sha256` files.
7. State clearly that the release is ad-hoc signed and not notarized.

Do not submit the ad-hoc build to Apple's notary service. Apple requires a Developer ID certificate, which requires Apple Developer Program membership.
