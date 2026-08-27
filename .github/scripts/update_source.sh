#!/bin/bash

set -euo pipefail

website_directory=${1:?Usage: update_source.sh WEBSITE_DIRECTORY RELEASE_VERSION}
release_version=${2:?Usage: update_source.sh WEBSITE_DIRECTORY RELEASE_VERSION}

cd "$website_directory"

git config user.name 'GitHub Action'
git config user.email 'action@github.com'

python3 updatesource.py index.json
git add index.json

if git diff --staged --quiet; then
    echo 'Website/index.json is already current.'
    exit 0
fi

git commit -m "chore: update StikDebug source for $release_version"
git push origin main
