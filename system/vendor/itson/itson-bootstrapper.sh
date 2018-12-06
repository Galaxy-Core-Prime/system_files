#!/system/bin/sh

# Log everything automatically
exec &> "/data/local/tmp/itson_update_log"

PATH="/system/vendor/itson:${PATH}"

echo "ItsOn bootstrapper starting"

# Getprop is not initialized yet, so parse system properties manually
ANDROID_VERSION=$(grep -m 1 '^ro.build.version.release=' /system/build.prop)
ANDROID_VERSION=${ANDROID_VERSION#*=}
ANDROID_FINGERPRINT=$(grep -m 1 '^ro.build.fingerprint=' /system/build.prop)
ANDROID_FINGERPRINT=${ANDROID_FINGERPRINT#*=}
ANDROID_INCREMENTAL=$(grep -m 1 '^ro.build.version.incremental=' /system/build.prop)
ANDROID_INCREMENTAL=${ANDROID_INCREMENTAL#*=}

echo "Android version is ${ANDROID_VERSION}"
echo "Android fingerprint is ${ANDROID_FINGERPRINT}"
echo "Android build incremental is ${ANDROID_INCREMENTAL}"

ENABLE_FLAG_CARRIER="/carrier/teb.enable"
ENABLE_FLAG_CARRIER_LEGACY="/carrier/itson_enabled"
ENABLE_FLAG_BOOTSTRAPPER="/data/data/com.itsoninc.android.itsonservice/itson.enable"
MANIFEST="/carrier/itson/manifest"
FINGERPRINT_FILE="/carrier/itson/android.fingerprint"
BUNDLED_VERSION_FILE="/system/vendor/itson/resources.version"
INSTALLED_VERSION_FILE="/carrier/itson/version"
KERNEL_API_FILE="/system/vendor/itson/kernel.api"
KERNEL_SUPPORTED_FILE="/carrier/itson/kernel.supported"
INTEGRATION_VERSION_FILE="/system/vendor/itson/integration.version"
INTEGRATION_SUPPORTED_FILE="/carrier/itson/integration.supported"

RESOURCES_ZIP="/system/vendor/itson/resources.zip"
UPDATE_ZIP="/data/data/com.itsoninc.android.itsonservice/app_update_staging/itson-update.zip"

MODULE1_SYSTEM="/system/lib/modules/itson_module1.ko"
MODULE2_SYSTEM="/system/lib/modules/itson_module2.ko"
MODULE1_OTA="/carrier/itson/resources/itson_module1-${ANDROID_VERSION}-${ANDROID_INCREMENTAL}.ko"
MODULE2_OTA="/carrier/itson/resources/itson_module2-${ANDROID_VERSION}-${ANDROID_INCREMENTAL}.ko"

is_enabled() {
  # Either flag file exists
  [ -f ${ENABLE_FLAG_CARRIER} ] || [ -f ${ENABLE_FLAG_CARRIER_LEGACY} ] || [ -f ${ENABLE_FLAG_BOOTSTRAPPER} ]
}

is_installed() {
  # Manifest file exists
  [ -f ${MANIFEST} ]
}

is_fingerprint_mismatch() {
  # Fingerprint file does not exist or has wrong fingerprint
  [ ! -f ${FINGERPRINT_FILE} ] || ! grep -Fxq "${ANDROID_FINGERPRINT}" ${FINGERPRINT_FILE}
}

update_fingerprint() {
  echo -E "${ANDROID_FINGERPRINT}" > ${FINGERPRINT_FILE}
  chmod 600 ${FINGERPRINT_FILE}
}

vercomp() {
  # Compare versions using dotted notation, ignore "-" suffixes, ignore letters/special characters
  local ver1=${1%%-*} ver2=${3%%-*} a b
  while [ -n "${ver1}" ] || [ -n "${ver2}" ]; do
    a=${ver1%%.*}
    ver1=${ver1#"${a}"}
    ver1=${ver1#.}
    a=${a//[!0-9]/}
    b=${ver2%%.*}
    ver2=${ver2#"${b}"}
    ver2=${ver2#.}
    b=${b//[!0-9]/}
    if (( "10#${a}" > "10#${b}" )); then
      [[ "$2" == ">" || "$2" == ">=" || "$2" == "!=" ]]; return $?
    fi
    if (( "10#${a}" < "10#${b}" )); then
      [[ "$2" == "<" || "$2" == "<=" || "$2" == "!=" ]]; return $?
    fi
  done
  [[ "$2" == "=" || "$2" == "==" || "$2" == ">=" || "$2" == "<=" ]]; return $?
}

is_bundled_resources_newer() {
  # Installed version file does not exist or bundled version > installed version or installed version is 0.0.1
  [ ! -f ${INSTALLED_VERSION_FILE} ] || vercomp "$(cat ${BUNDLED_VERSION_FILE})" ">" "$(cat ${INSTALLED_VERSION_FILE})" || vercomp "0.0.1" "=" "$(cat ${INSTALLED_VERSION_FILE})"
}

is_kernel_api_supported() {
  # Kernel api is in list of OTAd supported kernels
  [ -f ${KERNEL_SUPPORTED_FILE} ] && grep -Fxq "$(cat ${KERNEL_API_FILE})" ${KERNEL_SUPPORTED_FILE}
}

is_framework_integration_supported() {
  # integration version (major only) <= OTAd supported version
  if [ -f ${INTEGRATION_SUPPORTED_FILE} ]; then
    local integration_version=$(cat ${INTEGRATION_VERSION_FILE})
    integration_version=${integration_version%%.*}
    vercomp "${integration_version}" "<=" "$(cat ${INTEGRATION_SUPPORTED_FILE})"
  else
    false
  fi
}


# Install / Update / Remove
if is_enabled; then
  echo "ItsOn is enabled"

  if ! is_installed && [ -f ${RESOURCES_ZIP} ]; then
    # Initial install
    echo "Performing initial install"
    rm -rf /carrier/itson
    itson_installer ${RESOURCES_ZIP}

    # Prevent possibility of stale OTA bypassing MR upgrade logic
    rm -f ${UPDATE_ZIP}

    # Update fingerprint file
    update_fingerprint
  elif [ -f ${UPDATE_ZIP} ]; then
    # OTA update exists, apply it
    echo "Performing OTA update"
    itson_installer ${UPDATE_ZIP}
    rm -f ${UPDATE_ZIP}
  fi

  if is_fingerprint_mismatch; then
    # Ensure that installed version can handle this MR
    if is_bundled_resources_newer; then
      echo "Performing MR update - bundled version is newer than installed"
      rm -rf /carrier/itson
      itson_installer ${RESOURCES_ZIP}
    elif ! is_framework_integration_supported; then
      echo "Performing MR update - installed version does not support framework integration"
      rm -rf /carrier/itson
      itson_installer ${RESOURCES_ZIP}
    elif ! is_kernel_api_supported; then
      echo "Performing MR update - installed version does not support kernel api"
      rm -rf /carrier/itson
      itson_installer ${RESOURCES_ZIP}
    else
      echo "Installed version supports this MR"
    fi

    # Update fingerprint file
    update_fingerprint
  fi
else
  echo "ItsOn is not enabled"

  # Remove if installed
  if is_installed; then
    echo "Removing installation"
    rm -rf /carrier/itson
  fi
fi

# Initialize system
if is_enabled; then
  # Apply SELinux policies if applicable
  if command -v restorecon &> /dev/null; then
    echo "Applying SELinux policies"
    restorecon -R /carrier/itson
  fi

  # Load the kernel modules
  if [ -f ${MODULE1_OTA} ] && [ -f ${MODULE2_OTA} ]; then
    echo "Loading kernel modules from OTA"
    insmod ${MODULE1_OTA}
    insmod ${MODULE2_OTA}
  else
    echo "Loading kernel modules from system"
    insmod ${MODULE1_SYSTEM}
    insmod ${MODULE2_SYSTEM}
  fi
fi

echo "ItsOn bootstrapper done"
