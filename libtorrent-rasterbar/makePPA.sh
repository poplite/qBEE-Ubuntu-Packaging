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

# Read version from argument
DEB_VERSION=$1
SUB_VERSION=${2:-"1"}

# Supported distributions
DISTROS=${DISTROS:-"xenial bionic disco eoan focal"}

# Maintainer information, needed by dch
export DEBFULLNAME="poplite"
export DEBEMAIL="poplite.xyz@gmail.com"

# PPA infomation
PPA_URL=${PPA_URL:-"ppa:poplite/qbittorrent-enhanced"}
PPA_KEY="F1B89752"

# distribution name placeholder, used by sed
DIST_PLACEHOLDER="DISTRO"

# Options for dch
DCH_OPT="--package ${PROGRAM_NAME} --distribution ${DIST_PLACEHOLDER} --force-distribution --force-bad-version"

# Options for debuild
DEBUILD_OPT="-k${PPA_KEY}"
# Prefer using gpg2 for package signing
if hash gpg2 2>/dev/null;
then
    DEBUILD_OPT="${DEBUILD_OPT} -pgpg2"
fi

SOURCE_DIR="${PROGRAM_NAME}-${DEB_VERSION}"
TARBALL_ORIG="${PROGRAM_NAME}_${DEB_VERSION}.orig.tar.gz"

BOLD_GREEN="\e[1;32m"
CLEAR_CLR="\e[0m"

echo_clr() {
    echo -e "${BOLD_GREEN}\n$1${CLEAR_CLR}"
}

usage() {
    echo -e "${BOLD_GREEN}makePPA.sh for ${PROGRAM_NAME}${CLEAR_CLR}"
    echo -e "Usage: ${SCRIPT_NAME} version [sub-version]\n"
    echo -e "Options:"
    echo -e "  version     - Main version (Recommended: ${BOLD_GREEN}${CURR_VERSION}${CLEAR_CLR})"
    echo -e "  sub-version - Sub version  (Default: 1)"
}

check_depends() {
    depends="curl quilt dch debuild dput uscan"
    for depend in ${depends}; 
    do
        if ! hash "$depend" 2>/dev/null; 
        then
            echo "ERROR: $depend not installed."
            exit 2
        fi
    done
}

print_info() {
    echo -e "Release version:" "${BOLD_GREEN}${DEB_VERSION}-${SUB_VERSION}${CLEAR_CLR}"
    echo -e "Maintainer     :" "${BOLD_GREEN}${DEBFULLNAME} <${DEBEMAIL}>${CLEAR_CLR}"
    echo -e "Launchpad PPA  :" "${BOLD_GREEN}${PPA_URL}${CLEAR_CLR}"
    echo -e "Release distro :" "${BOLD_GREEN}${DISTROS}${CLEAR_CLR}"
    echo -e "Debuild options:" "${BOLD_GREEN}${DEBUILD_OPT}${CLEAR_CLR}"
}

# Show help
if [ -z "${DEB_VERSION}" ] || [ "$1" == "-h" ] || [ "$1" == "--help" ];
then
  usage
  exit 1
fi

check_depends

print_info

# 1. Create a new directory
[ -d "${DEB_VERSION}" ] && rm -rf "${DEB_VERSION}"
mkdir -p "${DEB_VERSION}"
cd "${DEB_VERSION}"

# 2. Download tarball from Github
echo_clr "Downloading tarball..."
if [[ "$TARBALL_DOWNLOAD_URL" != "" ]];
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

# 3. Extract the tarball
tar -xzf "${TARBALL_ORIG}"

# 4. Copy debian directory
cp -R ../debian "${SOURCE_DIR}"
cd "${SOURCE_DIR}"

# 5. Apply patches
echo_clr "Applying patches..."
export QUILT_PATCHES=debian/patches
quilt push -a

# 6. Add new release to changelog
echo_clr "Add new release to changelog"
dch ${DCH_OPT} \
    --newversion "${DEB_VERSION}-${SUB_VERSION}ppa1~${DIST_PLACEHOLDER}1" \
    "New upstream version ${DEB_VERSION}" 2>/dev/null
head -n 5 debian/changelog

# 7. Create and sign changes files
echo_clr "signing changes files..."
cp debian/changelog ../changelog.template
for DISTRO in ${DISTROS}; 
do
    # Just an ugly fix, it may be improved in later version.
    # Make sure focal is the last distro to sign, for this patch is uncompatible with other distros.
    if [[ ${DISTRO} == "focal" ]]
    then
        echo_clr "Applying python bindings patch for focal..."
        patch -p1 < ../../ubuntu20.04-fix-python-bindings.patch
    fi

    echo_clr "signing ${DISTRO}..."
    sed "s/${DIST_PLACEHOLDER}/${DISTRO}/g" ../changelog.template > debian/changelog
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
