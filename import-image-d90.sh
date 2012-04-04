#!/bin/bash

PROGRAM_NAME="import-image-d90"
DST_BASE="${HOME}/Pictures/raw/d90"

function error()
{
  if [ -n "$1" ] ; then
    echo "Error! $1"
  fi
  echo "Error! ${PROGRAM_NAME} halted."
  exit 1
}

function check_empty()
{
  if [ -z "$1" ] ; then
    error "$2"
  fi
}

function check_error()
{
  if [ $? != 0 ] ; then
    error "$1"
  fi
}


for FILE in "$@"
do

  TYPE=`echo ${FILE##*.} | tr '[:upper:]' '[:lower:]'`

  if [ "${TYPE}" == "jpg" ] ; then

    EXIF_DATETIME=`exif -t=DateTime "${FILE}" | sed -n s/[[:space:]][[:space:]]*Value:[[:space:]][[:space:]]*//p`
    check_empty "${EXIF_DATETIME}" "'${FILE}': extracting datetime failed."

    EXIF_DATE=`echo ${EXIF_DATETIME} | cut -d " " -f 1 | sed s/:/-/g`
    check_empty "${EXIF_DATE}" "'${FILE}': extracting datetime failed."

    EXIF_TIME=`echo ${EXIF_DATETIME} | cut -d " " -f 2`
    check_empty "${EXIF_TIME}" "'${FILE}': extracting datetime failed."

    DATETIME=`date -d "${EXIF_DATE} ${EXIF_TIME} +0000"`
    check_empty "${DATETIME}" "'${FILE}': extracting datetime failed."

  elif [ ${TYPE} == "nef" ] ; then

    RAW_DATETIME=`dcraw -v -i "${FILE}" | sed -n "s/Timestamp: //p"`
    check_empty "${RAW_DATETIME}" "'${FILE}': extracting datetime failed."
  
    DATETIME=`date -d "${RAW_DATETIME} UTC"`
    check_empty "${DATETIME}" "'${FILE}': extracting datetime failed."

  else

    error "'${FILE}': unsupported file format."

  fi

  BASE_NAME=`basename "${FILE}" | tr '[:upper:]' '[:lower:]'`
  YEAR=`date -u -d "${DATETIME}" +%Y`
  MONTH=`date -u -d "${DATETIME}" +%m`
  PREFIX=`date -u -d "${DATETIME}" +%Y-%m-%d-%H-%M-%S`
  DST_DIR="${DST_BASE}/${YEAR}/${MONTH}"
  DST_PATH="${DST_DIR}/${PREFIX}-${BASE_NAME}"

#  echo "DATETIME : ${DATETIME}"
#  echo "TYPE : ${TYPE}"
#  echo "BASE_NAME : ${BASE_NAME}"
#  echo "YEAR : ${YEAR}"
#  echo "MONTH : ${MONTH}"
#  echo "PREFIX : ${PREFIX}"
#  echo "DST_DIR : ${DST_DIR}"
#  echo "DST_PATH : ${DST_PATH}"

  mkdir -v -p "${DST_DIR}"
  check_error

  cp -v "${FILE}" "${DST_PATH}"
  check_error

  touch -md "${DATETIME}" "${DST_PATH}"
  check_error
done

