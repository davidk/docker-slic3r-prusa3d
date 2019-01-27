#!/bin/bash
# Place this in your $PATH and chmod +x so you can run it like a regular program
# Change paths, etc as appropriate

docker run -v /tmp/.X11-unix:/tmp/.X11-unix \
-v "$PWD":/Slic3r/3d \
-v slic3rSettings:/home/slic3r \
-e DISPLAY="$DISPLAY" \
--rm keyglitch/docker-slic3r-prusa3d

# For debugging -- had something blow up inside the persisted settings volume and don't want to nuke it?
#docker run -v /tmp/.X11-unix:/tmp/.X11-unix \
#-v $PWD:/Slic3r/3d:z \
#-v slic3rSettings:/home/slic3r \
#-e DISPLAY=$DISPLAY \
#--entrypoint=/bin/bash \
#-it keyglitch/docker-slic3r-prusa3d 
