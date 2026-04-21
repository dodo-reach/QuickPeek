# QuickPeek Release Checklist

Use this before publishing a public build.

1. Run `./script/build_and_run.sh --verify`
2. Run `./script/package_release.sh`
3. Open the packaged app on a clean macOS account or second Mac
4. Confirm at least one tracker refresh works for GitHub and one non-GitHub source
5. Confirm optional API keys save and reload correctly
6. If shipping binaries to users, sign and notarize the release artifact before publishing it on GitHub
