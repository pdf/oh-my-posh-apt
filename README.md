# oh-my-posh-apt

Unofficial apt repository for [Oh My Posh](https://ohmyposh.dev), built automatically from upstream releases.

This project is not affiliated with or supported by the Oh My Posh project. Please report packaging problems here, not upstream.

## Install

Supports `amd64`, `arm64` and `armhf`.

```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://pdf.github.io/oh-my-posh-apt/key.gpg | sudo tee /etc/apt/keyrings/oh-my-posh-apt.gpg >/dev/null
sudo tee /etc/apt/sources.list.d/oh-my-posh-apt.sources >/dev/null <<EOF
Types: deb
URIs: https://pdf.github.io/oh-my-posh-apt
Suites: stable
Components: main
Signed-By: /etc/apt/keyrings/oh-my-posh-apt.gpg
EOF
sudo apt update && sudo apt install oh-my-posh
```

The themes are in a separate package, installed to `/usr/share/oh-my-posh/themes`:

```bash
sudo apt install oh-my-posh-themes
```

Upgrade with apt rather than `oh-my-posh upgrade`, which replaces the binary without apt knowing about it.

## Older versions

The repository keeps the last 5 versions. To roll back:

```bash
apt-cache madison oh-my-posh
sudo apt install --allow-downgrades oh-my-posh=VERSION
```

Older packages remain available from the [releases](https://github.com/pdf/oh-my-posh-apt/releases) page.

## Uninstall

```bash
sudo apt remove oh-my-posh oh-my-posh-themes
sudo rm /etc/apt/sources.list.d/oh-my-posh-apt.sources /etc/apt/keyrings/oh-my-posh-apt.gpg
```

## Hash Sum mismatch

If `apt update` reports this just after a new version is published, try again a few minutes later.

## License

The packaging in this repository is [MIT](LICENSE). Oh My Posh is MIT licensed by its authors, and its license is installed with each package.
