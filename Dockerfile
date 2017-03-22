# DESCRIPTION:  Slic3r Prusa3D edition in a Docker container
# AUTHOR:        davidk
# COMMENTS:      This Dockerfile wraps Prusa3D's fork of Slic3r into a Docker container.
#                Tested on Fedora 25.
#                Derived from Jess Frazelle's Atom Dockerfile: https://raw.githubusercontent.com/jessfraz/dockerfiles/master/atom/Dockerfile
#
# USAGE:
#               # Build image
#               docker build -t slic3r .
#
#               # Run it!
#               docker run -v /tmp/.X11-unix:/tmp/.X11-unix -v $PWD:/Slic3r/3d:z -v slic3rSettings:/home/slic3r -e DISPLAY=$DISPLAY --rm keyglitch/docker-slic3r-prusa3d
#
#		# If this fails, it might either be SELinux or
#               # just needing to allow access to your local X session
#               xhost local:root
#
# VOLUME MANAGEMENT:
#
#                     # Remove and wipe settings
#                     docker volume rm slic3rSettings
#
#                     # Information about where stuff is
#                     docker volume inspect slic3rSettings

FROM debian:stretch

RUN apt-get update && apt-get install -y \
  freeglut3 \
  libgtk2.0-dev \
  libwxgtk3.0-dev \
  libwx-perl \
  libxmu-dev \
  libgl1-mesa-glx \
  libgl1-mesa-dri \
  xdg-utils \
  --no-install-recommends \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get autoremove -y \
  && apt-get autoclean

RUN groupadd -r slic3r \
  && useradd -r -g slic3r slic3r \
  && mkdir -p /Slic3r \
  && chown slic3r:slic3r /Slic3r \
  && mkdir /home/slic3r \
  && chown slic3r:slic3r /home/slic3r

WORKDIR /Slic3r

# curl opts: -s = slient, -S = show errors, -L = follow redirects
RUN apt-get update && apt-get install -y \
  curl \
  ca-certificates \
  unzip \
  bzip2 \
  --no-install-recommends \
  && curl -sSL https://github.com/prusa3d/Slic3r/releases/download/version_1.33.8/Slic3r-1.33.8-prusa3d-linux64-full-201702210906.tar.bz2 > /Slic3r/Slic3r-1.33.8-prusa3d-linux64-full-201702210906.tar.bz2 \
  && curl -sSL https://github.com/prusa3d/Slic3r-settings/archive/master.zip > /Slic3r/slic3r-settings.zip \
  && tar -xjf Slic3r-1.33.8-prusa3d-linux64-full-201702210906.tar.bz2 \
  && unzip -q slic3r-settings.zip \
  && mkdir -p /home/slic3r/.Slic3r/ \
  && cp -a /Slic3r/Slic3r-settings-master/Slic3r\ settings\ MK2/* /home/slic3r/.Slic3r/ \
  && rm -f /Slic3r/Slic3r-1.33.8-prusa3d-linux64-full-201702210906.tar.bz2 \
  && rm -f /Slic3r/slic3r-settings.zip \
  && rm -rf /var/lib/apt/lists/* \
  && apt-get purge -y --auto-remove curl ca-certificates unzip bzip2 \
  && apt-get autoclean \
  && chown -R slic3r:slic3r /Slic3r /home/slic3r

USER slic3r

RUN mkdir -p /home/slic3r/.local/share/

VOLUME /home/slic3r/

ENTRYPOINT [ "/Slic3r/Slic3r-1.33.8-prusa3d-linux64-full-201702210906/slic3r", "--gui" ]
