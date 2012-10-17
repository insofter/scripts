#!/bin/bash

FILE=/tmp/night-poweroff


if [ -e ${FILE} ]
then
  echo "Auto poweroff is set."
else
  echo "Auto poweroff is NOT set."
fi

echo -n "Type \`s' to set, \`u' to unset: "

read z

if [ "$z" == "s" ]
then
  touch ${FILE}
else
  rm -f ${FILE}
fi


if [ -e ${FILE} ]
then
  echo "Now auto poweroff is set."
else
  echo "Now auto poweroff is NOT set."
fi
