#!/bin/bash
# Check a GitHub repository for new releases and trigger a Docker Hub autobuild.
# This is an attempt at a pure API implementation instead of using a GitHub 
# repository + pushed tags to trigger automated builds on the Docker Hub.
#
# Software Requirements / Dependencies:
# - jq
# 

set -eu

# Set these in your own environment
#DOCKER_HUB_PASS=""
#DOCKER_HUB_REPO_TRIGGER_TOKEN=""

# Customize for your own targeted repositories
DOCKER_HUB_USER="keyglitch"
DOCKER_HUB_REPO="docker-slic3r-prusa3d"
GH_RELEASE="https://api.github.com/repos/prusa3d/slic3r/releases/latest"

GH_VERSION=""
HUB_VERSIONS=""

checkGitHubRelease() {
	# This particular regular expression targets Prusa3d's version preferences,
	# change it as needed for different purposes/targets
	GH_VERSION="$(curl -SsL ${GH_RELEASE} | jq -r '.tag_name | select(test("^version_[0-9]{1,2}\\.[0-9]{1,2}\\.[0-9]{1,2}\\-{0,1}(\\w+){0,1}$"))' | cut -d_ -f2)"

	if [[ -z "${GH_VERSION}" ]]; then
		echo "Data garbled?"
		echo "Resulting output: ${GH_VERSION}"
		exit 1
	fi
}

checkHubVersion() {
	HUB_TOKEN=$(curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'${DOCKER_HUB_USER}'", "password": "'${DOCKER_HUB_PASS}'"}' https://hub.docker.com/v2/users/login/ | jq -r .token)
	
	if [[ -z "${HUB_TOKEN}" ]]; then
		echo "Hub token empty? Response was: ${HUB_TOKEN}"
	fi

	HUB_VERSIONS=$(curl -s -H "Authorization: JWT ${HUB_TOKEN}" https://hub.docker.com/v2/repositories/${DOCKER_HUB_USER}/${DOCKER_HUB_REPO}/tags/?page_size=100 | jq -r '.results|.[]|.name')
}

# arguments:
# 1: tag name
triggerDockerBuild() {
	echo "Building ${1}"
 	curl -H "Content-Type: application/json" --data "{\"source_type\": \"Tag\", \"source_name\": \"${1}\"}" -X POST "https://registry.hub.docker.com/u/${DOCKER_HUB_USER}/${DOCKER_HUB_REPO}/trigger/${DOCKER_HUB_REPO_TRIGGER_TOKEN}/"
}

checkGitHubRelease

echo "Latest of watched repository ${GH_RELEASE} is ${GH_VERSION}"

checkHubVersion

BUILT=""
for version in ${HUB_VERSIONS}; do
	if [[ "${GH_VERSION}" == "${version}" ]]; then
		echo "${version} has been previously built on the Docker Hub."
		BUILT="yes"
	fi
done

if [[ "${BUILT}" != "yes" ]]; then
	echo "${GH_VERSION} not found in the first 100 results. Triggering a build."
	triggerDockerBuild "${GH_VERSION}"
	echo
fi
