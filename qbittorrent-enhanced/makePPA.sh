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

# Read version from argument
DEB_VERSION=$1
SUB_VERSION=${2:-"1"}

# Supported distributions
DISTROS=${DISTROS:-"xenial bionic disco"}

# Maintainer information, needed by dch
export DEBFULLNAME="poplite"
export DEBEMAIL="poplite.xyz@gmail.com"

# PPA infomation
PPA_URL="ppa:poplite/qbittorrent-enhanced"
PPA_KEY="F1B89752"

DEBUILD_OPT="-k${PPA_KEY}"
# Prefer using gpg2 for package signing
if hash gpg2 2>/dev/null;
then
    DEBUILD_OPT="${DEBUILD_OPT} -pgpg2"
fi

SOURCE_DIR="${PROGRAM_NAME}-${DEB_VERSION}"
TARBALL="${PROGRAM_NAME}_${DEB_VERSION}.orig.tar.gz"
TARBALL_URL="https://github.com/c0re100/qBittorrent-Enhanced-Edition/archive/release-${DEB_VERSION}.tar.gz"

BOLD_GREEN="\e[1;32m"
CLEAR_CLR="\e[0m"

echo_clr() {
    echo -e "${BOLD_GREEN}\n$1${CLEAR_CLR}"
}

usage() {
    echo -e "makePPA.sh for ${PROGRAM_NAME}"
    echo -e "Usage: ${SCRIPT_NAME} version [sub-version]\n"
    echo -e "version     - Main version (Example: 4.1.6.1)"
    echo -e "sub-version - Sub version  (Default: 1)"
}

check_depends() {
    depends="curl quilt dch debuild dput"
    for depend in ${depends}; 
    do
        if ! hash "$depend" 2>/dev/null; 
        then
            echo "ERROR: $depend not installed."
            exit 2
        fi
    done
}

print_config() {
    echo -e "Release version:" "${BOLD_GREEN}${DEB_VERSION}-${SUB_VERSION}${CLEAR_CLR}"
    echo -e "Maintainer     :" "${BOLD_GREEN}${DEBFULLNAME} <${DEBEMAIL}>${CLEAR_CLR}"
    echo -e "Launchpad PPA  :" "${BOLD_GREEN}${PPA_URL}${CLEAR_CLR}"
    echo -e "Release distro :" "${BOLD_GREEN}${DISTROS}${CLEAR_CLR}"
    echo -e "Debuild options:" "${BOLD_GREEN}${DEBUILD_OPT}${CLEAR_CLR}"
}

[ -z "${DEB_VERSION}" ] && usage && exit 1
check_depends

print_config

# 1. Create a new directory
[ -d "${DEB_VERSION}" ] && rm -rf "${DEB_VERSION}"
mkdir -p "${DEB_VERSION}"
cd "${DEB_VERSION}"

# 2. Download tarball from Github
echo_clr "Downloading tarball..."
echo "${TARBALL_URL}"
curl -L "${TARBALL_URL}" -o "${TARBALL}"

# 3. Extract the tarball
tar -xzf "${TARBALL}"
mv "qBittorrent-Enhanced-Edition-release-${DEB_VERSION}" "${SOURCE_DIR}"

# 4. Copy debian directory
cp -R ../debian "${SOURCE_DIR}"
cd "${SOURCE_DIR}"

# 5. Apply patches
echo_clr "Applying patches..."
export QUILT_PATCHES=debian/patches
quilt push -a

# 6. Add new release to changelog
echo_clr "Add new release to changelog"
dch --package qbittorrent-enhanced \
    --distribution %DISTRO% \
    --force-distribution \
    --force-bad-version \
    --newversion "${DEB_VERSION}-${SUB_VERSION}ppa1~%DISTRO%1" \
    "New upstream version ${DEB_VERSION}" 2>/dev/null
head -n 5 debian/changelog

# 7. Create and sign changes files
echo_clr "Signing changes files..."
cp debian/changelog ../changelog.template
for DISTRO in ${DISTROS}; 
do
    echo_clr "Signing ${DISTRO}..."
    sed "s/%DISTRO%/${DISTRO}/g" ../changelog.template > debian/changelog
    debuild -S ${DEBUILD_OPT}
done 
echo_clr "All changes files signed."
cd ..
ls -lh *.changes

# 8. Upload signed changes files to Launchpad
echo_clr "Uploading changes files..."
dput "${PPA_URL}" *.changes

echo_clr "Done."

exit 0
