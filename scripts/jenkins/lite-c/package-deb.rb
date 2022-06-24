#!/usr/bin/env ruby

###   ./${PKGR} ${PREFIX} ${PRODUCT} ${PRODUCT_VERSION} ${ARCHITECTURE}
#
require 'rubygems'
require 'fileutils'
require 'rake'
require 'open3'

def get_dependencies()
    command = "objdump -p #{PREFIX}/lib/*/*so* | grep NEEDED |awk \'{print $2}\' |sort |uniq"
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
PREFIX            = ARGV[0] || "./build_release/install"
PRODUCT_BASE      = ARGV[1] || "libcblite"
EDITION           = ARGV[2] || "enterprise"
PRODUCT_VERSION   = ARGV[3] || "1.0-1234"
ARCHITECTURE      = ARGV[4] || `uname -m`.chomp
DEPENDENCIES      = ARGV[5]

RELEASE           = PRODUCT_VERSION.split('-')[0]    # e.g., 1.0
BLDNUM            = PRODUCT_VERSION.split('-')[1]    # e.g., 1234

if EDITION.eql?("community")
    #PRODUCT is libcblite-community
    #libcblite or libcblite-dev should not be installed
    PRODUCT                = "#{PRODUCT_BASE}-#{EDITION}"
    DEV_DEPENDENCIES       = "libcblite-#{EDITION} (= #{PRODUCT_VERSION}),libc6-dev"
    OTHER_PRODUCTS         = "#{PRODUCT_BASE}"
else
    #PRODUCT is libcblite or libcblite-dev for EE
    #libcblite-community or libcblite-dev community should not be installed
    PRODUCT                = "#{PRODUCT_BASE}"
    DEV_DEPENDENCIES       = "libcblite (= #{PRODUCT_VERSION}),libc6-dev"
    OTHER_PRODUCTS         = "#{PRODUCT_BASE}-community"
end

sh %{echo "Packaging #{PRODUCT} for #{ARCHITECTURE}"}

STARTDIR  = Dir.getwd()
STAGE_DIR = "#{STARTDIR}/build/deb/#{PRODUCT}_#{RELEASE}"

FileUtils.rm_rf STAGE_DIR

FileUtils.mkdir_p "#{STAGE_DIR}/usr"
FileUtils.mkdir_p "#{STAGE_DIR}/debian"
FileUtils.mkdir_p "#{STAGE_DIR}/usr/share/doc/#{PRODUCT}"

# Prune or otherwise tweak the payload, depending on whether this
# is the -dev or base package, and compute the required dependencies
if PRODUCT_BASE.eql?("libcblite")
    system("cp -rPp #{PREFIX}/lib #{STAGE_DIR}/usr")
    #remove libcblite.so and unnecessary subdirectories
    system("rm -f #{STAGE_DIR}/usr/lib/*/libcblite.so")
    system("rm -rf #{STAGE_DIR}/usr/lib/*/*/")
    CUSTOM_DEPENDENCIES="#{DEPENDENCIES}"
else
    system("cp -rPp #{PREFIX}/include #{STAGE_DIR}/usr")
    system("cp -rPp #{PREFIX}/lib #{STAGE_DIR}/usr")
    system("rm -f #{STAGE_DIR}/usr/lib/*/libcblite.so.*")
    CUSTOM_DEPENDENCIES="#{DEV_DEPENDENCIES}"
end

system("cp -rPp #{PREFIX}/LICENSE.txt #{STAGE_DIR}/usr/share/doc/#{PRODUCT}/.")
system("cp -rPp #{PREFIX}/notices.txt #{STAGE_DIR}/usr/share/doc/#{PRODUCT}/.")

puts "dependencies: " + CUSTOM_DEPENDENCIES


# Dir.chdir STAGE_DIR do
#   sh %{dh_make -e #{DEBEMAIL} --native --single --packagename #{PKGNAME}}
# end

[["#{STARTDIR}/deb_templates", "#{STAGE_DIR}/debian"]].each do |src_dst|
    Dir.chdir(src_dst[0]) do
        Dir.glob("*.tmpl").each do |x|
            target = "#{src_dst[1]}/#{x.gsub('.tmpl', '')}"
            sh %{sed -e s\/@@VERSION@@\/#{PRODUCT_VERSION}\/g #{x}                  |
                sed -e s\/@@RELEASE@@\/#{RELEASE}\/g                       |
                sed -e s\/@@PRODUCT@@\/#{PRODUCT}\/g                   |
                sed -e s\/@@OTHER_PRODUCTS@@\/#{OTHER_PRODUCTS}\/g                   |
                sed -e 's\/@@CUSTOM_DEPENDENCIES@@\/#{CUSTOM_DEPENDENCIES}\/g'                   |
                sed -e s\/@@ARCHITECTURE@@\/#{ARCHITECTURE}\/g         > #{target}}
            sh %{chmod a+x #{target}}
        end
    end
end

Dir.chdir STAGE_DIR do
    debian_revision = 1
    sh %{dch -b -v #{PRODUCT_VERSION} "Released debian package for version #{PRODUCT_VERSION}"}
    sh %{dpkg-buildpackage -b -uc -a#{ARCHITECTURE}}
end
