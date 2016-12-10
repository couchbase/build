#!/bin/bash

mkdir ~/.ssh
echo 'StrictHostKeyChecking no' > ~/.ssh/config
ansible-playbook -v -i /mnt/inventory /mnt/slave-setup/slave-setup.yml

