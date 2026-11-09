# Maintaining

## How it works

Every 6 hours, [publish.yml](../.github/workflows/publish.yml) compares upstream's latest release with the `published-version` file, and stops if nothing is new. Drafts, prereleases and any tag that is not plain `vX.Y.Z` are never published. For a new version it:

1. Verifies the download. `checksums.txt` must carry a valid signature from upstream's Ed25519 key, pinned in [upstream/public_key.pem](../upstream/public_key.pem), and the binaries must match it. `themes.zip` is not listed in `checksums.txt`, so it is checked against the digest GitHub reports for the asset, which only protects against a corrupted download.
2. Builds the `.deb` files with [nfpm](https://nfpm.goreleaser.com/) and stores them as a release of this repository.
3. Builds the index from the last 5 releases with [aptly](https://www.aptly.info/), signs it, and deploys it to GitHub Pages.
4. Installs the result in clean Debian 13 and Ubuntu 26.04 containers on each architecture (arm under QEMU), then records the version. A failed run is retried on the next schedule.

[test.yml](../.github/workflows/test.yml) runs the same pipeline on pull requests, with a throwaway key and a repository served from the runner, without publishing anything.

## Design decisions

- **`.debs` are served from Pages, not from releases.** apt resolves a package's path relative to the repository URL, so packages must be on the same host as the index, and Pages can't redirect elsewhere. The releases are the durable store that each run rebuilds the site from.
- **aptly over reprepro.** aptly keeps several versions of a package in one repository by default, and its database can be discarded after each run.
- **Pages Actions deployment over a `gh-pages` branch.** It keeps binaries out of git history.

## Scheduled workflow inactivity

GitHub disables scheduled workflows in public repositories after 60 days without repository activity. Each publish makes a commit, and if nothing has been published for 45 days the workflow makes an empty commit. GitHub doesn't define "activity", so if the schedule is ever disabled anyway, turn it back on:

```bash
gh workflow enable publish.yml --repo pdf/oh-my-posh-apt
```

## Setup

Run these once. The key has no passphrase because it only ever lives in an Actions secret, and no expiry because an expired key would break `apt update` for every user.

1. Generate the signing key in a temporary keyring and store it as a secret:

   ```bash
   export GNUPGHOME=$(mktemp -d)
   gpg --batch --passphrase '' --quick-generate-key 'oh-my-posh-apt <oh-my-posh-apt@c0dedbad.com>' ed25519 sign never
   gpg --armor --export-secret-keys oh-my-posh-apt@c0dedbad.com | gh secret set APT_SIGNING_KEY --repo pdf/oh-my-posh-apt
   gpg --fingerprint oh-my-posh-apt@c0dedbad.com
   ```

2. Note the fingerprint, then delete the temporary keyring. Nothing else needs the private key, and if the secret is ever lost you rotate to a new key.

   ```bash
   gpgconf --kill all
   rm -rf "$GNUPGHOME"
   unset GNUPGHOME
   ```

3. Enable Pages with Actions as the source:

   ```bash
   gh api -X POST repos/pdf/oh-my-posh-apt/pages -f build_type=workflow
   ```

4. Run the first publish:

   ```bash
   gh workflow run publish.yml --repo pdf/oh-my-posh-apt
   ```

## Rotating the signing key

Repeat steps 1 and 2 of the setup, then run the workflow with `force` enabled. Users must fetch `key.gpg` again.
