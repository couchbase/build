#!/usr/bin/perl

# queries jenkins  JSON api to find status of a couchbase-server builder
#  
#  Call with these parameters:
#  
#    OS              e.g. windows
#    ARCH            32, 64
#    BRANCH          e.g. master
#  
use warnings;
#use strict;
$|++;

my $DEBUG = 1;


use File::Basename;
use Cwd qw(abs_path);
BEGIN
    {
    $THIS_DIR = dirname( abs_path($0));    unshift( @INC, $THIS_DIR );
    }
my $installed_URL='http://factory.hq.couchbase.com/cgi/show_latest_server.cgi';


use jenkinsQuery    qw(:DEFAULT);
use jenkinsReports  qw(:DEFAULT);
use buildbotReports qw(:DEFAULT);
use htmlReports     qw(:DEFAULT);

use CGI qw(:standard);
my  $query = new CGI;

#my $delay = 2 + int rand(5.3);    sleep $delay;

my ($good_color, $warn_color, $err_color, $note_color) = ('#CCFFDD', '#FFFFCC', '#FFAAAA', '#CCFFFF');

my $timestamp = "";
sub get_timestamp
    {
    my $timestamp;
    my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    $month =    1 + $month;
    $year  = 1900 + $yearOffset;
    $timestamp = "page generated $hour:$minute:$second  on $year-$month-$dayOfMonth";
    }

my $usage = "ERROR: must specify 'os', 'arch', and 'branch' parameters\n\n"
           ."<PRE>"
           ."For example:\n\n"
           ."    $installed_URL?branch=master&os=windows&arch=32\n\n"
           ."</PRE><BR>"
           ."\n\n";

my ($jenkins_builder, $os, $arch, $branch);

if ( $query->param('branch') && $query->param('os') && $query->param('arch')  )
    {
    $os      = $query->param('os');
    $arch    = $query->param('arch');
    $branch  = $query->param('branch');
    if ($DEBUG)                { print STDERR "called with ( $os, $arch, $branch)\n"; }
    $jenkins_builder  =    jenkinsQuery::get_server_builder( $os, $arch, $branch );
    if ($DEBUG)                { print STDERR "\nready to start with: $jenkins_builder\n"; }
    }
else
    {
    print STDERR "\nmissing parametern";
    my $sys_err = htmlReports::HTML_pair_cell( buildbotQuery::html_ERROR_msg($usage), '&nbsp;' );
    
    htmlReports::print_HTML_Page( $query, $sys_err, '&nbsp;', $err_color );
    exit;
    }



my ($bldstatus, $bldnum, $rev_numb, $bld_date, $is_running);


########   S T A R T   H E R E 


print STDERR "calling  jenkinsReports::last_done_repo(".$branch.")";

($bldnum, $is_running, $bld_date, $bldstatus) = jenkinsReports::last_done_repo($branch);
print STDERR "according to last_done_build, is_running = $is_running\n";

my ($jenkins_color, $jenkins_row);

if ($bldnum < 0)
    {
    $jenkins_color = $note_color;
    $jenkins_row   = htmlReports::HTML_pair_cell( jenkinsQuery::html_RUN_link( $jenkins_builder, 'no build yet'),
                                     buildbotReports::is_running($is_running),
                                     $jenkins_color                                       );
    }
elsif ($bldstatus)
    {
    $jenkins_color = $good_color;
    $jenkins_row   = htmlReports::HTML_pair_cell( jenkinsQuery::html_OK_link( $jenkins_builder, $bldnum, $rev_numb, $bld_date),
                                     buildbotReports::is_running($is_running),
                                     $jenkins_color                                                     );
    print STDERR "GOOD: $bldnum\n"; 
    }
else
    {
    print STDERR "FAIL: $bldnum\n"; 
   
    if ( $is_running == 1 )
        {
        $bldnum += 1;
        $jenkins_color = $warn_color;
        }
    else
        {
        $jenkins_color = $err_color;
        }
    $jenkins_row = htmlReports::HTML_pair_cell( buildbotReports::is_running($is_running),
                                   jenkinsQuery::html_FAIL_link( $jenkins_builder, $bldnum, $is_running, $bld_date),
                                   $jenkins_color                                                         );
    }



htmlReports::print_HTML_Page(  $query, $jenkins_row,  "$branch Repo Builder Status",  $buildbot_color );

# print "\n---------------------------\n";
__END__

