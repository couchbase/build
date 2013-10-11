#!/bin/perl
# 
############ 
#use strict;
use warnings;

package buildbotMapping;

use Exporter qw(import);
#use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT      = ();
our @EXPORT_OK   = qw( get_builder get_toy_builder );

our %EXPORT_TAGS = ( DEFAULT => [qw( &get_builder &get_toy_builder )] );

my $DEBUG = 0;   # FALSE

############ 

my $usage="\n".'use:  buildbotMapping::get_builder( platform, bits, branch)'."\n\n"
              .'      plaform   : centos, macosx, windows, ubuntu'."\n"
              .'      bits      : 32, 64'."\n"
              .'      branch    : 2.0.0, 2.0.1, 2.0.2, 2.1.0, 2.1.1, 3.0.0, master'."\n";


my %buildbots = ( "production" => { "centos-5"   => { 32 => { "2.0.0"  =>  "centos-x86-20-builder",
                                                              "2.0.1"  =>  "centos-x86-201-builder",
                                                              "2.0.2"  =>  "centos-x86-202-builder",
                                                              "2.1.0"  =>  "centos-x86-210-builder",
                                                              "2.1.1"  =>  "centos-x86-211-builder",
                                                              "2.2.0"  =>  "centos-5-x86-220-builder",
                                                              "2.2.1"  =>  "centos-5-x86-221-builder",
                                                              "3.0.0"  =>  "centos-5-x86-300-builder",
                                                              "master" =>  "centos-5-x86-master-builder",
                                                            },
                                                      64 => { "2.0.0"  =>  "centos-x64-20-builder",
                                                              "2.0.1"  =>  "centos-x64-201-builder",
                                                              "2.0.2"  =>  "centos-x64-202-builder",
                                                              "2.1.0"  =>  "centos-x64-210-builder",
                                                              "2.1.1"  =>  "centos-x64-211-builder",
                                                              "2.2.0"  =>  "centos-5-x64-220-builder",
                                                              "2.2.1"  =>  "centos-5-x64-221-builder",
                                                              "3.0.0"  =>  "centos-5-x64-300-builder",
                                                              "master" =>  "centos-5-x64-master-builder",
                                                            },
                                                    },
                                     "centos-6"  => { 32 => { "master" =>  "centos-6-x86-master-builder",
                                                              "3.0.0"  =>  "centos-6-x86-300-builder",
                                                              "2.2.1"  =>  "centos-6-x86-221-builder",
                                                              "2.2.0"  =>  "centos-6-x86-220-builder",
                                                            },
                                                      64 => { "master" =>  "centos-6-x64-master-builder",
                                                              "3.0.0"  =>  "centos-6-x64-300-builder",
                                                              "2.2.1"  =>  "centos-6-x64-221-builder",
                                                              "2.2.0"  =>  "centos-6-x64-220-builder",
                                                            },
                                                    },
                                     "macosx"  => { 64 => { "2.0.0"  =>  "mac-x64-20-builder",
                                                            "2.0.1"  =>  "mac-x64-201-builder",
                                                            "2.0.2"  =>  "mac-x64-202-builder",
                                                            "2.1.0"  =>  "mac-x64-210-builder",
                                                            "2.1.1"  =>  "mac-x64-211-builder",
                                                            "2.2.0"  =>  "mac-x64-220-builder",
                                                            "2.2.1"  =>  "mac-x64-221-builder",
                                                            "3.0.0"  =>  "mac-x64-300-builder",
                                                            "master" =>  "mac-x64-master-bldr",
                                                          },
                                                  },
                                     "ubuntu-1004"  => { 32 => { "2.0.0"  =>  "ubuntu-x86-20-builder",
                                                                 "2.0.1"  =>  "ubuntu-x86-201-builder",
                                                                 "2.0.2"  =>  "ubuntu-x86-202-builder",
                                                                 "2.1.0"  =>  "ubuntu-x86-210-builder",
                                                                 "2.1.1"  =>  "ubuntu-x86-211-builder",
                                                                 "2.2.0"  =>  "ubuntu-1004-x86-220-builder",
                                                                 "2.2.1"  =>  "ubuntu-1004-x86-221-builder",
                                                                 "3.0.0"  =>  "ubuntu-1004-x86-300-builder",
                                                                 "master" =>  "ubuntu-1004-x86-master-builder",
                                                               },
                                                         64 => { "2.0.0"  =>  "ubuntu-x64-20-builder",
                                                                 "2.0.1"  =>  "ubuntu-x64-201-builder",
                                                                 "2.0.2"  =>  "ubuntu-x64-202-builder",
                                                                 "2.1.0"  =>  "ubuntu-x64-210-builder",
                                                                 "2.1.1"  =>  "ubuntu-x64-211-builder",
                                                                 "2.2.0"  =>  "ubuntu-1004-x64-220-builder",
                                                                 "2.2.1"  =>  "ubuntu-1004-x64-221-builder",
                                                                 "3.0.0"  =>  "ubuntu-1004-x64-300-builder",
                                                                 "master" =>  "ubuntu-1004-x64-master-builder",
                                                               },
                                                       },
                                     "ubuntu-1204"  => { 32 => { "master" =>  "ubuntu-1204-x86-master-builder",
                                                                 "2.2.0"  =>  "ubuntu-1204-x86-220-builder",
                                                                 "2.2.1"  =>  "ubuntu-1204-x86-221-builder",
                                                                 "3.0.0"  =>  "ubuntu-1204-x86-300-builder",
                                                               },
                                                         64 => { "master" =>  "ubuntu-1204-x64-master-builder",
                                                                 "2.2.0"  =>  "ubuntu-1204-x64-220-builder",
                                                                 "2.2.1"  =>  "ubuntu-1204-x64-221-builder",
                                                                 "3.0.0"  =>  "ubuntu-1204-x64-300-builder",
                                                               },
                                                       },
                                     "windows" => { 32 => { "2.0.0"  =>  "cs-win2008-x86-20-builder",
                                                            "2.0.1"  =>  "cs-win2008-x86-20-builder-201",
                                                            "2.0.2"  =>  "cs-win2008-x86-20-builder-202",
                                                            "2.1.0"  =>  "cs-win2008-x86-20-builder-210",
                                                            "2.1.1"  =>  "cs-win2008-x86-20-builder-211",
                                                            "2.2.0"  =>  "cs-win2008-x86-20-builder-220",
                                                            "2.2.1"  =>  "cs-win2008-x86-20-builder-221",
                                                            "3.0.0"  =>  "cs-win2008-x86-20-builder-300",
                                                            "master" =>  "cs-win2008-x86-20-builder-master",
                                                          },
                                                    64 => { "2.0.0"  =>  "cs-win2008-x64-20-builder",
                                                            "2.0.1"  =>  "cs-win2008-x64-20-builder-201",
                                                            "2.0.2"  =>  "cs-win2008-x64-20-builder-202",
                                                            "2.1.0"  =>  "cs-win2008-x64-20-builder-210",
                                                            "2.1.1"  =>  "cs-win2008-x64-20-builder-211",
                                                            "2.2.0"  =>  "cs-win2008-x64-20-builder-220",
                                                            "2.2.1"  =>  "cs-win2008-x64-20-builder-221",
                                                            "3.0.0"  =>  "cs-win2008-x64-20-builder-300",
                                                            "master" =>  "cs-win2008-x64-20-builder-master",
                                                          },
                                                  },
                                  },
                   "toy"       => { "centos"   => { 64 => { "plabee-211-identical"  =>  "ec2-centos-x64_toy-plabee-211-identical", }},
                                    "windows"  => { 32 => { "plabee-211-identical"  =>  "cs-win-32-toy-builder-toy-plabee-211-identical",
                                                          },
                                                    64 => { "plabee-211-identical"  =>  "cs-win-64-toy-builder-toy-plabee-211-identical",
                                                  }       }
                                  }
               );

