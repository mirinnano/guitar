# Releasing Guitar Tools

Semantic-version tags (`vX.Y.Z`) publish a shared macOS / Android release.
Never move a published tag or replace it with different source code.

## Preflight

1. Run Swift tests, Debug / Release builds, and relevant live UI checks.
2. Check `macOS/AppResources/Info.plist` version against the intended tag and update its build number.
3. Keep `AppIcon.png` and `AppIcon.icns` in sync using `macOS/scripts/generate-app-icon.sh`.
4. Confirm `docs/releases/vX.Y.Z.md` exists and describes signing, notarization and CPU support honestly.
5. Update README, install instructions, and original demo screenshots as needed.
6. Push the release commit to `main` and wait for required CI checks to pass.

Mac builds currently use **ad-hoc signing, without Developer ID or notarization**.
`macos-15` currently supplies an arm64 runner, so the distributed app targets Apple Silicon.
Both Mac workflows explicitly use Xcode 26.3 so native Liquid Glass is included,
while runtime availability checks keep macOS 14/15 supported.
There is no universal / Intel binary. Confirm runner architecture in each release.
Do not describe signature verification as Apple approval or Gatekeeper acceptance.

## 1. Create the release signing key once

Run locally:

```bash
keytool -genkeypair -v \
  -keystore guitar-tools-release.jks \
  -storetype JKS \
  -alias guitar-tools \
  -keyalg RSA \
  -keysize 4096 \
  -validity 10000
```

Keep this keystore backed up offline. Future APK updates must be signed with the same key.

Do not commit the keystore to Git.

## 2. Convert the keystore to a GitHub Secret

```bash
base64 < guitar-tools-release.jks | tr -d '\n'
```

Copy the output.

## 3. Add repository Actions secrets

Open:

`Settings → Secrets and variables → Actions → New repository secret`

Create these four secrets:

| Secret | Value |
| --- | --- |
| `RELEASE_KEYSTORE_BASE64` | Base64 output of the keystore |
| `RELEASE_STORE_PASSWORD` | Keystore password |
| `RELEASE_KEY_ALIAS` | `guitar-tools` unless you chose another alias |
| `RELEASE_KEY_PASSWORD` | Key password |
| `GETSONGBPM_API_KEY` | Optional GetSongBPM API key for BPM/key metadata |

The GetSongBPM secret is optional. Without it, song search falls back to MusicBrainz and the app remains fully buildable.

## Publish

After successful main CI, tag the verified commit:

```bash
git tag v0.3.0
git push origin v0.3.0
```

`release/vX.Y.Z` branches also trigger the workflows, but a single immutable tag is preferred for a public release.

The **macOS Release** workflow runs Swift tests, packages and verifies the app,
checks the plist version and icon, runs `--smoke-test`, and creates the shared GitHub Release using the versioned notes.
It uploads:

- `Guitar Tools-X.Y.Z.dmg`
- `Guitar Tools-X.Y.Z.sha256`

The app bundle is also retained as an Actions artifact.

The **Release APK** workflow restores the existing signing key inside the runner,
runs Android unit tests, builds and verifies a signed APK, then attaches it to the same release:

- `guitar-tools-vX.Y.Z.apk`
- `guitar-tools-vX.Y.Z.apk.sha256`

The APK workflow waits for the Mac workflow to create the release.
If its bounded wait expires, confirm the Mac workflow succeeded before rerunning the APK job.
Do not generate a new Android signing key for an update.

## Post-release checks

- Both release workflows succeeded, and all four expected assets are present.
- Download DMG / APK and verify their SHA-256 values against the attached checksum files.
- Verify the packaged icon, bundle version, binary architecture, ad-hoc signature, and smoke test.
- Live UI checks, local tests, CI tests, and a clean Mac first-install test are different evidence. Report each separately.
- Publish announcements from `docs/launch.md` only to destinations authorized by the maintainer.

Android version metadata derives from the tag: `v1.2.3` yields versionName `1.2.3` and versionCode `10203`.
