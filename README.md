# docker-slic3r-prusa3d

Containerized Slic3r (Prusa3D version/fork) - Dockerfile and supporting script

The header of the Dockerfile has more documentation, but to grab and run this:

`docker run -v /tmp/.X11-unix:/tmp/.X11-unix -v $PWD:/Slic3r/3d:z -v slic3rSettings:/home/slic3r -e DISPLAY=$DISPLAY --rm keyglitch/docker-slic3r-prusa3d`

* Your current directory will be mounted into the container at /Slic3r/3d (change the :z option as appropriate to :rw/:ro). 

* Settings are persisted into the slic3rSettings volume.

* SELinux might block access to X by slic3r inside the container. Look in /var/log/messages or /var/log/audit/audit.log to see if this is happening (and for the relevant commands to fix).

* Alternatively, there might be a plain permission error upon trying to access X. Try running `xhost local:root` to fix (this is a temporary fix and must be reapplied when restarting the host).

Sample error example (it\'s pretty cryptic, sigh):

    No protocol specified
    19:13:54: Error: Unable to initialize GTK+, is DISPLAY set properly?
    Failed to initialize wxWidgets at /Slic3r/slic3r-dist/lib/site_perl/5.22.0/Slic3r/GUI/2DBed.pm line 10.
    Compilation failed in require at /Slic3r/slic3r-dist/lib/site_perl/5.22.0/Slic3r/GUI/2DBed.pm line 10.
    BEGIN failed--compilation aborted at /Slic3r/slic3r-dist/lib/site_perl/5.22.0/Slic3r/GUI/2DBed.pm line 10.
    Compilation failed in require at /Slic3r/slic3r-dist/lib/site_perl/5.22.0/Slic3r/GUI.pm line 9.
    BEGIN failed--compilation aborted at /Slic3r/slic3r-dist/lib/site_perl/5.22.0/Slic3r/GUI.pm line 9.
    Compilation failed in require at (eval 87) line 1.

