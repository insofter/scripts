#!/bin/sh

print_usage()
{
>&2 cat <<EOF

Usage: ${program_name} [-s|--samba-device DEVICE] [-f|--factory-settings FS_FILE]
  [-p|--prepare-only] PACKAGE_FILE
  [-h|--help] [-v|--version]

Runs initial device programming cycle - erases flash and flashes all 
neccessary components (at91bootstrap, u-boot, kernel, rootfs, datafs)
from PACKAGE_FILE. Package file is a bzipped tar archive built during
icdtcp3 build process. Sets up all necessary u-boot commands,
environment variables and factory settings.

  -s|--samba-device     samba modem device; default is read from
                        ICDTCP3_SAM_BA_MODEM environment variable;
                        if missing '/dev/ttyACM0' is used

  -f|--factory-settings file containging factory settings to be
                        programmed on the device; each line in the file
                        should containg a definition of one variable
                        in the form: <name>=<value>
                        Lines beginning with '#' are treated as comments
                        and ignored, line breakings (lines ended with '\'
                        that continiues on the next line) are concatenated
                        before actual programming

  -p|--prepare-only     Copy all required components to tftp folder 
                        but do not launch sam-ba programming; This option
                        is usefull if you intend to re-flash the device
                        from u-boot console

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

options=`getopt -o s:d:f:phv --long samba-device:,release-dir:,factory-settings:,prepare-only,help,version -- "$@"`
test $? -eq 0 || error "Parsing parameters failed"
eval set -- "$options"
while true ; do
  case "$1" in
    -s|--samba-device) samba_dev="$2"; shift 2 ;;
    -f|--factory-settings) fs_file="$2"; shift 2 ;;
    -p|--prepare-only) prepare_only="yes"; shift 1 ;;
    -h|--help) print_usage; exit 0 ;;
    -v|--version) print_version; exit 0 ;;
    --) shift; break ;;
    *) error "Parsing parameters failed at '$1'" ;;
  esac
done

test "x$1" != "x" || error "Parsing parameters faield. Missing parameter PACKAGE_FILE"
package_file="$1"; shift 1

test "x$1" = "x" || error "Parsing parameters failed at '$1'"

if [ "x${samba_dev}" = "x" ]; then
  if [ "x${ICDTCP3_SAM_BA_DIR}" != "x" ]; then
    samba_dev="${ICDTCP3_SAM_BA_DIR}"
  else
    samba_dev="/dev/ttyACM0"
  fi
fi

if [ "x${prepare_only}" != "xyes" ]; then
  prepare_only="no"
fi

# ICDTCP3_TFTP_DIR environment variable must exists;
# Is is also required by icdtcp3.tcl script
test "x${ICDTCP3_TFTP_DIR}" != "x" || \
  error "Missing ICDTCP3_TFTP_DIR environment variable"

# Copying uImage-prog to tftp directory
info "Copying uImage-prog to tftp directory..."
rsync -a ${ICDTCP3_SCRIPTS_DIR}/icdtcp3-uImage-prog ${ICDTCP3_TFTP_DIR}/uImage-prog
test $? -eq 0 || error "Copying 'uImage-prog' failed"

# Extract package files to tftp directory
info "Extracting package files to tftp directory..."
tar -C "${ICDTCP3_TFTP_DIR}" -xjf "${package_file}"
test $? -eq 0 || error "Extracting '${package_file}' package files failed"

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
echo "flashing-script-version=${version}" >> "${ICDTCP3_TFTP_DIR}/factory-settings.txt"
echo "flashing-date=`date +'%Y/%m/%d %H:%M %Z'`" >> "${ICDTCP3_TFTP_DIR}/factory-settings.txt"

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
if [ "${prepare_only}" = "no" ]; then
  info "Running sam-ba..."
  sam-ba ${ICDTCP3_SAM_BA_MODEM} at91sam9260-ek ${ICDTCP3_SCRIPTS_DIR}/icdtcp3.tcl
  test $? -eq 0 || error "Running sam-ba failed"
fi

rm "${TMP_FILE}"

exit 0

