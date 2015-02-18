#!/bin/sh

MERCURIAL_REPO=../plugins-hosted-vungle
#DRYRUN="-n"
RSYNC_ARGS="-c ${DRYRUN} -vv --delete --filter \"- .git\" --filter \"- .hg\""

if [ "$1" == "beta" ]; then
	eval "rsync ${RSYNC_ARGS} -r release/ ${MERCURIAL_REPO}-beta"
else
	eval "rsync ${RSYNC_ARGS} -r release/ ${MERCURIAL_REPO}"
fi
