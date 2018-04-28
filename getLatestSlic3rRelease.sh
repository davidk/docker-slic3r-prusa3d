#!/bin/bash
# Get the latest release of Prusa3D's slic3r for Linux (non-AppImage) via the GitHub API

set -eu

if [[ $# -lt 1 ]]; then

  exit 1

fi

baseDir="/Slic3r"
mkdir -p $baseDir

if [[ ! -e "$baseDir/latestReleaseInfo.json" ]]; then

  curl -SsL https://api.github.com/repos/prusa3d/slic3r/releases/latest > $baseDir/latestReleaseInfo.json

fi

releaseInfo=$(cat $baseDir/latestReleaseInfo.json)

if [[ $# -gt 1 ]]; then

  VER=$2

  if [[ ! -e "$baseDir/releases.json" ]]; then
    curl -SsL https://api.github.com/repos/prusa3d/slic3r/releases > $baseDir/releases.json
  fi

  allReleases=$(cat $baseDir/releases.json)

fi

if [[ "$1" == "url" ]]; then

  echo "$(echo ${releaseInfo} | jq -r '.assets[] | .browser_download_url | select(test("Slic3rPE-.+(-\\w)?.linux64-full.+.tar.bz2"))')"

elif [[ "$1" == "name" ]]; then

  echo "$(echo ${releaseInfo} | jq -r '.assets[] | .name | select(test("Slic3rPE-.+(-\\w)?.linux64-full.+.tar.bz2"))')"

elif [[ "$1" == "url_ver" ]]; then

  echo $(echo ${allReleases} | jq -r ".[] | .assets[] | .browser_download_url | select(test(\"Slic3rPE-$VER(-\\w)?.linux64-full.+.tar.bz2\"))")

elif [[ "$1" == "name_ver" ]]; then

  echo $(echo ${allReleases} | jq -r ".[] | .assets[] | .name | select(test(\"Slic3rPE-$VER(-\\w)?.linux64-full.+.tar.bz2\"))")

fi
