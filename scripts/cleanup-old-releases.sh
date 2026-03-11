#!/usr/bin/env bash
#
# cleanup-old-releases.sh — Remove old package versions, keeping the N most recent.
# After removal, regenerates APT and RPM repository metadata and signs it.
#
# Usage: ./scripts/cleanup-old-releases.sh [--keep N] [--dry-run]
#
# Environment:
#   GPG_KEY_ID  — GPG key fingerprint/ID used to sign metadata (required unless --dry-run)
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEEP=5
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep)   KEEP="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--keep N] [--dry-run]"
      echo "  --keep N     Number of most recent versions to keep (default: 5)"
      echo "  --dry-run    Show what would be removed without deleting anything"
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Safety: require at least 2 versions to be kept
if [[ "$KEEP" -lt 2 ]]; then
  echo "ERROR: --keep must be at least 2 to ensure users can always install a package." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Version sorting helper
# ---------------------------------------------------------------------------
sort_versions() {
  sort -t. -k1,1n -k2,2n -k3,3n
}

# ---------------------------------------------------------------------------
# Discover all unique versions present across deb and rpm packages
# ---------------------------------------------------------------------------
discover_versions() {
  {
    # .deb files: vouch_<version>_<arch>.deb
    if [[ -d "$REPO_ROOT/apt/pool/main" ]]; then
      find "$REPO_ROOT/apt/pool/main" -name "*.deb" -printf '%f\n' 2>/dev/null \
        | sed 's/^vouch_//; s/_[^_]*\.deb$//' \
        | sort -u
    fi

    # .rpm files: vouch-<version>-1.<arch>.rpm or vouch-server-<version>-1.<arch>.rpm
    for arch_dir in "$REPO_ROOT/rpm/x86_64" "$REPO_ROOT/rpm/aarch64"; do
      if [[ -d "$arch_dir" ]]; then
        find "$arch_dir" -name "*.rpm" -printf '%f\n' 2>/dev/null \
          | sed 's/^vouch-server-//; s/^vouch-//; s/-1\.[^.]*\.rpm$//' \
          | sort -u
      fi
    done
  } | grep -v '^$' | sort -u | sort_versions
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
all_versions="$(discover_versions)"
total="$(echo "$all_versions" | wc -l)"

removed_count=0

if [[ "$total" -le "$KEEP" ]]; then
  echo "Only $total version(s) found, nothing to clean up (keeping $KEEP)."
else
  versions_to_remove="$(echo "$all_versions" | head -n -"$KEEP")"
  versions_to_keep="$(echo "$all_versions" | tail -n "$KEEP")"

  echo "=== Cleanup Summary ==="
  echo "Total versions found: $total"
  echo "Keeping $KEEP most recent:"
  echo "$versions_to_keep" | sed 's/^/  /'
  echo ""
  echo "Removing $(echo "$versions_to_remove" | wc -l) older version(s):"
  echo "$versions_to_remove" | sed 's/^/  /'
  echo ""

  if $DRY_RUN; then
    echo "[dry-run] No files will be deleted."
    echo ""
    echo "Files that would be removed:"
  fi

  while IFS= read -r ver; do
    # Remove .deb packages for this version
    for f in "$REPO_ROOT/apt/pool/main/vouch_${ver}_"*.deb; do
      [[ -e "$f" ]] || continue
      if $DRY_RUN; then
        echo "  would remove: ${f#$REPO_ROOT/}"
      else
        echo "  removing: ${f#$REPO_ROOT/}"
        rm -f "$f"
      fi
      removed_count=$((removed_count + 1))
    done

    # Remove .rpm packages for this version (vouch and vouch-server)
    for arch_dir in "$REPO_ROOT/rpm/x86_64" "$REPO_ROOT/rpm/aarch64"; do
      [[ -d "$arch_dir" ]] || continue
      for f in "$arch_dir/vouch-${ver}-1."*.rpm "$arch_dir/vouch-server-${ver}-1."*.rpm; do
        [[ -e "$f" ]] || continue
        if $DRY_RUN; then
          echo "  would remove: ${f#$REPO_ROOT/}"
        else
          echo "  removing: ${f#$REPO_ROOT/}"
          rm -f "$f"
        fi
        removed_count=$((removed_count + 1))
      done
    done
  done <<< "$versions_to_remove"
fi

echo ""
if $DRY_RUN; then
  echo "Files that would be removed: $removed_count"
  echo "[dry-run] Skipping metadata regeneration."
  exit 0
fi

echo "Packages removed: $removed_count"

# ---------------------------------------------------------------------------
# Safety check: ensure GPG_KEY_ID is set before signing metadata
# ---------------------------------------------------------------------------
if [[ -z "${GPG_KEY_ID:-}" ]]; then
  echo "ERROR: GPG_KEY_ID is not set. Metadata must be signed to keep the" >&2
  echo "repository functional. Set GPG_KEY_ID and re-run, or use --dry-run." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Regenerate APT metadata
# ---------------------------------------------------------------------------
echo ""
echo "=== Regenerating APT metadata ==="

apt_dists="$REPO_ROOT/apt/dists/stable"
cd "$REPO_ROOT"

for arch in amd64 arm64; do
  mkdir -p "$apt_dists/main/binary-$arch"
  packages_file="$apt_dists/main/binary-$arch/Packages"

  if dpkg-scanpackages --arch "$arch" apt/pool/main /dev/null \
       > "$packages_file" 2>/dev/null; then
    : # success
  elif command -v apt-ftparchive >/dev/null 2>&1; then
    # Fallback: generate all-arch Packages, then filter to the target arch
    apt-ftparchive packages apt/pool/main 2>/dev/null \
      | awk -v arch="$arch" '
          BEGIN { rec=""; match_arch=0 }
          /^$/ {
            if (match_arch) printf "%s\n", rec
            rec=""; match_arch=0; next
          }
          { rec = (rec == "" ? $0 : rec "\n" $0) }
          /^Architecture: / && $2 == arch { match_arch=1 }
          END { if (match_arch && rec != "") printf "%s\n", rec }
        ' > "$packages_file"
  else
    echo "ERROR: Neither dpkg-scanpackages nor apt-ftparchive is available." >&2
    exit 1
  fi

  gzip -9 -k -f "$packages_file"
  echo "  Generated Packages for $arch ($(grep -c '^Package:' "$packages_file" || echo 0) packages)"
done

# Generate Release file
apt-ftparchive \
  -c apt-ftparchive.conf \
  release "$apt_dists" \
  > "$apt_dists/Release"

# Sign Release file
rm -f "$apt_dists/Release.gpg" "$apt_dists/InRelease"
gpg --batch --yes --default-key "$GPG_KEY_ID" \
  -abs -o "$apt_dists/Release.gpg" "$apt_dists/Release"
gpg --batch --yes --default-key "$GPG_KEY_ID" \
  --clearsign -o "$apt_dists/InRelease" "$apt_dists/Release"
echo "  APT metadata signed."

# ---------------------------------------------------------------------------
# Regenerate RPM metadata
# ---------------------------------------------------------------------------
echo ""
echo "=== Regenerating RPM metadata ==="

for arch_dir in "$REPO_ROOT/rpm/x86_64" "$REPO_ROOT/rpm/aarch64"; do
  [[ -d "$arch_dir" ]] || continue
  echo "  createrepo_c: ${arch_dir#$REPO_ROOT/}"
  createrepo_c --update "$arch_dir"

  rm -f "$arch_dir/repodata/repomd.xml.asc"
  gpg --batch --yes --default-key "$GPG_KEY_ID" \
    --detach-sign --armor "$arch_dir/repodata/repomd.xml"
  echo "  RPM metadata signed: ${arch_dir#$REPO_ROOT/}"
done

echo ""
echo "=== Cleanup complete ==="
