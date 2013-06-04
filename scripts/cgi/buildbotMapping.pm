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
our @EXPORT_OK   = qw( get_builder );

our %EXPORT_TAGS = ( DEFAULT => [qw( &get_builder  )] );

my $DEBUG = 0;   # FALSE

############ 

my $usage="\n".'use:  buildbotMapping::get_builder( platform, bits, branch)'."\n\n"
              .'      plaform   : centos, macosx, windows, ubuntu'."\n"
              .'      bits      : 32, 64'."\n"
              .'      branch    : 2.0.0, 2.0.1, 2.0.2, 2.1.0, master'."\n";


my %buildbots = ( "production" => { "centos"   => { 32 => { "2.0.0"  =>  "centos-x86-20-builder",
                                                            "2.0.1"  =>  "centos-x86-201-builder",
                                                            "2.0.2"  =>  "centos-x86-202-builder",
                                                            "2.1.0"  =>  "centos-x86-210-builder",
                                                            "master" =>  "centos-x86-master-builder",
                                                          },
                                                    64 => { "2.0.0"  =>  "centos-x64-20-builder",
                                                            "2.0.1"  =>  "centos-x64-201-builder",
                                                            "2.0.2"  =>  "centos-x64-202-builder",
                                                            "2.1.0"  =>  "centos-x64-210-builder",
                                                            "master" =>  "centos-x64-master-builder",
                                                          },
                                                  },
                                     "macosx"  => { 64 => { "2.0.0"  =>  "mac-x64-20-builder",
                                                            "2.0.1"  =>  "mac-x64-201-builder",
                                                            "2.0.2"  =>  "mac-x64-202-builder",
                                                            "2.1.0"  =>  "mac-x64-210-builder",
                                                            "master" =>  "mac-x64-master-builder",
                                                          },
                                                  },
                                     "ubuntu"  => { 32 => { "2.0.0"  =>  "ubuntu-x86-20-builder",
                                                            "2.0.1"  =>  "ubuntu-x86-201-builder",
                                                            "2.0.2"  =>  "ubuntu-x86-202-builder",
                                                            "2.1.0"  =>  "ubuntu-x86-210-builder",
                                                            "master" =>  "ubuntu-x86-master-builder",
                                                          },
                                                    64 => { "2.0.0"  =>  "ubuntu-x64-20-builder",
                                                            "2.0.1"  =>  "ubuntu-x64-201-builder",
                                                            "2.0.2"  =>  "ubuntu-x64-202-builder",
                                                            "2.1.0"  =>  "ubuntu-x64-210-builder",
                                                            "master" =>  "ubuntu-x64-master-builder",
                                                          },
                                                  },
                                     "windows" => { 32 => { "2.0.0"  =>  "cs-win2008-x86-20-builder",
                                                            "2.0.1"  =>  "cs-win2008-x86-20-builder-201",
                                                            "2.0.2"  =>  "cs-win2008-x86-20-builder-202",
                                                            "2.1.0"  =>  "cs-win2008-x86-20-builder-210",
                                                            "master" =>  "cs-win2008-x86-20-builder-master",
                                                          },
                                                    64 => { "2.0.0"  =>  "cs-win2008-x64-20-builder",
                                                            "2.0.1"  =>  "cs-win2008-x64-20-builder-201",
                                                            "2.0.2"  =>  "cs-win2008-x64-20-builder-202",
                                                            "2.1.0"  =>  "cs-win2008-x64-20-builder-210",
                                                            "master" =>  "cs-win2008-x64-20-builder-master",
                                                          },
                                                  },
                                  },
                   "test" => 0,
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

1;
__END__
