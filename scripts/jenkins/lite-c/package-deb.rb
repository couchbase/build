#!/usr/bin/env ruby

###   ./${PKGR} ${PREFIX} ${PRODUCT} ${PRODUCT_VERSION} ${ARCHITECTURE}
#
require 'rubygems'
require 'fileutils'
require 'rake'
require 'open3'

def get_dependencies()
    command = "objdump -p #{PREFIX}/lib/*so* | grep NEEDED |awk \'{print $2}\' |sort |uniq"
    dependencies=Array.new

    stdout, stderr, status= Open3.capture3(command)
    if status.success?
        for package in stdout.split(/\n+/)
            case ARCHITECTURE
                when "arm64"
                    cmd = "apt-file search -a #{ARCHITECTURE} #{package}|grep aarch64 |sort -r|head -1|awk -F \":\" \'{print $1}\'"
                when "armhf"
                    cmd = "apt-file search -a #{ARCHITECTURE} #{package}|grep arm-linux-gnueabihf |sort -r|head -1|awk -F \":\" \'{print $1}\'"
                else
                    cmd = "apt-file search -a #{ARCHITECTURE} #{package}|sort -r|head -1|awk -F \":\" \'{print $1}\'"
            end
            out, err, s= Open3.capture3(cmd)
            if s.success?
                puts "Detected dependency #{out.strip} for #{package}"
                dependencies.push(out.strip)
            else
                abort("apt-file error: " + err)
            end
        end
    else
        abort("objdump error: " + stderr)
    end
    return dependencies.uniq.join(",")
end

# Input arguments
PREFIX       = ARGV[0] || "./opt/couchbase-lite-c"
PRODUCT      = ARGV[1] || "couchbase-lite-c"
PRODUCT_VERSION = ARGV[2] || "1.0-1234"
ARCHITECTURE = ARGV[3] || `uname -m`.chomp

RELEASE         = PRODUCT_VERSION.split('-')[0]    # e.g., 1.0
BLDNUM          = PRODUCT_VERSION.split('-')[1]    # e.g., 1234

sh %{echo "PLATFORM is #{ARCHITECTURE}"}


STARTDIR  = Dir.getwd()
STAGE_DIR = "#{STARTDIR}/build/deb/#{PRODUCT}_#{RELEASE}"

FileUtils.rm_rf STAGE_DIR

FileUtils.mkdir_p "#{STAGE_DIR}/usr"
FileUtils.mkdir_p "#{STAGE_DIR}/debian"

CUSTOM_DEPENDENCIES=get_dependencies()
puts "dependencies: " + CUSTOM_DEPENDENCIES

Dir.chdir STAGE_DIR do
# sh %{dh_make -e #{DEBEMAIL} --native --single --packagename #{PKGNAME}}
end

[["#{STARTDIR}/deb_templates", "#{STAGE_DIR}/debian"]].each do |src_dst|
    Dir.chdir(src_dst[0]) do
        Dir.glob("*.tmpl").each do |x|
            target = "#{src_dst[1]}/#{x.gsub('.tmpl', '')}"
            sh %{sed -e s\/@@VERSION@@\/#{PRODUCT_VERSION}\/g #{x}                  |
                sed -e s\/@@RELEASE@@\/#{RELEASE}\/g                       |
                sed -e s\/@@PRODUCT@@\/#{PRODUCT}\/g                   |
                sed -e s\/@@CUSTOM_DEPENDENCIES@@\/#{CUSTOM_DEPENDENCIES}\/g                   |
                sed -e s\/@@ARCHITECTURE@@\/#{ARCHITECTURE}\/g         > #{target}}
            sh %{chmod a+x #{target}}
        end
    end
end

if PRODUCT.eql?("libcblite")
    system("cp -rp #{PREFIX}/lib #{STAGE_DIR}/usr")
    #remove libcblite.so and unnecessary subdirectories
    system("rm -f #{STAGE_DIR}/usr/lib/*/libcblite.so")
    system("rm -rf #{STAGE_DIR}/usr/lib/*/*/")
else
    system("cp -rp #{PREFIX}/lib #{STAGE_DIR}/usr")
    system("cp -rp #{PREFIX}/include #{STAGE_DIR}/usr")
end

Dir.chdir STAGE_DIR do
    debian_revision = 1
    sh %{dch -b -v #{PRODUCT_VERSION} "Released debian package for version #{PRODUCT_VERSION}"}
    sh %{dpkg-buildpackage -b -uc -a#{ARCHITECTURE}}
end
