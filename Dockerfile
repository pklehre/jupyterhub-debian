# An incomplete base Docker image for running JupyterHub
#
# Add your configuration to create a complete derivative Docker image.
#
# Include your configuration settings by starting with one of two options:
#
# Option 1:
#
# FROM jupyterhub/jupyterhub:latest
#
# And put your configuration file jupyterhub_config.py in /srv/jupyterhub/jupyterhub_config.py.
#
# Option 2:
#
# Or you can create your jupyterhub config and database on the host machine, and mount it with:
#
# docker run -v $PWD:/srv/jupyterhub -t jupyterhub/jupyterhub
#
# NOTE
# If you base on jupyterhub/jupyterhub-onbuild
# your jupyterhub_config.py will be added automatically
# from your docker directory.

ARG BASE_IMAGE=debian:bookworm
#ARG BASE_IMAGE=ocaml/opam:debian-ocaml-5.2-flambda
FROM $BASE_IMAGE AS builder

USER root

ENV DEBIAN_FRONTEND noninteractive

#RUN mv -i /etc/apt/trusted.gpg.d/debian-archive-*.asc  /root/
#RUN ln -s /usr/share/keyrings/debian-archive-* /etc/apt/trusted.gpg.d/

RUN apt-get update && \
    apt-get install -y --allow-unauthenticated debian-archive-keyring

RUN apt-get update \
 && apt-get install -yq --no-install-recommends \
    gnupg \
    debian-archive-keyring \
    build-essential \
    ca-certificates \
    locales \
    python3-dev \
    python3-pycurl \
    nodejs \
    npm \
    yarnpkg \
    curl \
 # Pass the flag to the get-pip.py script itself
 && curl -sS https://bootstrap.pypa.io/get-pip.py | python3 - --break-system-packages \
 # The pip install command still needs the flag as well
 && pip3 install --no-cache --upgrade --break-system-packages setuptools pip \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

RUN pip3 install --break-system-packages --upgrade setuptools wheel

# copy everything except whats in .dockerignore, its a
# compromise between needing to rebuild and maintaining
# what needs to be part of the build
COPY . /src/jupyterhub/
WORKDIR /src/jupyterhub

# Build client component packages (they will be copied into ./share and
# packaged with the built wheel.)
RUN python3 setup.py bdist_wheel
RUN python3 -m pip wheel --wheel-dir wheelhouse dist/*.whl


FROM $BASE_IMAGE

USER root

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -yq --no-install-recommends \
    build-essential \
    python3-dev \
    ca-certificates \
    curl \
    gnupg \
    locales \
    python3 \
    python3-pycurl \
    nodejs \
    npm \
 # Pass the flag to the get-pip.py script itself
 && curl -sS https://bootstrap.pypa.io/get-pip.py | python3 - --break-system-packages \
 # The pip install command still needs the flag as well
 && pip3 install --no-cache --upgrade --break-system-packages setuptools pip \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

ENV SHELL=/bin/bash \
    LC_ALL=en_GB.UTF-8 \
    LANG=en_GB.UTF-8 \
    LANGUAGE=en_GB.UTF-8

RUN  locale-gen $LC_ALL


RUN npm install -g configurable-http-proxy@^4.2.0 \
 && rm -rf ~/.npm

# install the wheels we built in the first stage
COPY --from=builder /src/jupyterhub/wheelhouse /tmp/wheelhouse
RUN pip3 install --break-system-packages --no-cache /tmp/wheelhouse/*

RUN mkdir -p /srv/jupyterhub/
WORKDIR /srv/jupyterhub/

COPY jupyterhub_config.py /srv/jupyterhub/

# create user
RUN useradd -ms /bin/bash labadmin
RUN echo "labadmin:test123" | chpasswd 

# install jupyterlab
RUN pip3 install --break-system-packages jupyterlab

EXPOSE 8000

LABEL maintainer="Jupyter Project <jupyter@googlegroups.com>"
LABEL org.jupyter.service="jupyterhub"

CMD ["jupyterhub"]
