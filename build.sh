#!/bin/bash
set -ex

# This build script is mainly aimed at CI. It takes a bunch of environment variables as input.
# Optionally, we can use the .env work to help during debugging or if we want to work without XCode.
#
# APP_BUILD_TARGET -> application XCode target 
# APP_PROVISION_PROFILE -> path to the provision profile to use for the final app build. Obtained from Apple developers site.
# CODESIGN_IDENTITY -> name of the installed certificate to use for signing. You can find yours with `security find-identity -v -p codesigning`. It's obtained from Apple.
# EXTENSION_BUILD_TARGET -> extension XCode target
# EXTENSION_ID -> bundle id of the extension
# NOTARIZATION_EMAIL -> email to use for notarization. Only used for release builds, ignore during dev work
# NOTARIZATION_PASSWORD -> password to use for notarization. It's a token password obtained from apple
# PACKAGE_FOR_RELEASE -> boolean-ish flag. When 0 this will be a development build, when 1 it will be a distributable build using a Developer ID certificate.
# PROJECT -> Name of the project file (without extension)
# SEXT_PROVISION_PROFILE -> path to the provision profile to use for the final extension build. Obtained from Apple developers site.
# TEAM_ID -> Team Id, obtained from Apple to your dev account

# For dev work, set any project vars in .env
if [ -f .env ]
then
    source .env
fi

extension_id=${EXTENSION_ID}
extension_bundle="${extension_id}.systemextension"
app_name="${APP_BUILD_TARGET}"
app_bundle="${app_name}.app"

# These values are all linked together. The profile is only valid for a certificate and identity (bundle id).
# If building for distribution `PACKAGE_FOR_RELEASE=1`, and CODESIGN_IDENTITY must be a Developer ID certificate. 
certificate_name="$CODESIGN_IDENTITY"
app_provision_profile_path="$APP_PROVISION_PROFILE"
extension_provision_profile_path="$SEXT_PROVISION_PROFILE"

app_profile_uuid=$(grep --binary-files=text -A1 UUID "$app_provision_profile_path" | tail -n1 | sed -E 's/<string>(.*)<\/string>/\1/g' | tr -d ' ' | tr -d '\t')
extension_profile_uuid=$(grep --binary-files=text -A1 UUID "$extension_provision_profile_path" | tail -n1 | sed -E 's/<string>(.*)<\/string>/\1/g' | tr -d ' ' | tr -d '\t')

ditto "$app_provision_profile_path" "$HOME/Library/MobileDevice/Provisioning Profiles/${app_profile_uuid}.provisionprofile"
ditto "$extension_provision_profile_path" "$HOME/Library/MobileDevice/Provisioning Profiles/${extension_profile_uuid}.provisionprofile"

# For release, change network entitlements for their Developer ID variant with the `-systemextension` suffix.
# Otherwise, xcodebuild will fail with a mismatch between entitlements and the provision profile.
# Careful if you run this locally, as the entitlement files will change
if [ $PACKAGE_FOR_RELEASE -ne 0 ]
then
    find . -name '*.entitlements' -exec sed -i '' 's/app-proxy-provider/app-proxy-provider-systemextension/g' {} \;
fi

# Build the app and extension
xcodebuild -project ${PROJECT}.xcodeproj -scheme ${EXTENSION_BUILD_TARGET} archive -archivePath "out/${EXTENSION_BUILD_TARGET}.xcarchive" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="${certificate_name}" PROVISIONING_PROFILE_SPECIFIER="${extension_profile_uuid}"
xcodebuild -project ${PROJECT}.xcodeproj -scheme ${APP_BUILD_TARGET} archive -archivePath "out/${APP_BUILD_TARGET}.xcarchive" CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="${certificate_name}" PROVISIONING_PROFILE_SPECIFIER="${app_profile_uuid}"

# Copy the app and extension over
for i in ./out/*.xcarchive
do
    bundle=$(ls -1 "$i/Products/Applications")
    ditto "$i/Products/Applications/${bundle}" "./out/${bundle}"
done

# Make sure the right bundles got copied
if [ ! -d "./out/${extension_bundle}" ] || [ ! -d "./out/${app_bundle}" ] 
then
  echo Missing bundles, probably a configuration error?
  exit 1
fi

# Extract the entitlements from the builds. They differ from the .entitlements files in the project!
codesign -d --entitlements :- "./out/${app_bundle}" > ./out/app.entitlements
codesign -d --entitlements :- "./out/${extension_bundle}" > ./out/sext.entitlements

# We already changed the entitlements to contain the -systemextension suffix before.
# Usually the initial build would always be in dev mode, so we'd need to change them again here.
# Keep that in mind if you work on a mix environment where the builds from xcodebuild are using a development env.
if false && [ $PACKAGE_FOR_RELEASE -ne 0 ]
then
    # We only use this entitlement, if we need others we can specify them here too
    sed -i '' 's/app-proxy-provider/app-proxy-provider-systemextension/g' ./out/app.entitlements
    sed -i '' 's/app-proxy-provider/app-proxy-provider-systemextension/g' ./out/sext.entitlements
fi

# Copy the system extension into the app bundle
mkdir -p ./out/${app_bundle}/Contents/Library/SystemExtensions/
ditto ./out/${extension_bundle} ./out/${app_bundle}/Contents/Library/SystemExtensions/${extension_bundle}

# Replace the embedded provision profiles
ditto ${app_provision_profile_path} "./out/${app_bundle}/Contents/embedded.provisionprofile"
ditto ${extension_provision_profile_path} "./out/${app_bundle}/Contents/Library/SystemExtensions/${extension_bundle}/Contents/embedded.provisionprofile"

# Sign the System extension bundle first, then the binary with entitlements. Both require hardened runtime
codesign -f --timestamp --options runtime --sign "${certificate_name}" ./out/${app_bundle}/Contents/Library/SystemExtensions/${extension_bundle}
codesign -f --timestamp --options runtime --entitlements "./out/sext.entitlements" --sign "${certificate_name}" "./out/${app_bundle}/Contents/Library/SystemExtensions/${extension_bundle}/Contents/MacOS/${extension_id}"

# Sign the App bundle first, then the binary with entitlements. Both require hardened runtime
codesign -f --timestamp --options runtime --sign "${certificate_name}" ./out/${app_bundle}
if [ -f "./out/${app_bundle}/Contents/Frameworks/libswift_Concurrency.dylib" ]
then
    # Any additional resources require manual signing as we are not using the --deep flag.
    codesign -f --timestamp --options runtime --sign "${certificate_name}" "./out/${app_bundle}/Contents/Frameworks/libswift_Concurrency.dylib"
fi
codesign -f --timestamp --options runtime --entitlements "./out/app.entitlements" --sign "${certificate_name}" "./out/${app_bundle}/Contents/MacOS/${app_name}"

# Notarize for release
if [ $PACKAGE_FOR_RELEASE -ne 0 ]
then
    # notarytool cannot take a bundle, zip it first.
    ditto -ck --rsrc --keepParent --sequesterRsrc "./out/${app_bundle}" ./out/app.zip
    xcrun notarytool submit ./out/app.zip --wait --apple-id=${NOTARIZATION_EMAIL} --password="${NOTARIZATION_PASSWORD}" --team-id="$TEAM_ID"
    # Staple assuming notarization was Accepted. Even if it fails, notarytool returns 0, so stapler will fail then.
    xcrun stapler staple "./out/${app_bundle}"
fi

echo OK