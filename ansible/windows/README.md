The ConfigureForAnsible.ps1 script must be run on a Windows Server 2012 R2
slave (or probably other Windows versions) to enable WinRM remote control.
This is the only thing necessary to allow Ansible to run. Run with:

    ConfigureForAnsible.ps1 -SkipNetworkProfileCheck -ForceNewSSLCert

This script was originally from

    http://docs.ansible.com/ansible/intro_windows.html#windows-system-prep

I have hacked it to always use the local `New-LegacySelfSignedCert` function
(regardless of the version of PowerShell) and then to set the expiration
date of the new self-signed certificate 10,000 days into the future. This
was necessary because:

1. This script ignores its own `CertValidityDays` argument

2. Windows 2012 R2's version of `New-SelfSignedCertificate` can only create
   a certificate with a 365 day expiration.

