#!/usr/bin/perl

use warnings;
#use strict;
$|++;

use File::Basename;
use Cwd qw(abs_path);
BEGIN
    {
    $THIS_DIR = dirname( abs_path($0));
    print STDERR "THIS_DIR is $THIS_DIR\n";
    unshift( @INC, $THIS_DIR );
    }
my $installed_URL='http://10.3.2.199/cgi-bin/build/scripts/cgi/show_latest_good_build.cgi';

use Getopt::Std;

use buildbotQuery   qw(:HTML :JSON );
use buildbotMapping qw(:DEFAULT);
use buildbotReports qw(:DEFAULT);

use CGI qw(:standard);
my  $query = new CGI;

sub print_props_file
    {
    my ($iter, $bnum, $bdat) = @_;
    
    if ($iter >0)
        {
        print "BUILD_COUNTER=$iter\n";
        print "BUILD_NUMBER=$bnum\n";
        print "BUILD_DATE=$bdat\n";
        }
    else
        {
        print "BUILD_COUNTER=$iter\n";
        }
    }

my $usage = "use:  $0 -b builder -r branch, or\n"
           ."         -P platfrom -B bitwidth -R branch\n\n"
           ."<PRE>"
           ."For example:\n\n"
           ."    $installed_URL?builder=cs-win2008-x64-20-builder-202&branch=2.0.2\n\n"
           ."    $installed_URL?platform=windows&bits=64&branch=2.0.2\n\n"
           ."<PRE>";

my ($builder, $branch);
my %options=();
getopts("b:r:P:B:R:",\%options);

if  ( defined $options{b} && defined $options{r} )
    {
    $builder = $options{b};
    $branch  = $options{r};
    }
elsif ( defined $options{P} && defined $options{B} && defined $options{R} )
    {
    my $platform = $options{P};
    my $bitwidth = $options{B};
    $branch      = $options{R};
    $builder     = buildbotMapping::get_builder( $platform, $bitwidth, $branch);
    }
else
    {
    print STDERR "$usage\n";
    exit  99;
    }


print STDERR "\nready to start with\n($builder, $branch)\n";

#### S T A R T  H E R E 

my ($bldnum, $rev_numb, $bld_date) = buildbotReports::last_good_build($builder, $branch);


if ($bldnum)
    {
    print_props_file( $bldnum, $rev_numb, $bld_date );
    
    print STDERR "GOOD: $bldnum\n"; 
    }
else
    {
    print STDERR "FAIL: $bldnum\n"; 
    
    print_props_file( 0 );
    }


# print "\n---------------------------\n";
__END__

