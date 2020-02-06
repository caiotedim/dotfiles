#!/bin/bash
##############################################################################
# fancy-i3lock
# -----------
# Based on the awesome sauce of https://github.com/meskarune/i3lock-fancy
# This just uses imagemagick in a container...
# because reasons...
#
# Dependencies: docker, i3lock, scrot

# :authors: Jess Frazelle, @jessfraz
# :date: 8 June 2015
# :version: 0.0.1
##############################################################################
set -e

# subshell this shiz
(
IMAGE="/tmp/lock.png"

# All options are here: http://www.imagemagick.org/Usage/blur/#blur_args
BLURTYPE="0x8"
# BLURTYPE="0x5" # 7.52s
# BLURTYPE="0x2" # 4.39s
# BLURTYPE="5x3" # 3.80s
# BLURTYPE="2x8" # 2.90s
# BLURTYPE="2x3" # 2.92s

scrot $IMAGE

docker run --rm \
	-v $IMAGE:$IMAGE \
	-v "${HOME}/Pictures/lock.png:/root/lock.png" \
	r.j3ss.co/imagemagick \
  sh -c "
    [ -f ${IMAGE} ] || touch ${IMAGE}
    [ -f /root/lock.png ] || touch /root/lock.png
    shot=$(import -window root)
    ${shot[@]} ${IMAGE}
    convert ${IMAGE} -blur ${BLURTYPE} /root/lock.png"

i3lock -i ${HOME}/Pictures/lock.png

rm $IMAGE
)
