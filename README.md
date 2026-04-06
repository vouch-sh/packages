# Vouch Packages

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

APT and YUM/DNF package repositories for [Vouch](https://github.com/vouch-sh/vouch) — hardware-backed identity for developers.

Hosted at [packages.vouch.sh](https://packages.vouch.sh).

## Installation

### APT (Debian / Ubuntu)

```bash
curl -fsSL https://packages.vouch.sh/gpg/vouch.asc \
  | gpg --dearmor \
  | sudo tee /usr/share/keyrings/vouch-archive-keyring.gpg > /dev/null

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/vouch-archive-keyring.gpg] https://packages.vouch.sh/apt stable main" \
  | sudo tee /etc/apt/sources.list.d/vouch.list > /dev/null

sudo apt-get update && sudo apt-get install -y vouch
```

### YUM / DNF (Fedora / RHEL)

```bash
sudo tee /etc/yum.repos.d/vouch.repo << 'EOF'
[vouch]
name=Vouch
baseurl=https://packages.vouch.sh/rpm/$basearch/
gpgcheck=1
gpgkey=https://packages.vouch.sh/gpg/vouch.asc
enabled=1
EOF

sudo dnf install -y vouch
```

## Packages

| Package | Type | Architectures |
|---------|------|---------------|
| `vouch` | APT (.deb) | amd64, arm64 |
| `vouch` | RPM (.rpm) | x86_64, aarch64 |
| `vouch-server` | RPM (.rpm) | x86_64, aarch64 |

## GPG Verification

All packages and repository metadata are signed. The public key is available at [`/gpg/vouch.asc`](https://packages.vouch.sh/gpg/vouch.asc).

## Repository Structure

```
apt/
  pool/main/          .deb packages
  dists/stable/       APT repository metadata
rpm/
  x86_64/             x86_64 .rpm packages + repodata
  aarch64/            aarch64 .rpm packages + repodata
gpg/
  vouch.asc           GPG public key
```

## License

[MIT](LICENSE)
