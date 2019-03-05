#!/bin/bash -l
# GitHub Action variable required:
# GITHUB_TOKEN - Lets this action upload the generated gcode file using the GitHub API
#
# An additional variable is used, but this is provided by GitHub:
# GITHUB_ACTOR - The username / app that initiated the action
#
# Optional variables that can be provided:
# BRANCH - the branch to operate on for queries to the API (default: master)

if [ -z "${BRANCH}" ]; then
	BRANCH=master
fi

WORKDIR="/github/workspace"
SLICE_CFG=$1; shift

for stl in "$@"; do
	echo "Generating STL for $stl ..."
	#if sh -c "/Slic3r/slic3r-dist/slic3r --load ${WORKDIR}/${SLICE_CFG} --save ${WORKDIR}/${SLICE_CFG}.config --slice ${WORKDIR}/${stl}"; then
	if sh -c "/Slic3r/slic3r-dist/slic3r --no-gui --load ${WORKDIR}/${SLICE_CFG} --output $(dirname "$(readlink -f "${WORKDIR}/${stl}")") ${WORKDIR}/${stl}"; then

		echo "Successfully generated STL for ${stl} ..."		
	else
		exit_code=$?
		echo "Failure generating STL, exited with ${exit_code}"
		exit $exit_code
	fi
done

# https://developer.github.com/v3/repos/contents/#create-a-file
# PUT /repos/:owner/:repo/contents/:path/
# Upload all of our gcode files using GITHUB_TOKEN
while IFS= read -r -d '' gcode; do
	curl -sSL \
	-X PUT "https://api.github.com/repos/${GITHUB_REPOSITORY}/contents/${gcode}?ref=${BRANCH}" \
	-H "Accept: application/vnd.github.v3+json" \
	-H "Authorization: token ${GITHUB_TOKEN}" \
	-d @- <<EOF
{
  "message": "slic3r action: Adding generated gcode from ${gcode}",
  "committer": {
    "name": "${GITHUB_ACTOR}",
    "email": "${GITHUB_ACTOR}@example.com"
  },
  "content": "$(base64 < "${gcode}")",
  "sha": "$(curl -sSL \
		-H "Accept: application/vnd.github.v3+json" \
		-H "Authorization: token ${GITHUB_TOKEN}" \
		"https://api.github.com/repos/${GITHUB_REPOSITORY}/contents/${gcode}?ref=${BRANCH}" \
		| jq -r '.sha'
	)"
}
EOF
done < <(find ./ -name '*.gcode' -print0)
