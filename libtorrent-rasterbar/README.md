
*CREDIT*: The original `debian` directory used in this repo was taken from [Debian](https://salsa.debian.org/debian/libtorrent-rasterbar) and [official PPA](https://launchpad.net/~qbittorrent-team/+archive/ubuntu/qbittorrent-stable).

**Current version**: 1.2.10

## Note for ubuntu 20.04

Please patch `ubuntu20.04-fix-python-bindings.patch` to your source code before building package. It fixes a filename pattern error for python3.8 bindings which causes failure while generating Deb package. It also removes python2 bindings, for Python 2 is about to reach end-of-life.
