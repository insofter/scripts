#!/bin/sh

print_usage()
{
>&2 cat <<EOF

Usage: ${program_name} [-s|--source-dir SOURCE_DIR] [-o|--output-dir OUTPUT_DIR] NAME
  [-h|--help] [-v|--version]

Builds a source package <NAME>-<version>.tar.bz2 for the project
in the current directory. The output directory can be specified
by -o|--output-dir parameter. If the parameter is not provided then
the archive will be placed in the current directory. The script
must be executed from the source top directory.

  -s|--source-dir source code directory
  -o|--output-dir output directory
  -h|--help       show this information
  -v|--version    show version information

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

output_dir=`pwd`
src_dir=`pwd`

options=`getopt -o o:s:hv --long output-dir:,source-dir:,help,version -- "$@"`
test $? -eq 0 || error "Parsing parameters failed"
eval set -- "$options"
while true ; do
  case "$1" in
    -o|--output-dir) output_dir=`eval cd "$2" && pwd`;
       test $? -eq 0 || error "Invalid output directory specified"; shift 2 ;;
    -s|--source-dir) src_dir=`eval cd "$2" && pwd`;
       test $? -eq 0 || error "Invalid source directory specified"; shift 2 ;;
    -h|--help) print_usage; exit 0 ;;
    -v|--version) print_version; exit 0 ;;
    --) shift; break ;;
    *) error "Parsing parameters failed at '$1'" ;;
  esac
done

test "x$1" != "x" || error "Parsing parameters faield. Missing parameter NAME"
prefix=$1; shift 1

test "x$1" = "x" || error "Parsing parameters failed at '$1'"

cd "${src_dir}"
test $? -eq 0 || error "Changing directory to '${src_dir}' failed"

package_version=`git describe --dirty | sed -e 's/^v//' -e 's/+/-/g'`
test -n "${package_version}" || error "Reading version failed"

# Build source package only if does not exist in destination directory;
# with the exception that always build dirty (=with local changes) packages
dirty=`cat "${package_version}" | grep -o "dirty"`
if [ ! -f "${output_dir}/${prefix}-${package_version}.tar.bz2" -o "x${dirty}" != "x" ]; then
  temp_dir=`mktemp -d`
  test $? -eq 0 || error "Creating temporary directory '${temp_dir}' failed"
  export_dir="${temp_dir}/${prefix}-${package_version}"
  mkdir -p "${export_dir}"
  test $? -eq 0 || error "Creating '${export_dir}' directory failed"

  info "Preparing source directory tree..."
  rsync -a --exclude=.git* --exclude=/make-*sh ./ "${export_dir}"
  test $? -eq 0 || error "Copying package files failed"

  info "Updating package version information..."
  ./make-version.sh "${src_dir}" "${export_dir}"
  test $? -eq 0 || error "Runnikg make-version.sh failed"

  info "Creating archive ${prefix}-${package_version}.tar.bz2..."
  cd "${temp_dir}"
  test $? -eq 0 || error "Changing directory to '${output_dir}' failed"
  tar -cjf "${output_dir}/${prefix}-${package_version}.tar.bz2" "${prefix}-${package_version}"
  test $? -eq 0 || \
    error "Creating bzipped tar archive '${output_dir}/${prefix}-${package_version}.tar.bz2' failed"

  rm -R "${temp_dir}"
else
  info "Package up to date"
fi

info "Done"

exit 0

