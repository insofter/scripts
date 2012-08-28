#!/bin/bash

DATE=`date +%Y.%m.%d__%H-%M-%S`

cd /home/insofter/projects/buildroot
git checkout icdtcp3-2011.11

echo "pwd: `pwd`" 2>&1 | tee -a ../night_${DATE}.all.log


#log circulate
mv ../night_*.log ../night.log/
ssh pmika@cattus.info "mv ~/logs/night* ~/logs/_old/; date > ~/logs/start"



#przenosimy stary output
if [ -e output ] 
then
  mkdir -p __outputs
  if [ -e output/_about_me ]
  then
    mv output __outputs/`cat output/_about_me`
    echo output __outputs/`cat output/_about_me` 2>&1 | tee -a ../night_${DATE}.all.log
  else
    mv output __outputs/moved_at__${DATE}
    echo output __outputs/moved_at__${DATE} 2>&1 | tee -a ../night_${DATE}.all.log
  fi
fi


mkdir output
echo -e ${DATE}__`git log --format=%s -1 | sed 's/ /_/g; s/[^a-zA-Z0-9_]//g; s/__/_/g'` \
  >> output/_about_me



#kompilujemy całość do błedu z getsem
echo "make_1 start: `date +%Y.%m.%d__%H-%M-%S`" 2>&1 | tee -a ../night_${DATE}.all.log
make 2>&1 | tee ../night_${DATE}.make_1.log

if [ ${PIPESTATUS[0]} -eq 0 ] #jesli 1 make nie poszło to próbujemy naprawic getsa i puszczamy jeszcze raz
then
  echo OK >> ../night_${DATE}.all.log 
  echo "make_1 end: `date +%Y.%m.%d__%H-%M-%S`" 2>&1 | tee -a ../night_${DATE}.all.log

else

  echo ERR >> ../night_${DATE}.all.log
  echo "make_1 end: `date +%Y.%m.%d__%H-%M-%S`" 2>&1 | tee -a ../night_${DATE}.all.log


  sudo beep -l 1000
  sleep 1

  #poprawiamy getsa (workaround)
  cat output/build/host-m4-1.4.15/lib/stdio.in.h | grep -v 'undef gets' \
    | grep -v 'gets is a security hole' > .tmp.stdio.h
  echo  "cat output/build/host-m4-1.4.15/lib/stdio.in.h | grep -v 'undef gets' \
    | grep -v 'gets is a security hole' > .tmp.stdio.h" >> ../night_${DATE}.all.log
  mv .tmp.stdio.h output/build/host-m4-1.4.15/lib/stdio.in.h
  echo "mv .tmp.stdio.h output/build/host-m4-1.4.15/lib/stdio.in.h" >> ../night_${DATE}.all.log

  sudo beep -l 1000


  #kompilujemy dalej
  echo "make_2 start: `date +%Y.%m.%d__%H-%M-%S`" 2>&1 | tee -a ../night_${DATE}.all.log
  make 2>&1 | tee ../night_${DATE}.make_2.log ; test ${PIPESTATUS[0]} -eq 0 && echo OK \
    >> ../night_${DATE}.all.log || echo ERR >> ../night_${DATE}.all.log
  echo "make_2 end: `date +%Y.%m.%d__%H-%M-%S`" 2>&1 | tee -a ../night_${DATE}.all.log

fi #koniec proby naprawiania



#budujemy pakiet
echo "make_relpkg start: `date +%Y.%m.%d__%H-%M-%S`" 2>&1 | tee -a ../night_${DATE}.all.log
make relpkg 2>&1 | tee ../night_${DATE}.make_relpkg.log ; test ${PIPESTATUS[0]} -eq 0 \
  && echo OK :: DONE :: ${DATE} >> ../night_${DATE}.all.log || echo ERR >> ../night_${DATE}.all.log
echo "make_relpkg end: `date +%Y.%m.%d__%H-%M-%S`" 2>&1 | tee -a ../night_${DATE}.all.log


echo -e "END\nstart: ${DATE}\nend: `date +%Y.%m.%d__%H-%M-%S`" 2>&1 | tee -a ../night_${DATE}.all.log

echo -e ${DATE}

echo -e "ls -lah output/images/\n`ls -la output/images/`" | tee -a ../night_${DATE}.all.log

sudo beep -l 1000
sleep 1
sudo beep -l 1000
sleep 1
sudo beep -l 1000
sleep 1
sudo beep -l 1000



ssh pmika@cattus.info "rm ~/logs/start"
scp ../night_${DATE}.* pmika@cattus.info:logs/


sleep 30

sudo shutdown -h now