############   # DEBUG
# use Data::Dumper;
# print Dumper(\%buildbots);
############ 

############                        get_builder ( <platform>, <branch> )
#          
#                                   returns (production) buildbot builder name
sub get_builder
    {
    my ($platform, $bits, $branch) = @_;
    if ($DEBUG)  { print "\n".'...checking platform >>'.$platform.'<<'."\n"; }
    if (! defined( $buildbots{"production"}{$platform} ))
        {
        print 'unsupported platform >>'.$platform.'<<'."\n";
        die $usage;
        }
    if ($DEBUG)  { print "\n".'...checking bit-width >>'.$bits.'<<'."\n"; }
    if (! defined( $buildbots{"production"}{$platform}{$bits} ))
        {
        print 'unsupported bit-width >>'.$bits.'<<'."\n";
        die $usage;
        }
    if ($DEBUG)  { print "\n".'...checking branch >>'.$branch.'<<'."\n"; }
    if (! defined( $buildbots{"production"}{$platform}{$bits}{$branch} ))
        {
        print 'unsupported branch >>'.$branch.'<<'."\n";
        die $usage;
        }
    return         $buildbots{"production"}{$platform}{$bits}{$branch};
    }


############                        get_toy_builder ( <toy_name>, <platform>, <bits> )
#          
#                                   returns (toy) buildbot builder name
sub get_toy_builder
    {
    my ($toy_name, $platform, $bits) = @_;
    if ($DEBUG)  { print "\n".'...checking platform >>'.$platform.'<<'."\n"; }
    if (! defined( $buildbots{"toy"}{$platform} ))
        {
        print 'unsupported platform >>'.$platform.'<<'."\n";
        die $usage;
        }
    if ($DEBUG)  { print "\n".'...checking bit-width >>'.$bits.'<<'."\n"; }
    if (! defined( $buildbots{"toy"}{$platform}{$bits} ))
        {
        print 'unsupported bit-width >>'.$bits.'<<'."\n";
        die $usage;
        }
    if ($DEBUG)  { print "\n".'...checking toy-name >>'.$toy_name.'<<'."\n"; }
    if (! defined( $buildbots{"toy"}{$platform}{$bits}{$toy_name} ))
        {
        print 'unsupported toy-name >>'.$toy_name.'<<'."\n";
        die $usage;
        }
    return         $buildbots{"toy"}{$platform}{$bits}{$toy_name};
    }


1;
__END__
