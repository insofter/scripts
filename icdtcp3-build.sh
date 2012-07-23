#!/bin/sh

print_usage()
{
>&2 cat <<EOF

Usage: ${program_name} [-h|--help] [-v|--version] [TAG]

Build script for icdtcp3 projects. Checks out sources of all required
components, compiles them and builds release package. In order to work,
this script requires the following environment variables to be defined:
ICDTCP3_SCRIPTS_DIR, ICDTCP3_WORKING_DIR, ICDTCP3_BUILD_DIR, ICDTCP3_GIT_ROOT.

ddRuns initial device programming cycle - erases flash and flashes all 
neccessary components (at91bootstrap, u-boot, kernel and rootfs).
Also sets up all necessary u-boot commands, environment variables
and factory settings.

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

git_checkout()
{
  local git_root project tag
  git_root="$1"
  working_dir="$2"
  project="$3"
  tag="$4"

  info "Checking out '${project}@${tag}'"

  cd "${working_dir}"
  test $? -eq 0 || { error "Changing directory to '${working_dir} failed" noexit; return 1; }

  if [ -d "${project}" ]; then
    cd "${project}"
    test $? -eq 0 || { error "Changing directory to '${project} failed" noexit; return 1; }
    git pull
    test $? -eq 0 || { error "git pull for '${project}' failed" noexit; return 1; }
  else
    git clone "${git_root}/${project}"
    test $? -eq 0 || { error "git clone for '${project}' failed" noexit; return 1; }
    cd "${project}"
    test $? -eq 0 || { error "Changing directory to '${project} failed" noexit; return 1; }
  fi

  git checkout "${tag}"
  test $? -eq 0 || { error "git checkout '${tag}' failed" noexit; return 1; }
}

make_srcpkg()
{
  local git_root working_dir dl_dir project tag
  git_root="$1"
  working_dir="$2"
  dl_dir="$3"
  project="$4"
  tag="$5"

  info "Building source package for '${project}'"

  git_checkout "${git_root}" "${working_dir}" "${project}" "${tag}"
  test $? -eq 0 || return 1;

  make-srcpkg.sh -s "${working_dir}/${project}"  -o "${dl_dir}" "${project}"
  test $? -eq 0 || return 1
}

program_name=`basename "$0"`
version=$(script_version)

options=`getopt -o hv --long help,version -- "$@"`
test $? -eq 0 || error "Parsing parameters failed"
eval set -- "$options"
while true ; do
  case "$1" in
    -h|--help) print_usage; exit 0 ;;
    -v|--version) print_version; exit 0 ;;
    --) shift; break ;;
    *) error "Parsing parameters failed at '$1'" ;;
  esac
done

if [ "x$1" != "x" ]; then
  build_tag="$1"; shift 1
else
  build_tag="icdtcp3-2011.11"
fi

test "x$1" = "x" || error "Parsing parameters failed at '$1'"

test "x${ICDTCP3_GIT_ROOT}" != "x" || \
  error "Missing ICDTCP3_GIT_ROOT environment variable"
git_root="${ICDTCP3_GIT_ROOT}"

test "x${ICDTCP3_WORKING_DIR}" != "x" || \
  error "Missing ICDTCP3_WORKING_DIR environment variable"
working_dir="${ICDTCP3_WORKING_DIR}"
test "x${ICDTCP3_BUILD_DIR}" != "x" || \
  error "Missing ICDTCP3_BUILD_DIR environment variable"
build_dir="${ICDTCP3_BUILD_DIR}"
dl_dir="${build_dir}/dl"

mkdir -p "${working_dir}"
test $? -eq 0 || error "Creating '${working_dir}' directory failed"
mkdir -p "${build_dir}"
test $? -eq 0 || error "Creating '${build_dir}' directory failed"
mkdir -p "${dl_dir}"
test $? -eq 0 || error "Creating '${dl_dir}' directory failed"

# Sync buildroot repository
cd "${working_dir}"
git_checkout "${git_root}" "${working_dir}" "buildroot" "${build_tag}"
test $? -eq 0 || error "Checking out 'buildroot' project failed"

# Create .config file
make -C "${working_dir}/buildroot" O="${build_dir}" "icdtcp3_defconfig"
test $? -eq 0 || error "Creating buildroot 'icdtcp3' configuration failed"

# Find out build version
cd "${working_dir}/buildroot"
test $? -eq 0 || error "Changing directory to '${working_dir}/buildroot' failed"
build_version=`git describe --dirty | sed -e 's/^[^+]*+\(.*\)$/\1/'`
test -n "${build_version}" || error "Reading build version failed"

info "Creating 'at91bootstrap' source package..."
at91bootstrap_version=`cat "${working_dir}/buildroot/boot/at91bootstrap/at91bootstrap.mk" | \
  sed -n -e 's/^AT91BOOTSTRAP_VERSION[[:space:]]*=[[:space:]]*\([[:alnum:].-]*\).*$/\1/p'`
test -n "${at91bootstrap_version}" || error "Reading at91bootstrap version failed"
make_srcpkg "${git_root}" "${working_dir}" "${dl_dir}" "at91bootstrap" "${at91bootstrap_version}"
test $? -eq 0 || error "Creating 'at91bootstrap' source package failed"

info "Creating 'u-boot' source package..."
uboot_version=`cat "${working_dir}/buildroot/boot/uboot/uboot.mk" | \
  sed -n -e 's/^UBOOT_VERSION[[:space:]]*=[[:space:]]*"*\([^"]*\).*$/\1/p'`
test -n "${uboot_version}" || error "Reading u-boot version failed"
make_srcpkg "${git_root}" "${working_dir}" "${dl_dir}" "u-boot" "${uboot_version}"
test $? -eq 0 || error "Creating 'u-boot' source package failed"

info "Creating 'linux' source package..."
uimage_version=`cat "${build_dir}/.config" | \
  sed -n -e 's/^BR2_LINUX_KERNEL_VERSION[[:space:]]*=[[:space:]]*"*\([[:alnum:].-]*\).*$/\1/p'`
test -n "${uimage_version}" || error "Reading uimage version failed"
make_srcpkg "${git_root}" "${working_dir}" "${dl_dir}" "linux" "${uimage_version}"
test $? -eq 0 || error "Creating 'linux-stable' source package failed"

info "Creating 'icd' source package..."
icd_version=`cat "${working_dir}/buildroot/package/icd/icd.mk" | \
  sed -n -e 's/^ICD_VERSION[[:space:]]*=[[:space:]]*\([[:alnum:].-]*\).*$/\1/p'`
test -n "${icd_version}" || error "Reading icd version failed"
make_srcpkg "${git_root}" "${working_dir}" "${dl_dir}" "icd" "${icd_version}"
test $? -eq 0 || error "Creating 'icd' source package failed"

info "Building ${build_version}..."
make -C "${working_dir}/buildroot" O="${build_dir}"
test $? -eq 0 || error "Building ${build_version} failed"

icdtcp3-make-package.sh
test $? -eq 0 || error "Building ${build_version} package failed"

info "Done"

exit 0

