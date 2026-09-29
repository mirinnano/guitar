# Releasing Guitar Tools

Releases are created automatically from semantic-version tags such as `v0.1.0`.

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

## 4. Publish a release

After the release commit is on `main`:

```bash
git checkout main
git pull
git tag v0.1.0
git push origin v0.1.0
```

The `Release APK` workflow will:

1. Validate the semantic-version tag.
2. Restore the signing keystore only inside the GitHub runner.
3. Run unit tests.
4. Build `assembleRelease`.
5. Verify the APK signature with `apksigner`.
6. Generate a SHA-256 checksum.
7. Upload the APK as a workflow artifact.
8. Create a GitHub Release containing:
   - `guitar-tools-v0.1.0.apk`
   - `guitar-tools-v0.1.0.apk.sha256`

The tag also controls Android version metadata. For example:

- `v0.1.0` → `versionName 0.1.0`, `versionCode 100`
- `v1.2.3` → `versionName 1.2.3`, `versionCode 10203`

Use each semantic version only once, and always increase the version for later releases.
