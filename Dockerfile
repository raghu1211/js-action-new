FROM ubuntu:20.04
MAINTAINER Mark Turney <markturney@gmail.com>


## Docker Environment

ENV DOCKER_USER jenkins
ENV DOCKER_HOME_DIR /home/${DOCKER_USER}
ENV DOCKER_ROOT_DIR ${DOCKER_HOME_DIR}/root

ENV DOCKER_BASHRC_DIR ${DOCKER_HOME_DIR}/.bashrc
ENV DOCKER_ENV_FILEPATH ${DOCKER_HOME_DIR}/environment.properties

ENV DOCKER_CCACHE_CACHE_DIR ${DOCKER_HOME_DIR}/ccache_cache

ENV DOCKER_NDDS_FILE_NAME rti_connext_dds-5.2.3_ubuntu1404.7z
ENV DOCKER_NDDS_LIB_DIR_NAME x64Linux3gcc4.8.2

# Don't warn that a GUI is not available during installation.
ENV DEBIAN_FRONTEND noninteractive


## SETUP USER

# Add the user to the image and set the password (you may want to alter this).
RUN adduser --quiet ${DOCKER_USER} \
    && echo "${DOCKER_USER}:${DOCKER_USER}" | chpasswd


## INSTALL PACKAGES

## Add bash

RUN apt-get update && apt-get install -y bash


# Add development tools
RUN apt-get update
RUN apt-get install -y apt-utils git ntp nano python2 python3 python3-pip python3-jinja2 python3-psycopg2 python3-sortedcontainers \
    perl p7zip-full ncftp gcc g++ clang clang-tools cmake ccache make ninja-build swig doxygen graphviz cppcheck patchelf \
    chrpath llvm curl cloc openssh-server valgrind time



# Install JDK 8 (latest edition)
RUN apt-get install -y openjdk-8-jdk maven ant

# MISSING: libgfortran3 python-libxml2

# Add development libraries.
RUN apt-get install -y libx11-dev libglu1-mesa-dev libgfortran-8-dev libxrender1 libpcap0.8-dev libbz2-dev \
                       zlib1g-dev libcurl4-gnutls-dev python2-dev libfreetype6-dev libpng-dev "^libxcb.*" \
                       libpci-dev p7zip-full g++-multilib libxmlrpc-c++8-dev python3-libxml2 libpcre16-3 libusb-1.0-0-dev

# Add bundle creation libraries.
RUN apt-get install -y libasound2-dev libfontconfig1-dev libltdl-dev libxext-dev python-numpy python-setuptools \
                       autoconf libxfixes-dev libxi-dev libxrender-dev libx11-xcb-dev flex bison gperf libicu-dev \
                       libxslt-dev ruby chrpath libsqlite3-dev unixodbc-dev postgresql-client libpq-dev

# Add packages for GUI support.
RUN apt-get -y install x11-apps x11-xserver-utils libxkbcommon-dev libxcb-xkb-dev libxslt1-dev libgstreamer-plugins-base1.0-dev mesa-common-dev mesa-utils

# Install newest CMake
RUN mkdir -p ${DOCKER_HOME_DIR}/cmake && \
        cd ${DOCKER_HOME_DIR} \
        && wget -qO- "http://outgoing.energid.info/docker/packages/cmake-3.22.3-linux-x86_64.tar.gz" | tar --strip-components=1 -xz -C cmake \
        && chown -R ${DOCKER_USER}:${DOCKER_USER} ${DOCKER_HOME_DIR}/cmake

#ENV CMAKE_BIN_DIR=${DOCKER_HOME_DIR}/cmake/bin
#RUN ln -s ${CMAKE_BIN_DIR}/cmake /usr/bin/cmake \
#    && ln -s ${CMAKE_BIN_DIR}/cpack /usr/bin/cpack \
#    && ln -s ${CMAKE_BIN_DIR}/ctest /usr/bin/ctest \
#    && ln -s ${CMAKE_BIN_DIR}/ccmake /usr/bin/ccmake \
#    && ln -s ${CMAKE_BIN_DIR}/cmake-gui /usr/bin/cmake-gui

# Pip2 on 20.04
RUN curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py \
    && python2 get-pip.py

# Add required Python libs.
RUN pip2 install --upgrade "pip < 21.0" \
    && pip2 install six \
    && pip2 install ftptool \
    && pip2 install doxyqml==0.3.0 \
    && pip2 install setuptools \
    && pip2 install paramiko \
    && pip2 install gcovr \
    && pip2 install psycopg2-binary



## CONFIGURE PACKAGES

# Add development softlinks.
RUN ln -s /usr/bin/swig3.0 /usr/local/bin/swig \
    && ln -s /usr/include/freetype2/ft2build.h /usr/include/ft2build.h \
    && ln -s /usr/include/freetype2/freetype /usr/include/freetype

