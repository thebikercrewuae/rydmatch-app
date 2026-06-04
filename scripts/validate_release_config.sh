#!/usr/bin/env bash

set -euo pipefail

errors=0
warnings=0

pass() {
  printf "PASS: %s\n" "$1"
}

warn() {
  printf "WARNING: %s\n" "$1"
  warnings=$((warnings + 1))
}

fail() {
  printf "ERROR: %s\n" "$1"
  errors=$((errors + 1))
}

require_file() {
  if [ -f "$1" ]; then
    pass "Found $1"
  else
    fail "Missing required file: $1"
  fi
}

require_directory() {
  if [ -d "$1" ]; then
    pass "Found $1"
  else
    fail "Missing required directory: $1"
  fi
}

require_variable() {
  local name="$1"
  if [ -n "${!name:-}" ]; then
    pass "$name is configured"
  else
    fail "$name is empty or missing"
  fi
}

echo "Running RydMatch release configuration checks..."

require_file "pubspec.yaml"
require_file "lib/main.dart"
require_file "android/app/build.gradle.kts"
require_file "android/app/src/main/AndroidManifest.xml"
require_file "codemagic.yaml"
require_directory "assets"
require_directory "supabase/functions"
require_directory "supabase/migrations"

APP_VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
if printf "%s" "$APP_VERSION" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\+[1-9][0-9]*$'; then
  pass "App version is valid: $APP_VERSION"
else
  fail "pubspec.yaml version must look like 1.0.16+16 and use a positive version code"
fi

require_variable "SUPABASE_URL"
require_variable "SUPABASE_ANON_KEY"
require_variable "GOOGLE_MAPS_API_KEY"
require_variable "STRAVA_CLIENT_ID"
require_variable "STRAVA_REDIRECT_URI"
require_variable "REVENUECAT_ANDROID_API_KEY"
require_variable "CM_KEYSTORE_BASE64"
require_variable "CM_KEYSTORE_PASSWORD"
require_variable "CM_KEY_ALIAS"

if [ "${STRAVA_REDIRECT_URI:-}" = "rydmatch://rydmatch.com/strava-callback" ]; then
  pass "Strava redirect URI matches the Android callback"
else
  fail "STRAVA_REDIRECT_URI must be rydmatch://rydmatch.com/strava-callback"
fi

if printf "%s" "${SUPABASE_URL:-}" | grep -Eq '^https://[a-z0-9]+\.supabase\.co/?$'; then
  pass "SUPABASE_URL format looks valid"
else
  fail "SUPABASE_URL must look like https://project-ref.supabase.co"
fi

for function_name in strava-auth admin-growth-dashboard livekit-token; do
  require_file "supabase/functions/$function_name/index.ts"
done

if grep -Rqi "rocket\.new" lib; then
  fail "Found rocket.new in app source"
else
  pass "No rocket.new references found in app source"
fi

if grep -q 'android:scheme="rydmatch"' android/app/src/main/AndroidManifest.xml &&
  grep -q 'android:host="rydmatch.com"' android/app/src/main/AndroidManifest.xml &&
  grep -q 'android:path="/strava-callback"' android/app/src/main/AndroidManifest.xml; then
  pass "Android Strava callback intent filter is configured"
else
  fail "Android Strava callback intent filter is incomplete"
fi

if [ -d test ] && find test -type f -name '*_test.dart' -print -quit | grep -q .; then
  pass "Flutter tests are present"
else
  warn "No Flutter tests found yet"
fi

echo
echo "Release configuration result: $errors error(s), $warnings warning(s)"
if [ "$errors" -ne 0 ]; then
  exit 1
fi
