#!/bin/bash

# Updates ProxyExtension/build.xcconfig.
# By default it gets set to the current year (last two digits), month, day, hour, minute and second.
# If you specify a parameter, it will set it to that specific value.

if [ $# -eq 0 ]
then
    build_number=$(date "+%y%m%d%H%M%S")
else
    build_number=$1
fi
echo "EXT_BUILD_NUMBER=${build_number}" > 'ProxyExtension/build.xcconfig'