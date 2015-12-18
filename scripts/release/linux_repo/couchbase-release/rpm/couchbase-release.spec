Name:           couchbase-release
Version:        1.0
Release:        0
Summary:        Entry point rpm for accesing couchbase yum repository

Group:          System Environment/Base
License:        Apache
URL:            http://www.couchbase.com
Source0:        GPG-KEY-COUCHBASE-1.0
Source1:        couchbase-Base.repo

BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)

BuildArch:     noarch

%description
A package that configures access to couchbase yum repository.

%prep
%setup -q  -c -T
install -pm 644 %{SOURCE0} .
install -pm 644 %{SOURCE1} .

%build


%install
rm -rf $RPM_BUILD_ROOT
install -Dpm 644 %{SOURCE0} \
    $RPM_BUILD_ROOT%{_sysconfdir}/pki/rpm-gpg/GPG-KEY-COUCHBASE-1.0

install -dm 755 $RPM_BUILD_ROOT%{_sysconfdir}/yum.repos.d
install -pm 644 %{SOURCE1} $RPM_BUILD_ROOT%{_sysconfdir}/yum.repos.d

%clean
rm -rf $RPM_BUILD_ROOT

%post
if grep -q -i "release 6" /etc/redhat-release >/dev/null 2>&1
then
  sed -e "s/%VERSION%/6.2/g" -i /etc/yum.repos.d/couchbase-Base.repo
else
  sed -e "s/%VERSION%/\$releasever/g" -i /etc/yum.repos.d/couchbase-Base.repo
fi

%postun

%files
%defattr(-,root,root,-)
%config(noreplace) /etc/yum.repos.d/*
/etc/pki/rpm-gpg/*

%changelog
* Thu May 07 2015 Hari Kodungallur <hari.kodungallur@couchbase.com>
- Initial release
