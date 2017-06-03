#!/bin/bash -ex

host=$1
passwordfile=./password.txt

sshpass -f $2 scp -o StrictHostKeyChecking=no ConfigureForAnsible.ps1 Administrator@$host:
sshpass -f $2 ssh -o StrictHostKeyChecking=no Administrator@$host powershell.exe -File ConfigureForAnsible.ps1 -SkipNetworkProfileCheck -ForceNewSSLCert
