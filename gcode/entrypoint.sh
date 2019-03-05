#!/bin/sh -l

set -eu

#WORKDIR="/Slic3r/3d"
WORKDIR="/github/workspace"
SLICE_CFG=$1; shift

git config --global user.email "$GH_EMAIL"
git config --global user.name "$GH_USER"

for stl in "$@"; do
	echo "Generating STL for $stl ..."
	if sh -c "/Slic3r/slic3r-dist/slic3r --load ${WORKDIR}/${SLICE_CFG} --save ${WORKDIR}/${SLICE_CFG} --slice ${WORKDIR}/${stl}"; then
		echo "Successfully generated STL for ${stl} ..."

		git add . --force
		git commit -m "slic3r: Generated gcode for ${stl} using ${SLICE_CFG}"
		git push --set-upstream origin master
		
	else
		exit_code=$?
		echo "Failure generating STL, exited with ${exit_code}"
		exit $exit_code
	fi
done

