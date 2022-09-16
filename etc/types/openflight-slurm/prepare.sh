#!/bin/bash

if ! command -v ansible &> /dev/null
then
  yum install -y ansible
fi

if [ ! -d openflight-ansible-playbook/.git ]
then
  git clone https://github.com/openflighthpc/openflight-ansible-playbook
fi
cd openflight-ansible-playbook
git pull
git checkout dev/node-at-a-time