# Configure a basic SSH server - only allow Pubkey authentication.
#RUN sed -i 's|#PasswordAuthentication yes|PasswordAuthentication no|g' /etc/ssh/sshd_config \
#    && sed -i 's|#PubkeyAuthentication yes|PubkeyAuthentication yes|g' /etc/ssh/sshd_config \
#    && sed -i 's|UsePAM yes|UsePAM no|g' /etc/ssh/sshd_config \
#    && mkdir -p /var/run/sshd


## SETUP ENVIRONMENT

RUN echo "PROMPT_COMMAND='history -a'" > ${DOCKER_ENV_FILEPATH} \
    && echo "DISPLAY=:0" >> ${DOCKER_ENV_FILEPATH} \
    && echo "LC_ALL=C" >> ${DOCKER_ENV_FILEPATH} \
    && echo "PATH=/usr/lib/ccache:${DOCKER_HOME_DIR}/bin:${DOCKER_HOME_DIR}/cmake/bin:${DOCKER_HOME_DIR}/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" >> ${DOCKER_ENV_FILEPATH} \
    && echo "CCACHE_PATH=/usr/bin" >> ${DOCKER_ENV_FILEPATH} \
    && echo "CCACHE_DIR=$DOCKER_CCACHE_CACHE_DIR" >> ${DOCKER_ENV_FILEPATH} \
    && echo "CCACHE_MAXFILES=0" >> ${DOCKER_ENV_FILEPATH} \
    && echo "CCACHE_MAXSIZE=40G" >> ${DOCKER_ENV_FILEPATH} \
    && chown ${DOCKER_USER}:${DOCKER_USER} ${DOCKER_ENV_FILEPATH}

## UPDATE BASHRC

RUN echo "# Load properties into environment variables." >> ${DOCKER_BASHRC_DIR} \
    && echo "eval \$(cat ${DOCKER_ENV_FILEPATH} | sed 's/^/export /')" >> ${DOCKER_BASHRC_DIR} \
    && echo "# Aliases" >> ${DOCKER_BASHRC_DIR} \
    && echo "alias gls='git status'" >> ${DOCKER_BASHRC_DIR} \
    && echo "alias sizeof='du -hs'" >> ${DOCKER_BASHRC_DIR} \
    && echo "alias remaining='df -k'" >> ${DOCKER_BASHRC_DIR} \
    && echo "alias erase='rm -rf ./*'" >> ${DOCKER_BASHRC_DIR} \
    && echo "alias ntargets='ninja -t targets all'" >> ${DOCKER_BASHRC_DIR}


## NDDS SETUP

# NDDS license
RUN mkdir -p ${DOCKER_HOME_DIR}/licenses \
    && wget http://outgoing.energid.info/docker/packages/ndds/licenses/2019/rti_license.dat -P ${DOCKER_HOME_DIR}/licenses \
    && chown -R ${DOCKER_USER}:${DOCKER_USER} ${DOCKER_HOME_DIR}/licenses

# NDDS binaries
RUN wget http://outgoing.energid.info/ndds/${DOCKER_NDDS_FILE_NAME} -P ${DOCKER_HOME_DIR} \
    && 7z x ${DOCKER_HOME_DIR}/${DOCKER_NDDS_FILE_NAME} -o${DOCKER_HOME_DIR} \
    && chown -R ${DOCKER_USER}:${DOCKER_USER} ${DOCKER_HOME_DIR}/rti_connext_dds-5.2.3 \
    && rm ${DOCKER_HOME_DIR}/${DOCKER_NDDS_FILE_NAME}

# NDDS environment
RUN echo "RTI_LICENSE_FILE=${DOCKER_HOME_DIR}/licenses/rti_license.dat" >> ${DOCKER_ENV_FILEPATH} \
    && echo "LD_LIBRARY_PATH=${DOCKER_HOME_DIR}/rti_connext_dds-5.2.3/lib/${DOCKER_NDDS_LIB_DIR_NAME}" >> ${DOCKER_ENV_FILEPATH} \
    && chown ${DOCKER_USER}:${DOCKER_USER} ${DOCKER_ENV_FILEPATH}


# Acontis Ethercat Setup
ENV DOCKER_ACONTIS_FILE_NAME=EC-Master-V3.1.0.16-Linux-x86_64Bit-Protected.zip
RUN cd ${DOCKER_HOME_DIR} \
    && wget http://outgoing.energid.info/docker/packages/acontis/${DOCKER_ACONTIS_FILE_NAME} -P ${DOCKER_HOME_DIR} \
    && unzip ${DOCKER_HOME_DIR}/${DOCKER_ACONTIS_FILE_NAME} \
    && chown -R ${DOCKER_USER}:${DOCKER_USER} ${DOCKER_HOME_DIR}/EC-Master-V3.1.0.16-Linux-x86_64Bit-Protected \
    && rm ${DOCKER_HOME_DIR}/${DOCKER_ACONTIS_FILE_NAME}


