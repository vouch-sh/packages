# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a **package distribution repository**, not a source code project. It hosts pre-built APT and YUM/DNF packages for [Vouch](https://github.com/vouch-sh/vouch) (hardware-backed identity for developers), served via GitHub Pages at `packages.vouch.sh`.

There is no source code, build system, test suite, or CI/CD configuration here. Packages are built in the upstream [vouch-sh/vouch](https://github.com/vouch-sh/vouch) repository and pushed here by GitHub Actions automation.

## Structure

- `apt/pool/main/` — `.deb` packages (amd64, arm64)
- `apt/dists/stable/` — APT repository metadata (Release, InRelease, Packages)
- `rpm/x86_64/`, `rpm/aarch64/` — `.rpm` packages with `repodata/` metadata
- `gpg/vouch.asc` — GPG public key for repository signing
- `apt-ftparchive.conf` — APT metadata generation config
- `index.html` — Static landing page with installation instructions

## Release Process

Releases are fully automated. The upstream CI:
1. Builds vouch binaries for amd64/arm64
2. Creates `.deb` and `.rpm` packages
3. Adds packages to `apt/pool/` and `rpm/{arch}/`
4. Regenerates APT metadata (`apt-ftparchive`) and RPM metadata (`createrepo_c`)
5. Signs metadata with the GPG key
6. Commits and pushes to this repository

Versioning follows `YYYY.M.patch` format (e.g., `2026.3.4`).

## Key Details

- **Architectures**: amd64/x86_64 and arm64/aarch64
- **Package types**: `vouch` (client) and `vouch-server` (RPM only)
- **APT suite**: `stable`, component `main`
- **All repository metadata is GPG-signed** (Release.gpg, InRelease, repomd.xml.asc)
- **Hosted on GitHub Pages** (CNAME → packages.vouch.sh, `.nojekyll` present)
