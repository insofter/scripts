#!/bin/bash


cd /home/insofter/projects/icd

if git status | grep  -q "nothing to commit" 
then
  git push
else
  echo Commit icd!
fi


cd /home/insofter/projects/buildroot

if git checkout icdtcp3-2011.11 && git status | grep  -q "nothing to commit"
then
  git push
else
  echo Commit buildroot!
fi

cd /home/insofter/projects/scripts

if git status | grep  -q "nothing to commit"
then
  git push
else
  echo Commit scripts!
fi


cd /home/insofter/projects/factory

if git status | grep  -q "nothing to commit"
then
  git push
else
  echo Commit factory!
fi
