#!/usr/bin/env ruby

####    ./${PKGR} ${SOURCE} ${PRODUCT} ${PRODUCT_VERSION} ${ARCH}

require 'rubygems'
require 'fileutils'
require 'rake'

PRODUCT_BASE    = "couchbase"
START_DIR  = Dir.getwd()

SOURCE          = ARGV[0] || "#{STARTDIR}/couchbase-edge-server"
PRODUCT         = ARGV[1] || "couchbase-edge-server"
PRODUCT_VERSION = ARGV[2] || "1.0-1234"
ARCH            = ARGV[5] || `uname -m`.chomp

VERSION         = PRODUCT_VERSION.split('-')[0]    # e.g., 1.0.0
BLDNUM          = PRODUCT_VERSION.split('-')[1]    # e.g., 1234
PKGNAME="#{PRODUCT}_#{VERSION}-#{BLDNUM}"
PREFIX          ="/opt/#{PRODUCT}"

STAGE_DIR = "#{START_DIR}/build/rpm/#{PKGNAME}"
FileUtils.rm_rf "#{STAGE_DIR}/rpmbuild"
FileUtils.mkdir_p "#{STAGE_DIR}/rpmbuild/SOURCES"
FileUtils.mkdir_p "#{STAGE_DIR}/rpmbuild/BUILD"
FileUtils.mkdir_p "#{STAGE_DIR}/rpmbuild/BUILDROOT"
FileUtils.mkdir_p "#{STAGE_DIR}/rpmbuild/RPMS/#{ARCH}"


[["#{START_DIR}/rpm_templates", "#{STAGE_DIR}" ]].each do |src_dst|
    Dir.chdir(src_dst[0]) do
        Dir.glob("rpm*.tmpl").each do |x|
            target = "#{src_dst[1]}/#{x.gsub('.tmpl', '')}"
            sh %{sed -e s,@@VERSION@@,#{VERSION},g                   #{x} |
                 sed -e s,@@RELEASE@@,#{BLDNUM},g                          |
                 sed -e s,@@PREFIX@@,#{PREFIX},g                          |
                 sed -e s,@@PRODUCT@@,#{PRODUCT},g                        |
                 sed -e s,@@PRODUCT_BASE@@,#{PRODUCT_BASE},g > #{target}}
            sh %{chmod a+x #{target}}
        end
    end
end

sh %{cp -R "#{START_DIR}/service/#{PRODUCT}.service" "#{STAGE_DIR}/rpmbuild/SOURCES"}
Dir.chdir("#{START_DIR}") do
    sh %{tar --directory #{File.dirname(SOURCE)} -czf "#{STAGE_DIR}/rpmbuild/SOURCES/#{PRODUCT}_#{VERSION}.tar.gz" #{File.basename(SOURCE)}}
end
Dir.chdir("#{STAGE_DIR}") do
    sh %{rpmbuild -bb --define "_topdir #{STAGE_DIR}/rpmbuild" rpm.spec}
end
