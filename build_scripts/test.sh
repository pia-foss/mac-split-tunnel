#!/bin/bash -xe

# Runs tests for the extension target

# For dev work, set any project vars in .env
if [ -f .env ]
then
    source .env
fi

xcodebuild -project ${PROJECT}.xcodeproj \
           -scheme ${TEST_TARGET} test

if [ "$?" -ne 0 ]
then
    echo "Testing failed with error $1"
    exit $1
fi
