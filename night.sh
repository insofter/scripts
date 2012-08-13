#!/bin/bash

DATE=`date +%Y.%m.%d__%H-%M-%S`

cd /home/insofter/projects/buildroot
echo -n "pwd: " 
pwd
echo -n "pwd: " >> ../night_${DATE}.all.log
pwd >> ../night_${DATE}.all.log



if [ -e output ] 
then
  mv output __output__${DATE}
  echo mv output __output__${DATE}
  echo mv output __output__${DATE} >> ../night_${DATE}.all.log
fi



make 2>&1 | tee ../night_${DATE}.make_1.log ; test ${PIPESTATUS[0]} -eq 0
echo "make 2>&1 | tee ../night_${DATE}.make_1.log ; test \${PIPESTATUS[0]} -eq 0" >> ../night_${DATE}.all.log



sudo beep -l 1000
sleep 1

cat output/build/host-m4-1.4.15/lib/stdio.in.h | grep -v 'undef gets' | grep -v 'gets is a security hole' > .tmp.stdio.h
echo  "cat output/build/host-m4-1.4.15/lib/stdio.in.h | grep -v 'undef gets' | grep -v 'gets is a security hole' > .tmp.stdio.h" >> ../night_${DATE}.all.log

mv .tmp.stdio.h output/build/host-m4-1.4.15/lib/stdio.in.h
echo "mv .tmp.stdio.h output/build/host-m4-1.4.15/lib/stdio.in.h" >> ../night_${DATE}.all.log

sudo beep -l 1000



make 2>&1 | tee ../night_${DATE}.make_2.log ; test ${PIPESTATUS[0]} -eq 0
echo "make 2>&1 | tee ../night_${DATE}.make_2.log ; test \${PIPESTATUS[0]} -eq 0" >> ../night_${DATE}.all.log



make relpkg 2>&1 | tee ../night_${DATE}.make_relpkg.log ; test ${PIPESTATUS[0]} -eq 0
echo "make relpkg 2>&1 | tee ../night_${DATE}.make_relpkg.log ; test \${PIPESTATUS[0]} -eq 0" >> ../night_${DATE}.all.log



echo DONE @ ${DATE}
echo DONE @ ${DATE} >> ../night_${DATE}.all.log

sudo beep -l 1000
sleep 1
sudo beep -l 1000
sleep 1
sudo beep -l 1000
sleep 1
sudo beep -l 1000

sleep 30

sudo shutdown -h now
