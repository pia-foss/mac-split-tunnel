#!/bin/bash -xe

# Runs tests for the extension target

# For dev work, set any project vars in .env
if [ -f .env ]
then
    source .env
fi

test_output_file=$(mktemp)
xcodebuild -project ${PROJECT}.xcodeproj \
           -scheme ${TEST_TARGET} test 2>&1 | tee "$test_output_file" | grep 'Test '

if [ "$?" -ne 0 ]
then
    echo "Testing failed with error $1"
    echo "::group::Full output"
    cat "$test_output_file"
    echo "::endgroup::"
    exit $1
fi
