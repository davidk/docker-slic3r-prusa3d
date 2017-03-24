#!/bin/bash
# Get the latest release of Prusa3D's slic3r for Linux (non-AppImage) via the GitHub API

set -eu

if [[ $# -lt 1 ]]; then

  exit 1
  
fi

mkdir -p /Slic3r

if [[ ! -e "/Slic3r/releaseInfo.json" ]]; then

  curl -SsL https://api.github.com/repos/prusa3d/slic3r/releases/latest > /Slic3r/releaseInfo.json

fi

releaseInfo=$(cat /Slic3r/releaseInfo.json)

if [[ "$1" == "url" ]]; then

  latestSlic3r="$(echo ${releaseInfo} | jq -r '.assets[] | .browser_download_url | select(test("Slic3r-.+prusa3d-linux64-full.+.tar.bz2"))')"

  echo $latestSlic3r

elif [[ "$1" == "name" ]]; then

  slic3rReleaseName="$(echo ${releaseInfo} | jq -r '.assets[] | .name | select(test("Slic3r-.+?prusa3d-linux64-full.+.tar.bz2"))')"

  echo $slic3rReleaseName

fi
