#!/usr/bin/perl

# queries jenkins  JSON api to find status of a commit_validation job
#  
#  Call with these parameters:
#  
#    repo          e.g. ep-engine
#    branch        e.g. 300
#  
use warnings;
#use strict;
$|++;

my $DEBUG = 0;


use File::Basename;
use Cwd qw(abs_path);
BEGIN
    {
    $THIS_DIR = dirname( abs_path($0));    unshift( @INC, $THIS_DIR );
    }
my $installed_URL='http://factory.hq.couchbase.com/cgi/show_latest_commit_validation.cgi';

use jenkinsQuery     qw(:DEFAULT );
use jenkinsReports   qw(:DEFAULT);
use buildbotReports  qw(:DEFAULT );

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

sub HTML_pair_cell
    {
    my ($frag_left, $frag_right, $optional_color) = @_;
    my $color_prop = '';
    if( defined( $optional_color) )  {  $color_prop = 'style="background-color:'.$optional_color.';"'; }

    my $HTML = '<table border="0" '.$color_prop.' cellpadding="0" cellspacing="0">'
              .'<tr>'."\n".'<td valign="TOP">'.$frag_left.'</td><td valign="TOP">'.$frag_right.'</td></tr>'."\n"
              .'</table>'."\n";
    return($HTML);
    }


sub print_HTML_Page
    {
    my ($html_elem, $page_title, $color) = @_;
    
    print $query->header;
    print $query->start_html( -title           => $page_title,
                              -BGCOLOR         => $color,
                              '-cache-control' => 'NO-CACHE',
                               -expires        => -1,
                               -pragma         => 'pragma',
                            );
    print '<div style="overflow-x: hidden">'."\n";
    print  $html_elem                       ."\n";
    print '</div>'                          ."\n";
    print $query->end_html;
    }

my $usage = "ERROR: must specify 'repo' and 'branch' params\n\n"
           ."<PRE>"
           ."For example:\n\n"
           ."    $installed_URL?repo=testrunner&branch=300\n\n"
           ."</PRE><BR>"
           ."\n\n";

my ($repo, $branch, $jenkins_job);

if ( $query->param('repo') )
    {
    $repo  = $query->param('repo');
    if ($DEBUG)  { print STDERR "called with 'repo' param: $repo\n"; }
    }
else
    {
    print STDERR "\nmissing parameter: repo\n";
    my $sys_err = HTML_pair_cell( buildbotQuery::html_ERROR_msg($usage), '&nbsp;' );
    
    print_HTML_Page( $sys_err, '&nbsp;', $err_color );
    exit;
    }

if ( $query->param('branch') )
    {
    $branch  = $query->param('branch');
    if ($DEBUG)  { print STDERR "called with 'branch' param: $branch\n"; }
    }
else
    {
    print STDERR "\nmissing parameter: repo\n";
    my $sys_err = HTML_pair_cell( buildbotQuery::html_ERROR_msg($usage), '&nbsp;' );
    
    print_HTML_Page( $sys_err, '&nbsp;', $err_color );
    exit;
    }

$jenkins_job = jenkinsQuery::get_commit_valid( $repo, $branch );
if ($DEBUG)  { print STDERR "\nready to start with repo: ($repo, $branch, $jenkins_job)\n"; }


my ($bldstatus, $bldnum, $rev_numb, $bld_date, $is_running, $gerrit_url, $gerrit_num);


#### S T A R T  H E R E

print STDERR "calling  jenkinsReports::last_commit_valid($jenkins_job, $branch)";

($bldnum, $is_running, $bld_date, $bldstatus, $gerrit_url, $gerrit_num) = jenkinsReports::last_commit_valid($jenkins_job, $branch);
print STDERR "according to last_done_build, is_running = $is_running\n";

my ($jenkins_color, $jenkins_row);

if ($bldnum < 0)
    {
    $jenkins_color = $note_color;
    $jenkins_row   = HTML_pair_cell( jenkinsQuery::html_RUN_link( $jenkins_job, 'no build yet'),
                                     buildbotReports::is_running($is_running),
                                     $jenkins_color                                       );
    }
elsif ($bldstatus)
    {
    $jenkins_color = $good_color;
    $jenkins_row   = HTML_pair_cell( jenkinsQuery::html_OK_link( $jenkins_job, $bldnum, $rev_numb, $bld_date, $gerrit_url, $gerrit_num),
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
    $jenkins_row = HTML_pair_cell( buildbotReports::is_running($is_running),
                                   jenkinsQuery::html_FAIL_link( $jenkins_job, $bldnum, $is_running, $bld_date),
                                   $jenkins_color                                                         );
    }

print_HTML_Page( $jenkins_row, "$jenkins_job ( commit_validation )", $jenkins_color );

# print "\n---------------------------\n";
__END__

