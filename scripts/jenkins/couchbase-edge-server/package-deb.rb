#!/usr/bin/env ruby

####    /${PKGR} ${SOURCE} ${PRODUCT} ${PRODUCT_VERSION} ${ARCH}

require 'rubygems'
require 'fileutils'
require 'rake'

PRODUCT_BASE    = "couchbase"

STARTDIR  = Dir.getwd()

SOURCE          = ARGV[0] || "#{STARTDIR}/couchbase-edge-server"
PRODUCT         = ARGV[1] || "#{PRODUCT_BASE}-edge-server"
PRODUCT_VERSION = ARGV[2] || "1.0.0-1234"
ARCH            = ARGV[3] || `uname -m`.chomp

VERSION         = PRODUCT_VERSION.split('-')[0]    # e.g., 1.0.0
BLDNUM          = PRODUCT_VERSION.split('-')[1]    # e.g., 1234
PKGNAME         ="#{PRODUCT}_#{VERSION}"
PREFIX          ="/opt/#{PRODUCT}"

sh %{echo "Packaging #{PRODUCT} for #{ARCH}"}
STAGE_DIR = "#{STARTDIR}/build/deb/#{PKGNAME}-#{BLDNUM}"
FileUtils.rm_rf   "#{STAGE_DIR}"
FileUtils.mkdir_p "#{STAGE_DIR}"
FileUtils.mkdir_p "#{STAGE_DIR}/debian"
FileUtils.mkdir_p "#{STAGE_DIR}/opt"

[["#{STARTDIR}/deb_templates", "#{STAGE_DIR}/debian"]].each do |src_dst|
    Dir.chdir(src_dst[0]) do
        Dir.glob("*.tmpl").each do |x|
            target = "#{src_dst[1]}/#{x.gsub('.tmpl', '')}"
            sh %{sed -e s,@@PRODUCT_VERSION@@,#{PRODUCT_VERSION},g           #{x} |
                 sed -e s,@@PREFIX@@,#{PREFIX},g                          |
                 sed -e s,@@PRODUCT@@,#{PRODUCT},g                        |
                 sed -e s,@@PRODUCT_BASE@@,#{PRODUCT_BASE},g > #{target}}
            sh %{chmod a+x #{target}}
        end
    end
end

sh %{cp -R "#{SOURCE}" "#{STAGE_DIR}/opt/"}

Dir.chdir STAGE_DIR do
  sh %{dpkg-buildpackage -b -uc}
end
