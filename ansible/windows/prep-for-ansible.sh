#!/bin/bash -ex

host=$1
passwordfile=./password.txt

sshpass -f $passwordfile scp -o StrictHostKeyChecking=no ConfigureForAnsible.ps1 Administrator@$host:
sshpass -f $passwordfile ssh -o StrictHostKeyChecking=no Administrator@$host powershell.exe -File ConfigureForAnsible.ps1 -SkipNetworkProfileCheck -ForceNewSSLCert
