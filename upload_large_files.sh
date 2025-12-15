#!/bin/bash
set -x  # Enable debug output
# upload_large_files.sh
# Scans for files not ignored by .gitignore, checks if >100MB, uploads to GitHub Releases



set -e


# DRY_RUN=1 for local test, DRY_RUN=0 for actual upload
DRY_RUN=0

# Check if gh CLI is installed and authenticated
if ! command -v gh >/dev/null 2>&1; then
  echo "Error: GitHub CLI (gh) is not installed. Please install it and authenticate."
  exit 1
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "Error: GitHub CLI (gh) is not authenticated. Please run 'gh auth login'."
  exit 1
fi

# List all files tracked or not ignored by git
FILES=$(git ls-files --others --exclude-standard --cached)

# List ignored files
IGNORED_FILES=$(git ls-files --others --ignored --exclude-standard)

for FILE in $FILES; do
  echo "Checking $FILE..."
  if [ -f "$FILE" ]; then
    SIZE=$(stat -f%z "$FILE")
    echo "  Size: $SIZE bytes"
    if [ "$SIZE" -gt $((100*1024*1024)) ]; then
      BASENAME=$(basename "$FILE")
      TAG=$(basename "$(dirname "$FILE")")
      echo "  Candidate for upload: $FILE (tag: $TAG, asset: $BASENAME)"
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY RUN] Would process $FILE ($SIZE bytes) with release tag '$TAG' and asset name '$BASENAME'"
        # Add to .gitignore if not already present
        if ! grep -qxF "$FILE" .gitignore; then
          echo "$FILE" >> .gitignore
          echo "[DRY RUN] Added $FILE to .gitignore"
        fi
      else
        echo "Processing $FILE ($SIZE bytes)"
        # Add to .gitignore if not already present
        if ! grep -qxF "$FILE" .gitignore; then
          echo "$FILE" >> .gitignore
          echo "Added $FILE to .gitignore"
        fi
        # Create release if it doesn't exist
        if ! gh release view "$TAG" >/dev/null 2>&1; then
          echo "Creating release $TAG..."
          gh release create "$TAG" -t "$TAG" -n "Auto-uploaded large files for $TAG"
        else
          echo "Release $TAG already exists."
        fi
        echo "Uploading $FILE to release $TAG..."
        gh release upload "$TAG" "$FILE" --clobber
      fi
    fi
  fi
done

# Process ignored files (already in .gitignore)
for FILE in $IGNORED_FILES; do
  echo "Checking ignored $FILE..."
  if [ -f "$FILE" ]; then
    SIZE=$(stat -f%z "$FILE")
    echo "  Size: $SIZE bytes"
    if [ "$SIZE" -gt $((100*1024*1024)) ]; then
      BASENAME=$(basename "$FILE")
      TAG=$(basename "$(dirname "$FILE")")
      echo "  Candidate for upload: $FILE (tag: $TAG, asset: $BASENAME)"
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "[DRY RUN] Would upload $FILE ($SIZE bytes) with release tag '$TAG' and asset name '$BASENAME'"
      else
        echo "Uploading $FILE ($SIZE bytes)"
        # Create release if it doesn't exist
        if ! gh release view "$TAG" >/dev/null 2>&1; then
          echo "Creating release $TAG..."
          gh release create "$TAG" -t "$TAG" -n "Auto-uploaded large files for $TAG"
        else
          echo "Release $TAG already exists."
        fi
        echo "Uploading $FILE to release $TAG..."
        gh release upload "$TAG" "$FILE" --clobber
      fi
    fi
  fi
done

echo "Done."
