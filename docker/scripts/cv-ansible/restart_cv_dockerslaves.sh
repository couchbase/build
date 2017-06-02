#!/bin/bash

mkdir ~/.ssh
echo 'StrictHostKeyChecking no' > ~/.ssh/config
cd /mnt
ansible-playbook -v -i inventory $* restart_cv_dockerslaves.yml

