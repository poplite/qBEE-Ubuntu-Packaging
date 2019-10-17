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

VERSION="1.1"

PROGRAM_NAME="qbittorrent-enhanced"
SCRIPT_NAME=$0

# Read version and distro name from argument
DEB_VERSION=$1
SUB_VERSION="1"
DISTRO=${2:-$(lsb_release -sc || true)} # ignore error
ARCH=$(dpkg --print-architecture)

# Maintainer information, needed by dch
export DEBFULLNAME="poplite"
export DEBEMAIL="poplite.xyz@gmail.com"

# Check if running as root
if [[ $(id -u) != 0 ]];
then
    SUDO="sudo"
else
    SUDO=""
fi

DEBUILD_OPT="-uc -us -rfakeroot"

BUILD_DEPENDS="debhelper dh-systemd dpkg-dev build-essential devscripts fakeroot quilt curl tar"
DEPENDS="libtorrent-rasterbar-dev libboost-dev libqt5svg5-dev qtbase5-dev qttools5-dev-tools zlib1g-dev geoip-database"

BUILD_DIR="${DEB_VERSION}-build"
SOURCE_DIR="${PROGRAM_NAME}-${DEB_VERSION}"
TARBALL="${PROGRAM_NAME}_${DEB_VERSION}.orig.tar.gz"
TARBALL_URL="https://github.com/c0re100/qBittorrent-Enhanced-Edition/archive/release-${DEB_VERSION}.tar.gz"

BOLD_GREEN="\e[1;32m"
CLEAR_CLR="\e[0m"

echo_clr() {
    echo -e "${BOLD_GREEN}\n$1${CLEAR_CLR}"
}

usage() {
    echo -e "makeDeb.sh for ${PROGRAM_NAME}"
    echo -e "Usage: ${SCRIPT_NAME} version [distro]\n"
    echo -e "version - Build version (Example: 4.1.6.1)"
    echo -e "distro  - Distribution codename (Example: bionic)"
}

print_info() {
    echo -e "Build version  :" "${BOLD_GREEN}${DEB_VERSION}-${SUB_VERSION}${CLEAR_CLR}"
    echo -e "Build distro   :" "${BOLD_GREEN}${DISTRO}${CLEAR_CLR}"
    echo -e "Build arch     :" "${BOLD_GREEN}${ARCH}${CLEAR_CLR}"
    echo -e "Debuild options:" "${BOLD_GREEN}${DEBUILD_OPT}${CLEAR_CLR}"
}

[ -z "${DEB_VERSION}" ] && usage && exit 1
[ -z "${DISTRO}" ] && echo "Failed to detect distro name" && DISTRO="stable"
[ -z "${ARCH}" ] && echo "Failed to detect architecture"

print_info

# 1. Install dependencies
echo_clr "Installing dependencies..."
${SUDO} apt-get update
${SUDO} apt-get install ${BUILD_DEPENDS} -y
${SUDO} apt-get install ${DEPENDS} -y

# 2. Create build directory
[ -d "${BUILD_DIR}" ] && rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# 3. Download tarball from Github
echo_clr "Downloading tarball..."
echo "${TARBALL_URL}"
curl -L "${TARBALL_URL}" -o "${TARBALL}"

# 4. Extract the tarball
tar -xzf "${TARBALL}"
mv "qBittorrent-Enhanced-Edition-release-${DEB_VERSION}" "${SOURCE_DIR}"

# 5. Copy debian directory
cp -R ../debian "${SOURCE_DIR}"
cd "${SOURCE_DIR}"

# 6. Apply patches
echo_clr "Applying patches..."
export QUILT_PATCHES=debian/patches
quilt push -a

# 7. Add new release to changelog
echo_clr "Add new release to changelog"
dch --package "${PROGRAM_NAME}" \
    --distribution "${DISTRO}" \
    --force-distribution \
    --force-bad-version \
    --newversion "${DEB_VERSION}-${SUB_VERSION}~${DISTRO}1" \
    "New upstream version ${DEB_VERSION}" 2>/dev/null
head -n 5 debian/changelog

# 8. Build package
echo_clr "Building package..."
debuild -b ${DEBUILD_OPT}

# 9. Clean
debian/rules clean
# rm -f ../*.build ../*.buildinfo ../*.changes

echo_clr "Done."

exit 0
