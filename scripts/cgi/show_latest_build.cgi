#!/usr/bin/perl

# queries buildbot JSON api to find latest good build of a specific builder.
#  
#  Call with these parameters:
#  
#  BUILDER         e.g. cs-win2008-x64-20-builder-202
#  BRANCH          e.g. 2.0.2.  NOTE: must match!
#  
use warnings;
#use strict;
$|++;

use File::Basename;
use Cwd qw(abs_path);
BEGIN
    {
    $THIS_DIR = dirname( abs_path($0));
    print "THIS_DIR is $THIS_DIR\n";
    unshift( @INC, $THIS_DIR );
    }

use buildbotQuery   qw(:HTML :JSON );
use buildbotMapping qw(:DEFAULT);
use buildbotReports qw(:DEFAULT);

use CGI qw(:standard);
my  $query = new CGI;

sub print_HTML_Page
    {
    my ($fragment) = @_;
    
    print $query->header;
    print $query->start_html;
    print "\n".$fragment."\n";
    print $query->end_html;
    }
my $installed_URL='http://10.3.2.199/cgi-bin/build/scripts/cgi/show_latest_build.cgi';

my $usage = "ERROR: must specify  EITHER both 'builder' and 'branch' params\n"
           ."                         OR all of 'platform', 'bits', 'branch'\n\n"
           ."<PRE>"
           ."For example:\n\n"
           ."    $installed_URL?builder=cs-win2008-x64-20-builder-202&branch=2.0.2\n\n"
           ."    $installed_URL?platform=windows&bits=64&branch=2.0.2\n\n"
           ."<PRE>";

my ($builder, $branch);

if ( $query->param('builder') && $query->param('branch') )
    {
    $builder = $query->param('builder');
    $branch  = $query->param('branch');
    }
elsif( ($query->param('platform')) && ($query->param('bits')) && ($query->param('branch')) )
    {
    $branch  = $query->param('branch');
    $builder = buildbotMapping::get_builder( $query->param('platform'), $query->param('bits'), $branch );
    }
else
    {
    print_HTML_Page( buildbotQuery::html_ERROR_msg($usage) );
    exit;
    }

print STDERR "\nready to start with\n($builder, $branch)\n";

#### S T A R T  H E R E 

my ($bldstatus, $bldnum, $rev_numb, $bld_date) = buildbotReports::last_done_build($builder, $branch);

if ($bldstatus)
    {
    print_HTML_Page( buildbotQuery::html_OK_link(   $builder, $bldnum, $rev_numb, $bld_date ) );
    
    print STDERR "GOOD: $bldnum\n"; 
    }
else
    {
    print STDERR "FAIL: $bldnum\n"; 
    
    print_HTML_Page( buildbotQuery::html_FAIL_link( $builder, $bldnum ) );
    }


# print "\n---------------------------\n";
__END__

