#!/bin/bash
#
#  Copyright 2019 poplite <poplite.xyz@gmail.com>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#  
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#  MA 02110-1301, USA.
#

set -e

VERSION="1.4"

PROGRAM_NAME="libtorrent-rasterbar"
SCRIPT_NAME=$0

# Currently supported version
CURR_VERSION="1.2.10"

# Read version and distro name from argument
DEB_VERSION=$1
SUB_VERSION="1"
DISTRO=${2:-$(lsb_release -sc || true)} # ignore error
ARCH=$(dpkg --print-architecture)

# If set as 'no', do not run apt-get to install dependencies
INSTALL_DEPS=${INSTALL_DEPS:-"yes"}

# Maintainer information, needed by dch
export DEBFULLNAME="poplite"
export DEBEMAIL="poplite.xyz@gmail.com"

# Options for dch
DCH_OPT="--package ${PROGRAM_NAME} --distribution ${DISTRO} --force-distribution --force-bad-version"

# Check if running as root
if [[ $(id -u) != 0 ]];
then
    SUDO="sudo"
else
    SUDO=""
fi

DEBUILD_OPT="-uc -us -rfakeroot"

BUILD_DEPENDS="debhelper dh-python build-essential pkg-config devscripts fakeroot quilt curl tar"
DEPENDS="libboost-system-dev libboost-python-dev libboost-chrono-dev libboost-random-dev libssl-dev python-all-dev python-docutils python3-all-dev python3-docutils"

BUILD_DIR="${DEB_VERSION}-build"
SOURCE_DIR="${PROGRAM_NAME}-${DEB_VERSION}"
TARBALL_ORIG="${PROGRAM_NAME}_${DEB_VERSION}.orig.tar.gz"

BOLD_GREEN="\e[1;32m"
CLEAR_CLR="\e[0m"

echo_clr() {
    echo -e "${BOLD_GREEN}\n$1${CLEAR_CLR}"
}

usage() {
    echo -e "${BOLD_GREEN}makeDeb.sh for ${PROGRAM_NAME}${CLEAR_CLR}"
    echo -e "Usage: ${SCRIPT_NAME} version [distro]\n"
    echo -e "Options:"
    echo -e "  version    - Main version          (Recommended: ${BOLD_GREEN}${CURR_VERSION}${CLEAR_CLR})"
    echo -e "  distro     - Distribution codename (Default: ${BOLD_GREEN}${DISTRO}${CLEAR_CLR})"
}

print_info() {
    echo -e "Build version  :" "${BOLD_GREEN}${DEB_VERSION}-${SUB_VERSION}${CLEAR_CLR}"
    echo -e "Build distro   :" "${BOLD_GREEN}${DISTRO}${CLEAR_CLR}"
    echo -e "Build arch     :" "${BOLD_GREEN}${ARCH}${CLEAR_CLR}"
    echo -e "Debuild options:" "${BOLD_GREEN}${DEBUILD_OPT}${CLEAR_CLR}"
}

[ -z "${DISTRO}" ] && echo "Failed to detect distro name" && DISTRO="stable"
[ -z "${ARCH}" ] && echo "Failed to detect architecture"

# Show help
if [ -z "${DEB_VERSION}" ] || [ "$1" == "-h" ] || [ "$1" == "--help" ];
then
  usage
  exit 1
fi

print_info

# 1. Install dependencies
if [ "$INSTALL_DEPS" != "no" ];
then
  echo_clr "Installing dependencies..."
  ${SUDO} apt-get update
  ${SUDO} apt-get install ${BUILD_DEPENDS} -y
  ${SUDO} apt-get install ${DEPENDS} -y
fi

# 2. Create build directory
[ -d "${BUILD_DIR}" ] && rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# 3. Download tarball from Github
echo_clr "Downloading tarball..."
if [ "$TARBALL_DOWNLOAD_URL" != "" ];
then
  # If $TARBALL_DOWNLOAD_URL is set, try to download it using curl
  echo "${TARBALL_DOWNLOAD_URL}"
  curl -L "${TARBALL_DOWNLOAD_URL}" -o "${TARBALL_ORIG}"
else
  # Otherwise, run uscan to download the tarball
  echo_clr "NOTE: If the version you specified is too old, uscan may fail to find the tarball download URL on Github.
If so, please specify the download URL manually: TARBALL_DOWNLOAD_URL=XXXXXX ${SCRIPT_NAME} ${DEB_VERSION} ${SUB_VERSION}"
  uscan --package "${PROGRAM_NAME}" --watchfile ../debian/watch                   \
        --upstream-version "${DEB_VERSION}" --download-version "${DEB_VERSION}"   \
        --overwrite-download --no-signature --rename --destdir ./ --verbose
fi

# 4. Extract the tarball
tar -xzf "${TARBALL_ORIG}"

# 5. Copy debian directory
cp -R ../debian "${SOURCE_DIR}"
cd "${SOURCE_DIR}"

# 6. Apply patches
echo_clr "Applying patches..."
export QUILT_PATCHES=debian/patches
quilt push -a

# 7. Add new release to changelog
echo_clr "Add new release to changelog"
dch ${DCH_OPT} \
    --newversion "${DEB_VERSION}-${SUB_VERSION}~${DISTRO}1" \
    "New upstream version ${DEB_VERSION}" 2>/dev/null
head -n 5 debian/changelog

# 8. Build package

# Just an ugly fix, it may be improved in later version.
# Make sure focal is the last distro to sign, for this patch is uncompatible with other distros.
if [[ ${DISTRO} == "focal" ]]
then
    echo_clr "Applying python bindings patch for focal..."
    patch -p1 < ../../ubuntu20.04-fix-python-bindings.patch
fi

echo_clr "Building package..."
debuild -b ${DEBUILD_OPT}

# 9. Clean
debian/rules clean
# rm -f ../*.build ../*.buildinfo ../*.changes

echo_clr "Done."

exit 0
