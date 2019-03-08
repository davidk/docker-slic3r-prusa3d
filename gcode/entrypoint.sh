#!/bin/bash -l
# GitHub Actions Slic3r
# Convert .STL files to .gcode for use with 3D printers
#
# This file expects the following parameters:
# 
# entrypoint.sh [slic3r configuration] [relative_path_to_stl] [relative_path_to_stl]
#
# *** Where to get the parameters ***
#
# [slic3r configuration] - When slic3r is open (with preferred settings selected), go to File -> Export Config
# [relative_path_to_stl] - This is the path to the STL inside of your repository; ex: "kittens/large_cat_120mm.stl"
#
# GitHub Action variable required:
# GITHUB_TOKEN - Lets this action upload the generated gcode file using the GitHub API
#
# Optional environmental variables that can be provided:
# (untested) BRANCH - the branch to operate on for queries to the API (default: master)
#

if [[ -z "${BRANCH}" ]]; then
	BRANCH=master
fi

WORKDIR="/github/workspace"
SLICE_CFG=$1; shift
# TODO: export this to a known directory and upload it immediately instead of scanning
# for the file later..
# probably want to use mktemp -d as well?
for stl in "$@"; do
	TMPDIR="$(mktemp -d)"

	echo ">>> Generating STL for $stl ..."
	if ! sh -c "/Slic3r/slic3r-dist/slic3r \
		--no-gui \
		--load ${WORKDIR}/${SLICE_CFG} \
		--output-filename-format '{input_filename_base}_{layer_height}mm_{filament_type[0]}_{printer_model}.gcode_updated' \
		--output ${TMPDIR} ${WORKDIR}/${stl}"; then
		exit_code=$?
		echo "!!! Failure generating STL  - rc: ${exit_code} !!!"
		exit $exit_code
	fi

	GENERATED_GCODE="$(basename "$(find "$TMPDIR" -name '*.gcode_updated')")"
	DEST_GCODE_FILE="${GENERATED_GCODE%.gcode_updated}.gcode"

	# Get path, including any subdirectories that the STL might belong in
	# but exclude the WORKDIR
	STL_DIR="$(dirname "${WORKDIR}/${stl}")"
	GCODE_DIR="${STL_DIR#"$WORKDIR"}"

	GCODE="${GCODE_DIR}/${DEST_GCODE_FILE}"
	GCODE="${GCODE#/}"

	echo
	echo ">>> Processing file as ${GCODE}"

	if [[ -e "${WORKDIR}/${GCODE}" ]]; then
		echo
		echo ">>> Replacing file in ${GCODE}"
		echo
		# This is a GraphQL call to avoid downloading the generated .gcode files (which may 403 when the file is too large)
		# Syntax used below:
		# ${GITHUB_REPOSITORY%/*} -- capture the username before the '/'
		# ${GITHUB_REPOSITORY#*/} -- capture the repository name after the '/'
		# ${GCODE#./}			  -- remove the './' prefix in front of paths if it exists
	if ! SHA="$({
	curl -f -sSL \
		-H "Authorization: bearer ${GITHUB_TOKEN}" \
		-H "User-Agent: github.com/davidk/docker-slic3r-prusa3d" \
		"https://api.github.com/graphql" \
		-d @- <<-EOF
		{
		"query": "query {repository(owner: \"${GITHUB_REPOSITORY%/*}\", name: \"${GITHUB_REPOSITORY#*/}\") {object(expression: \"${BRANCH}:${GCODE#./}\"){ ... on Blob { oid } }}}"
		}
EOF
		} | jq -r '.data | .repository | .object | .oid')"; then
			exit_code=$?
			echo "!!! Failed to get SHA from the GitHub GraphQL API - rc: ${exit_code} !!!"
			exit $exit_code
		fi

		echo ">>> SHA of previous file: ${SHA}, rc: $?"
		echo
	else
		SHA=""
	fi

	if [[ "${SHA}" != "null" ]]; then
		if ! curl -f -sSL \
		-X PUT "https://api.github.com/repos/${GITHUB_REPOSITORY}/contents/${GCODE}?ref=${BRANCH}" \
		-H "Accept: application/vnd.github.v3+json" \
		-H "Authorization: token ${GITHUB_TOKEN}" \
		-H "User-Agent: github.com/davidk/docker-slic3r-prusa3d" \
		-d @- <<-EOF
		{
		  "message": "Slic3r: updating ${GCODE}",
		  "committer": {
		    "name": "${GITHUB_ACTOR}",
		    "email": "${GITHUB_ACTOR}@example.com"
		  },
		  "content": "$(base64 < "${TMPDIR}/${GENERATED_GCODE}")",
		  "sha": "${SHA}"
		}
EOF
		then
			exit_code=$?
			echo "!!! Couldn't update ${GCODE} with SHA ${SHA} using the GitHub API - rc: ${exit_code} !!!"
			exit $exit_code
		fi
	else
		echo
		echo ">>> Committing new file ${GCODE}"
		echo
		if ! curl -f -sSL \
		-X PUT "https://api.github.com/repos/${GITHUB_REPOSITORY}/contents/${GCODE}?ref=${BRANCH}" \
		-H "Accept: application/vnd.github.v3+json" \
		-H "Authorization: token ${GITHUB_TOKEN}" \
		-H "User-Agent: github.com/davidk/docker-slic3r-prusa3d" \
		-d @- <<-EOF
		{
		  "message": "Slic3r: adding ${GCODE}",
		  "committer": {
		    "name": "${GITHUB_ACTOR}",
		    "email": "${GITHUB_ACTOR}@example.com"
		  },
		  "content": "$(base64 < "${TMPDIR}/${GENERATED_GCODE}")"
		}
EOF
		then
			exit_code=$?
			echo "!!! Unable to upload ${GCODE} using the GitHub API - rc: ${exit_code} !!!"
			exit $exit_code
		fi
	fi

	echo
	echo ">>> Finished processing file"
	echo

	echo ">>> Successfully generated STL for ${stl} ..."
	rm -rf "${TMPDIR}"
done

# Upload generated gcode files using secret ${GITHUB_TOKEN}, if "sha" is defined, this updates the 
# file instead. This should only affect .gcode_updated files created by the previous slicer pass.