## JENKINS SETUP - DELETE SOON

# Create softlink for old config.cmake files across projects.
RUN mkdir -p /home/energid/third_party \
    && ln -s ${DOCKER_HOME_DIR}/rti_connext_dds-5.2.3 /home/energid/third_party/rti_connext_dds-5.2.3 \
    && ln -s ${DOCKER_HOME_DIR}/licenses /home/energid/licenses \
    && chown -R ${DOCKER_USER}:${DOCKER_USER} /home/energid/third_party


## SUDO SETUP - KEEP THIS SECTION DISABLED EXCEPT FOR TEMPORARY WORKAROUNDS

RUN apt-get -y install sudo \
    && adduser jenkins sudo


# For changing rt priority (Tyler)
RUN echo 'jenkins hard rtprio 10' >> /etc/security/limits.conf
RUN echo 'jenkins soft rtprio 10' >> /etc/security/limits.conf

# 
RUN apt-get update && apt-get install -y libglfw3-dev libgles2-mesa-dev \
	mesa-utils libgbm-dev mtdev-tools libmtdev-dev libpulse-dev


# Installing all Qt5 building deps: https://wiki.qt.io/Building_Qt_5_from_Git
RUN cp /etc/apt/sources.list /etc/apt/sources.list~ \
    && sed -Ei 's/^# deb-src /deb-src /' /etc/apt/sources.list \
    && apt-get update

RUN apt-get -y build-dep qt5-default \
    &&  apt-get install -y libxcb-xinerama0-dev

RUN apt-get -y install libeigen3-dev libopencv-dev libopenscenegraph-dev qtbase5-private-dev \
    qtdeclarative5-dev qtdeclarative5-private-dev qttools5-dev qtmultimedia5-dev \
    qml-module-qt-labs-platform libqhull-dev libqwt-qt5-dev libprotobuf-dev protobuf-compiler \
    qtdeclarative5-dev-tools qml-module-qtquick2 qml-module-qttest libqt5svg5-dev libnlopt0 \
    qml-module-qtquick-dialogs qml-module-qt-labs-folderlistmodel qml-module-qtquick-controls2 \
    qtquickcontrols2-5-dev

RUN apt-get install -y libnlopt-dev

RUN apt-get install -y libtomcrypt-dev libtommath-dev clang-format abigail-tools

RUN apt-get install -y vim tmux bash-completion aptitude

RUN apt-get install -y --no-install-recommends xvfb xauth x11vnc

RUN apt-get install -y python-libxml2 libproj-dev

RUN ln -s /usr/bin/python2 /usr/bin/python

# Configure a basic SSH server - only allow Pubkey authentication.
RUN sed -i 's|#PasswordAuthentication yes|PasswordAuthentication no|g' /etc/ssh/sshd_config \
    && sed -i 's|#PubkeyAuthentication yes|PubkeyAuthentication yes|g' /etc/ssh/sshd_config \
    && sed -i 's|UsePAM yes|UsePAM no|g' /etc/ssh/sshd_config \
    && mkdir -p /var/run/sshd

# Download and install the latest wkhtmltopdf - for converting HTML release notes to PDF.
# xfonts-75dpi is a required dependency
ENV WKHTML_DEB=wkhtmltox_0.12.6-1.focal_amd64.deb
RUN apt-get install xfonts-75dpi \
    && wget https://outgoing.energid.info/docker/packages/${WKHTML_DEB} \
    && dpkg -i ${WKHTML_DEB} \
    && rm ${WKHTML_DEB}

RUN pip3 install jinja2 markdown python-gitlab markdown pdfkit paramiko colorlog~=5.0.1 \
    environs~=9.3.2 titlecase matplotlib PyGithub pandas grafana_api python-jenkins~=1.7.0 \
    O365~=2.0.18.1 gspread~=5.3.2 google-api-python-client~=2.45.0 google-auth-httplib2~=0.1.0 \
    google-auth-oauthlib~=0.5.1 oauth2client~=4.1.3

# Make sure we are using the correct default java
RUN rm -f /usr/lib/jvm/default-java && \
    ln -s /usr/lib/jvm/java-1.8.0-openjdk-amd64 /usr/lib/jvm/default-java

RUN dpkg --add-architecture i386 \
    && apt-get update \
    && apt-get install -y libboost-container-dev:i386

## SYSTEM COMPLETION

# Standard SSH port
EXPOSE 22

# Create the root directory
RUN mkdir ${DOCKER_ROOT_DIR} && chown ${DOCKER_USER}:${DOCKER_USER} ${DOCKER_ROOT_DIR}
RUN mkdir ${DOCKER_CCACHE_CACHE_DIR} && chown ${DOCKER_USER}:${DOCKER_USER} ${DOCKER_CCACHE_CACHE_DIR}
