# Distribution

## Current Release Model

QuickPeek is distributed directly through GitHub Releases as a universal macOS app.

The release artifact is:

- Built in the Xcode `Release` configuration
- Compatible with Apple silicon and Intel Macs
- Sandboxed with outbound network access
- Built with hardened runtime enabled
- Ad-hoc signed and validated with `codesign`
- Published with a SHA-256 checksum
- Not notarized

## Why It Is Not Notarized

Apple's notary service requires software to be signed with a Developer ID certificate. Developer ID certificates require membership in the paid Apple Developer Program.

An ad-hoc signature verifies the internal integrity of the app bundle after it is built, but it does not establish a trusted developer identity with Gatekeeper. Users should expect the first-launch warning documented in the README.

Apple's official documentation:

- [Developer ID](https://developer.apple.com/support/developer-id/)
- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)

## Release Artifact

Run:

```bash
./script/package_release.sh
```

The script creates:

```text
dist/QuickPeek-v<VERSION>-macOS.zip
dist/QuickPeek-v<VERSION>-macOS.zip.sha256
```

It also validates:

- The app bundle exists
- The ad-hoc signature is internally valid
- The executable includes `arm64` and `x86_64`

## Future Developer ID Upgrade

If the project later joins the Apple Developer Program:

1. Sign Release builds with a Developer ID Application certificate.
2. Keep hardened runtime enabled.
3. Submit the archive with `notarytool`.
4. Staple the accepted notarization ticket.
5. Validate the final artifact with Gatekeeper before publishing.

Until then, releases should remain transparent about the ad-hoc signature and include checksums.
