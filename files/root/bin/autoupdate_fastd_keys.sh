#!/bin/bash
# Simple script to update fastd peers from git upstream
# and only send HUP to fastd when changes happend.

if [[ "$1" == "-v" ]]; then
  VERBOSE=1
fi

# CONFIGURE THIS TO YOUR PEER DIRECTORY
FASTD_PEERS=/etc/fastd/ffhh-mesh-vpn/peers

function getCurrentVersion() {
  # Get hash from latest revision
  git log --format=format:%H -1
}

cd $FASTD_PEERS

# Get current version hash
GIT_REVISION=$(getCurrentVersion)

# Automagically commit local changes
# This preserves local changes
git commit --quiet -m "CRON: auto commit" > /dev/null

# Pull latest changes from upstream
git fetch --quiet
git merge origin/master --quiet -m "Auto Merge"

# Get new version hash
GIT_NEW_REVISION=$(getCurrentVersion)

if [ $GIT_REVISION != $GIT_NEW_REVISION ]
then
  # Version has changed we need to update
  test -n "$VERBOSE" && echo "Reload fastd peers"
  kill -HUP $(pidof fastd)
fi

