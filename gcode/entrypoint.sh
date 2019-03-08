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

WORKDIR="/github/workspace"

# Create a lock but wait if it is already held. 
# This and the retry system help to work around inconsistent repository operations.
# Derived from the flock(2) manual page.
echo "Launched at: $(date +%H:%M:%S:%N)"
(
flock 9 
echo "Unblocked and running at: $(date +%H:%M:%S:%N)"

if [[ -z "${BRANCH}" ]]; then
	BRANCH=master
fi

if [[ -z $UPDATE_RETRY ]]; then
	UPDATE_RETRY=5
fi

SLICE_CFG=$1; shift

# TODO: export this to a known directory and upload it immediately instead of scanning
# for the file later..
# probably want to use mktemp -d as well?

echo -e "\n>>> Processing STLs $* with ${SLICE_CFG}\n"

for stl in "$@"; do
	mkdir -p "${WORKDIR}/${TMPDIR}"
	TMPDIR="$(mktemp -d)"

	echo -e "\n>>> Generating STL for $stl ...\n"
	if /Slic3r/slic3r-dist/slic3r \
		--no-gui \
		--load "${WORKDIR}/${SLICE_CFG}" \
		--output-filename-format '{input_filename_base}_{layer_height}mm_{filament_type[0]}_{printer_model}.gcode_updated' \
		--output "${TMPDIR}" "${WORKDIR}/${stl}"; then
		echo -e "\n>>> Successfully generated gcode for STL\n"
	else
		exit_code=$?
		echo -e "\n!!! Failure generating STL  - rc: ${exit_code} !!!\n"
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

	echo -e "\n>>> Processing file as ${GCODE}\n"

	if [[ -e "${WORKDIR}/${GCODE}" ]]; then
		echo -e "\n>>> Updating existing file in ${WORKDIR}/${GCODE}\n"
		# This is a GraphQL call to avoid downloading the generated .gcode files (which may 403 when the file is too large)
		# Syntax used below:
		# ${GITHUB_REPOSITORY%/*} -- capture the username before the '/'
		# ${GITHUB_REPOSITORY#*/} -- capture the repository name after the '/'
		# ${GCODE#./}			  -- remove the './' prefix in front of paths if it exists

		while true; do

			if SHA="$({
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
					echo -e "\n>>> Successfully retrieved sha:${SHA} from GitHub GraphQL API\n"
			else
				exit_code=$?

				echo -e "\n!!! Failed to get SHA from the GitHub GraphQL API - rc: ${exit_code} !!!\n"

				SHA=""

				echo -e "\n!!! Retry attempts: ${UPDATE_RETRY} !!!\n"

				if [[ ${UPDATE_RETRY} -le 0 ]]; then
					echo -e "!!! Ran out of retry attempts."
					exit $exit_code
				fi

			fi

			if [[ "${SHA}" == "null" ]]; then
				echo -e "\n>>> New file\n"
				break
			fi

			if curl -f -sSL \
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
				echo -e "\n>>> Successfully updated ${GCODE} using the GitHub API\n"
				break
			else
				exit_code=$?
				echo "!!! Couldn't update ${GCODE} with SHA ${SHA} using the GitHub API - rc: ${exit_code} !!!"
				echo "!!! Possible reasons for this error !!!"
				echo "!!! * GitHub API is down (see the return code) !!!"
				echo "!!! * Two actions are trying to update the repository at the same time (409 conflict) !!!"
				echo "!!! Workaround: Make actions depend on each other with the 'needs' keyword            !!!"
				echo "!!! Retry attempts: ${UPDATE_RETRY} !!!"

				if [[ ${UPDATE_RETRY} -le 0 ]]; then
					echo -e "!!! Ran out of retry attempts."
					exit $exit_code
				fi
			fi

			if [[ ${UPDATE_RETRY} -gt 0 ]]; then
				sleep ${UPDATE_RETRY}
				echo -e "!!! Retrying due to errors. !!!"
			fi

			((UPDATE_RETRY--))
		done
	else

		echo -e "\n>>> Committing new file ${GCODE}\n"

		if curl -f -sSL \
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
			echo -e "\n>>> Successfully added a new file (${GCODE}) using the GitHub API\n"
		else
			exit_code=$?
			echo -e "!!! Unable to upload ${GCODE} using the GitHub API - rc: ${exit_code} !!!"
			exit $exit_code
		fi
	fi

	echo -e "\n>>> Finished processing file\n"

	rm -rf "${TMPDIR}"
done
) 9>"$WORKDIR/slice.lock"

echo "Completed at: $(date +%H:%M:%S:%N)"