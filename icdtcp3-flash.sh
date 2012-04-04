#!/bin/sh

print_usage()
{
>&2 cat <<EOF

Usage: ${program_name} [-s|--samba-device DEVICE] [-d|--release-dir DIR]
  [-f|--factory-settings FILE] [-h|--help] [-v|--version]

Runs initial device programming cycle - erases flash and flashes all 
neccessary components (at91bootstrap, u-boot, kernel and rootfs).
Also sets up all necessary u-boot commands, environment variables
and factory settings.

  -s|--samba-device     samba modem device; default is read from
                        ICDTCP3_SAM_BA_MODEM environment variable;
                        if missing '/dev/ttyACM0' is used

  -d|--release-dir      release directory where all binaries resides;
                        default is read from ICDTCP3_RELEASE_DIR
                        environment variable; if missing an error
                        is returned

  -f|--factory-settings file containging factory settings to be
                        programmed on the device; each line in the file
                        should containg a definition of one variable
                        in the form: <name>=<value>
                        Lines beginning with '#' are treated as comments
                        and ignored, line breakings (lines ended with '\'
                        that continiues on the next line) are concatenated
                        before actual programming

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

# $1 source file
# $2 destination file
sync_image()
{
  local src_file dst_file count file
  src_file="$1"
  dst_file="$2"

  count=`eval ls -1 "${src_file}" | wc -l`
  if [ ${count} -eq 0 ]; then
    error "No file matches '${src_file}'" noexit;
    return 1
  elif [ ${count} -gt 1 ]; then
    error "Too many files matching '${src_file}'" noexit;
    return 1
  fi

  file=`eval ls -1 "${src_file}"`
  info "Synchronizing '`basename "${file}"`'..."
  rsync -a "${file}" "${dst_file}"
}

program_name=`basename "$0"`

#TODO cd to scripts directory

#version=`git describe --dirty | sed -e 's/^v\(.*\)$/\1/'`
#TODO read version
version="0.0"

if [ "x${ICDTCP3_SAM_BA_DIR}" != "x" ]; then
  samba_dev="${ICDTCP3_SAM_BA_DIR}"
else
  samba_dev="/dev/ttyACM0"
fi

release_dir="${ICDTCP3_RELEASE_DIR}"

options=`getopt -o s:d:f:hv --long samba-device:,release-dir:,factory-settings:,help,version -- "$@"`
test $? -eq 0 || error "Parsing parameters failed"
eval set -- "$options"
while true ; do
  case "$1" in
    -s|--samba-device) samba_dev="$2"; shift 2 ;;
    -d|--release-dir) release_dir=`eval cd "$2" && pwd`; shift 2 ;;
    -f|--factory-settings) fs_file="$2"; shift 2 ;;
    -h|--help) print_usage; exit 0 ;;
    -v|--version) print_version; exit 0 ;;
    --) shift; break ;;
    *) error "Parsing parameters failed at '$1'" ;;
  esac
done

test "x$1" = "x" || error "Parsing parameters failed at '$1'"

test "x${release_dir}" != "x" || error "Missing release-dir parameter"

# ICDTCP3_SCRIPT_DIR is required to locate icdtcp3.tcl
# and icdtcp3-flash-script.txt scripts
test "x${ICDTCP3_SCRIPTS_DIR}" != "x" || \
  error "Missing ICDTCP3_SCRIPTS_DIR environment variable"

# ICDTCP3_TFTP_DIR is also required by icdtcp3.tcl script
test "x${ICDTCP3_TFTP_DIR}" != "x" || \
  error "Missing ICDTCP3_TFTP_DIR environment variable"

# Copy required binaries from RELEASE directory into TFTP directory
sync_image "${release_dir}/at91bootstrap*.bin" \
  "${ICDTCP3_TFTP_DIR}/at91bootstrap.bin"
test $? -eq 0 || error "Synchronization failed"

sync_image "${release_dir}/u-boot*.bin" \
  "${ICDTCP3_TFTP_DIR}/u-boot.bin"
test $? -eq 0 || error "Synchronization failed"

sync_image "${release_dir}/uImage*" \
  "${ICDTCP3_TFTP_DIR}/uImage"
test $? -eq 0 || error "Synchronization failed"

sync_image "${release_dir}/rootfs*.ubifs" \
  "${ICDTCP3_TFTP_DIR}/rootfs.ubifs"
test $? -eq 0 || error "Synchronization failed"

sync_image "${release_dir}/data*.ubifs" \
  "${ICDTCP3_TFTP_DIR}/data.ubifs"
test $? -eq 0 || error "Synchronization failed"

# Prepare factory settings file
info "Preparing factory settings..."
if [ "x${fs_file}" != "x" ]; then
  cat "${fs_file}" | \
    sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e '/^$/ d' | \
    sed -e '/[\]$/ { N; s:[\]\n:: }' \
    > "${ICDTCP3_TFTP_DIR}/factory-settings.txt"
else
  cat /dev/null > "${ICDTCP3_TFTP_DIR}/factory-settings.txt"
fi

# Create flash script image
info "Creating flash-script..."
TMP_FILE=`mktemp`
test $? -eq 0 || error "Creating temporary file failed"

cat ${ICDTCP3_SCRIPTS_DIR}/icdtcp3-flash-script.txt | \
  sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e '/^$/ d' | \
  sed -e '/[\]$/ { N; s:[\]\n:: }' > ${TMP_FILE}
test $? -eq 0 || error "Preparing icdtcp3-flash-script.txt failed"

mkimage -A arm -O linux -T script -C none -n "flash-script" \
  -d ${TMP_FILE} ${ICDTCP3_TFTP_DIR}/flash-script.img
test $? -eq 0 || error "Creating flash-script failed"

# Run sam-ba to flash at91bootstrap and u-boot
info "Running sam-ba..."
sam-ba ${ICDTCP3_SAM_BA_MODEM} at91sam9260-ek ${ICDTCP3_SCRIPTS_DIR}/icdtcp3.tcl
test $? -eq 0 || error "Running sam-ba failed"

rm "${TMP_FILE}"

exit 0

