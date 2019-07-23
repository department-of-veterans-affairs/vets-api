#!/bin/bash

# Runner script for comparing the performance of code changes
# optional flags:
#   -b  supply the "before" commit SHA. Defaults to HEAD~1
#   -a  supply the "after" commit SHA.  Defaults to current branch
#   -f  supply the file name that contains the code to benchmark. Defaults to 'benchmark/test_code.rb'
#
# Full example: ./benchmark/runner.sh -b 8dfe3c5 -a 21d51bb -f benchmark/testing.rb


current_branch="$(git branch | grep \\* | cut -d ' ' -f2)"
before_sha='HEAD~1'
after_sha=$current_branch
file='benchmark/test_code.rb'

while getopts 'a:b:f:' OPTION
do
  case $OPTION in
    a) after_sha="${OPTARG}";;
    b) before_sha="${OPTARG}";;
    f) file="${OPTARG}";;
  esac
done

for sha in $before_sha $after_sha
do
  git checkout Gemfile.lock
  git checkout $sha > /dev/null 2>&1
  rails runner $file
  echo "============================================================================================"
done
git checkout Gemfile.lock
git checkout $current_branch > /dev/null
