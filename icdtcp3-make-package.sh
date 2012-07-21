#!/bin/sh

print_usage()
{
>&2 cat <<EOF

Usage: ${program_name} [-d|--release-dir DIR]
  [-h|--help] [-v|--version]

Creates icdtcp3 release package, a bzipped archive containging all flashable
binaries plus version header. This tool expects ICDTCP3_SCRIPTS_DIR,
ICDTCP3_WORKING_DIR and ICDTCP3_BUILD_DIR  environment variables to be defined.

  -d|--release-dir      release directory where to put resulting archive

  -h|--help             show this information

  -v|--version          show version information

EOF
}

print_version()
{
>&2 cat <<EOF

${program_name} ${version}
Copyright (c) 2011-2012 Tomasz Rozensztrauch

EOF
}

info() 
{
  echo "${program_name}: $1" >&2
}

error() 
{
  echo "${program_name}: Error! $1" >&2
  if [ "$2" != "noexit" ]; then
    exit 1;
  fi
}

script_version()
{
  # Go to scripts directory in order to find out the script version
  if [ "x${ICDTCP3_SCRIPTS_DIR}" != "x" ]; then
    cd "${ICDTCP3_SCRIPTS_DIR}"
    if [ $? -eq 0 ]; then
      printf "%s" `git describe --dirty | sed -e 's/^v//' -e 's/+/-/g'`
    else
      printf "?"
    fi
  else
    printf "?"
  fi
}

program_name=`basename "$0"`
version=$(script_version)

options=`getopt -o d:hv --long release-dir:,help,version -- "$@"`
test $? -eq 0 || error "Parsing parameters failed"
eval set -- "$options"
while true ; do
  case "$1" in
    -d|--release-dir) release_dir=`eval cd "$2" && pwd`;
       test $? -eq 0 || error "Invalid release directory"; shift 2 ;;
    -h|--help) print_usage; exit 0 ;;
    -v|--version) print_version; exit 0 ;;
    --) shift; break ;;
    *) error "Parsing parameters failed at '$1'" ;;
  esac
done

test "x$1" = "x" || error "Parsing parameters failed at '$1'"

test "x${ICDTCP3_WORKING_DIR}" != "x" || \
  error "Missing ICDTCP3_WORKING_DIR environment variable"
working_dir="${ICDTCP3_WORKING_DIR}"
test "x${ICDTCP3_BUILD_DIR}" != "x" || \
  error "Missing ICDTCP3_BUILD_DIR environment variable"
build_dir="${ICDTCP3_BUILD_DIR}"
if [ "x${release_dir}" = "x" ]; then
  release_dir="${build_dir}"
fi

cd "${working_dir}/buildroot"
test $? -eq 0 || error "Changing directory to '${working_dir}/buildroot' failed"
package_version=`git describe --dirty | sed -e 's/^[^+]*+\(.*\)$/\1/'`
test -n "${package_version}" || error "Reading package version failed"
rootfs_version=`git describe --dirty | sed -e 's/^v//' -e 's/+/-/g'`
test -n "${rootfs_version}" || error "Reading rootfs version failed"

temp_dir=`mktemp -d`
test $? -eq 0 || error "Creating temporary directory '${temp_dir}' failed"
export_dir="${temp_dir}/${package_version}"
mkdir -p "${export_dir}"
test $? -eq 0 || error "Creating '${export_dir}' directory failed"

info "Building '${package_version}' package"

info "Creating package header..."
echo "version=${package_version}" > "${export_dir}/header"
at91bootstrap_version=`cat "${working_dir}/buildroot/boot/at91bootstrap/at91bootstrap.mk" | \
  sed -n -e 's/^AT91BOOTSTRAP_VERSION[[:space:]]*=[[:space:]]*\([[:alnum:].-]*\).*$/\1/p'`
test -n "${at91bootstrap_version}" || error "Reading at91bootstrap version failed"
echo "at91bootstrap-version=${at91bootstrap_version}" >> "${export_dir}/header"
uboot_version=`cat "${working_dir}/buildroot/boot/uboot/uboot.mk" | \
  sed -n -e 's/^UBOOT_VERSION[[:space:]]*=[[:space:]]*"*\([^"]*\).*$/\1/p'`
test -n "${uboot_version}" || error "Reading u-boot version failed"
echo "u-boot-version=${uboot_version}" >> "${export_dir}/header"
uimage_version=`cat "${build_dir}/.config" | \
  sed -n -e 's/^BR2_LINUX_KERNEL_VERSION[[:space:]]*=[[:space:]]*"*\([[:alnum:].-]*\).*$/\1/p'`
test -n "${uimage_version}" || error "Reading uimage version failed"
echo "uimage-version=${uimage_version}" >> "${export_dir}/header"
echo "rootfs-version=${rootfs_version}" >> "${export_dir}/header"
icd_version=`cat "${working_dir}/buildroot/package/icd/icd.mk" | \
  sed -n -e 's/^ICD_VERSION[[:space:]]*=[[:space:]]*\([[:alnum:].-]*\).*$/\1/p'`
test -n "${icd_version}" || error "Reading icd version failed"
echo "icd-version=${icd_version}" >> "${export_dir}/header"

info "Copying files..."
rsync -a "${build_dir}/images/"  "${export_dir}"
test $? -eq 0 || error "Copying package files failed"

info "Creating 'data.ubifs'..."
mkfs.ubifs -r "${build_dir}/target/mnt/data" -m 2048 -e 258048 -c 4000 -x none \
 -o "${export_dir}/data.ubifs"
test $? -eq 0 || error "Creating 'data.ubifs' failed"

info "Creating archive '${release_dir}/${package_version}.tar.bz2'..."
cd "${temp_dir}"
test $? -eq 0 || error "Changing directory to '${output_dir}' failed"
tar -cjf "${release_dir}/${package_version}.tar.bz2" "${package_version}"
test $? -eq 0 || \
  error "Creating bzipped tar archive '${release_dir}/${package_version}.tar.bz2' failed"

info "Done"

exit 0

