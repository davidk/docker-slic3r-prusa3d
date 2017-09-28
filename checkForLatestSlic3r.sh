#!/bin/bash
# getReleaseTags.sh
# Push a tag for our repository if an upstream repository generates a new release

set -eu

LATEST_RELEASE="https://api.github.com/repos/prusa3d/slic3r/releases/latest"

# Get the latest tagged version
LATEST_VERSION=$(curl -SsL ${LATEST_RELEASE} | jq -r '.tag_name | select(test("^version_[0-9]{1,2}+\\.[0-9]{1,2}+\\.[0-9]{1,2}+$"))' | tr -d 'version_')

if [[ -z "${LATEST_VERSION}" ]]; then
	echo "Data garbled?"
	echo "Resulting output: ${LATEST_VERSION}"
	exit 1
fi

# Run from the git repository
cd "$(dirname "$0")";

# Get the latest tag (by tag date, not commit) in our repository
LATEST_GIT_TAG=$(git for-each-ref refs/tags --sort=-creatordate --format='%(refname:short)' --count=1)
if [[ "${LATEST_GIT_TAG}" != "${LATEST_VERSION}" ]]; then
  echo "Update needed. Latest tag ver: ${LATEST_GIT_TAG} != upstream ver: ${LATEST_VERSION} .."
 git tag "${LATEST_VERSION}"
 git push --tags
else
  echo "Latest tag ver: ${LATEST_GIT_TAG} == upstream ver: ${LATEST_VERSION} -- no update"
fi
