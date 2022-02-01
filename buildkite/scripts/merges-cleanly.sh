#!/bin/bash

BRANCH=$1
echo 'Testing for conflicts with `'"$BRANCH"'`...'

# Adapted from this stackoverflow answer: https://stackoverflow.com/a/10856937
# The git merge-tree command shows the content of a 3-way merge without
# touching the index, which we can then search for conflict markers.

git merge-tree `git merge-base origin/$BRANCH HEAD` origin/$BRANCH HEAD | grep "^<<<<<<<"

RET=$?

if [ $RET -eq 0 ]; then
  # Found a conflict
  echo "This pull request conflicts with $BRANCH , please open a new PR https://github.com/MinaProtocol/mina/compare/${BRANCH}...${BUILDKITE_BRANCH}"
  exit 1
else
  echo "No conflicts found in upstream branches, all good to merge!"
  exit 0
fi
