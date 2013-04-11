#!/bin/perl
# 
############ 
use strict;

package buildbotMapping;

use Exporter qw(import);
#use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT      = ();
our @EXPORT_OK   = qw( get_builder );

our %EXPORT_TAGS = ( DEFAULT => [qw( &get_builder  )] );

############ 

my $usage="\n".'use:  buildbotMapping::get_builder( platform, bits, branch)'."\n\n"
              .'      plaform   : centos, macosx, windows, ubuntu'."\n"
              .'      bits      : 32, 64'."\n"
              .'      branch    : 2.0.0, 2.0.1, 2.0.2, 2.1.0'."\n";


my %buildbots = ( 'production' => ( 'centos'  => ( 32 => (2.0.0 => 'centos-x86-20-builder',
                                                      2.0.1 => 'centos-x64-201-builder',
                                                      2.0.2 => 'centos-x64-202-builder',
                                                      2.1.0 => 'centos-x64-21-builder'),
                                               64 => (2.0.0 => 'centos-x64-20-builder',
                                                      2.0.1 => 'centos-x64-201-builder',
                                                      2.0.2 => 'centos-x64-202-builder',
                                                      2.1.0 => 'centos-x64-21-builder')),
                                  macosx  => ( 64 => (2.0.0 => 'mac-x64-20-builder',
                                                      2.0.1 => 'mac-x64-201-builder',
                                                      2.0.2 => 'mac-x64-202-builder',
                                                      2.1.0 => 'mac-x64-21-builder')),
                                  ubuntu  => ( 32 => (2.0.0 => 'ubuntu-x86-20-builder',
                                                      2.0.1 => 'ubuntu-x86-201-builder',
                                                      2.0.2 => 'ubuntu-x86-202-builder',
                                                      2.1.0 => 'ubuntu-x86-21-builder'),
                                               64 => (2.0.0 => 'ubuntu-x64-20-builder',
                                                      2.0.1 => 'ubuntu-x64-201-builder',
                                                      2.0.2 => 'ubuntu-x64-202-builder',
                                                      2.1.0 => 'ubuntu-x64-21-builder')),
                                  windows => ( 32 => (2.0.0 => 'cs-win2008-x86-20-builder',
                                                      2.0.1 => 'cs-win2008-x86-20-builder-201',
                                                      2.0.2 => 'cs-win2008-x86-20-builder-202',
                                                      2.1.0 => 'cs-win2008-x86-20-builder-21'),
                                               64 => (2.0.0 => 'cs-win2008-x64-20-builder',
                                                      2.0.1 => 'cs-win2008-x64-20-builder-201',
                                                      2.0.2 => 'cs-win2008-x64-20-builder-202',
                                                      2.1.0 => 'cs-win2008-x64-20-builder-21'))
                               )
               );
                
############                        get_builder ( <platform>, <branch> )
#          
#                                   returns (production) buildbot builder name
sub get_builder
    {
    my ($platform, $bits, $branch) = @_;
    if (defined( $buildbots{'production'}{$platform}{$bits}{$branch} ))
        {
        return   $buildbots{'production'}{$platform}{$bits}{$branch};
        }
    die $usage;
    }

1;
__END__
