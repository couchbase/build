#!/usr/bin/perl

# queries jenkins  JSON api to find status of a repo builder
#         buildbot JSON api to find status of a repo builder
#  
#  Call with this parameter:
#  
#  BRANCH          e.g. 2.5.0
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
my $installed_URL='http://factory.hq.couchbase.com/cgi/show_latest_repo_build.cgi';

use buildbotQuery   qw(:HTML :JSON );
use buildbotMapping qw(:DEFAULT);
use buildbotReports qw(:DEFAULT);

use jenkinsQuery    qw(:DEFAULT );
use jenkinsReports  qw(:DEFAULT);

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

    my $HTML = "\n".'<div style="overflow-x: hidden">'."\n"
              .'<table border="0" '.$color_prop.' cellpadding="0" cellspacing="0"><tr>'."\n".'<td valign="TOP">'.$frag_left.'</td><td valign="TOP">'.$frag_right.'</td></tr>'."\n".'</table>'
              .'</div>'."\n";
    return($HTML);
    }

sub HTML_repo_pair
    {
    my ($branch, $row_top, $row_bot, $optional_color) = @_;
    my $color_prop = '';
    if( defined( $optional_color) )  {  $color_prop = 'style="background-color:'.$optional_color.';"'; }
    
    my $HTML = "\n".'<div style="overflow-x: hidden">'."\n"
              .'<table border="0" '.$color_prop.' cellpadding="0" cellspacing="0">'."\n"
              .'<tr><td valign="LEFT"><H3>'.$branch.'</H3></td></tr>'."\n"
              .'<tr><td valign="TOP">'.$row_top.'</td></tr>'."\n"
              .'<tr><td valign="TOP">'.$row_bot.'</td></tr>'."\n"
              .'</table>'."\n"
              .'</div>'."\n";
    return($HTML);
    }

sub print_HTML_Page
    {
    my ($html_elem, $page_title, $color) = @_;
    
    print $query->header;
    print $query->start_html( -title   => $page_title,
                              -BGCOLOR => $color,
                            );
    print $html_elem."\n";
    print $query->end_html;
    }

my $usage = "ERROR: must specify 'branch' param\n\n"
           ."<PRE>"
           ."For example:\n\n"
           ."    $installed_URL?branch=2.5.0\n\n"
           ."</PRE><BR>"
           ."\n\n";

my ($jenkins_builder, $buildbot_builder, $branch);

if ( $query->param('branch') )
    {
    $branch  = $query->param('branch');
    if ($DEBUG)  { print STDERR "called with 'branch' param: $branch\n"; }
    $jenkins_builder  =    jenkinsQuery::get_repo_builder( $branch );
    $buildbot_builder = buildbotMapping::get_repo_builder( $branch );
    if ($DEBUG)  { print STDERR "\nready to start with repo: ($branch, $jenkins_builder, $jenkins_builder)\n"; }
    }
else
    {
    print STDERR "\nmissing parameter: branch\n";
    my $sys_err = HTML_pair_cell( buildbotQuery::html_ERROR_msg($usage), '&nbsp;' );
    
    print_HTML_Page( $sys_err, '&nbsp;', $err_color );
    exit;
    }



my ($bldstatus, $bldnum, $rev_numb, $bld_date, $is_running);
my ($jenkins_row,   $buildbot_row);
my ($jenkins_color, $buildbot_color);


#### S T A R T  H E R E   --  J E N K I N S

print STDERR "calling  jenkinsReports::last_done_repo(".$branch.")";

($bldnum, $is_running, $bld_date, $bldstatus) = jenkinsReports::last_done_repo($branch);
print STDERR "according to last_done_build, is_running = $is_running\n";

if ($bldnum < 0)
    {
    $jenkins_color = $note_color;
    $jenkins_row   = HTML_pair_cell( jenkinsQuery::html_RUN_link( $jenkins_builder, 'no build yet'),
                                     buildbotReports::is_running($is_running),
                                     $jenkins_color                                       );
    }
elsif ($bldstatus)
    {
    $jenkins_color = $good_color;
    $jenkins_row   = HTML_pair_cell( jenkinsQuery::html_OK_link( $jenkins_builder, $bldnum, $rev_numb, $bld_date),
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
                                   jenkinsQuery::html_FAIL_link( $jenkins_builder, $bldnum, $is_running, $bld_date),
                                   $jenkins_color                                                         );
    }


#### S T A R T  H E R E   --  B U I L D B O T

print STDERR "calling  buildbotReports::last_done_build($buildbot_builder, $branch)";
($bldstatus, $bldnum, $rev_numb, $bld_date, $is_running) = buildbotReports::last_done_build($buildbot_builder, $branch);
print STDERR "according to last_done_build, is_running = $is_running\n";

if ($bldnum < 0)
    {
    $buildbot_color = $note_color;
    $buildbot_row   = HTML_pair_cell( buildbotQuery::html_RUN_link( $buildbot_builder, 'no build yet'),
                                      buildbotReports::is_running($is_running),
                                      $buildbot_color                                       );
    }
elsif ($bldstatus)
    {
    $buildbot_color = $good_color;
    $buildbot_row   = HTML_pair_cell( buildbotQuery::html_OK_link( $buildbot_builder, $bldnum, $rev_numb, $bld_date),
                                      buildbotReports::is_running($is_running),
                                      $buildbot_color                                                     );
    print STDERR "GOOD: $bldnum\n"; 
    }
else
    {
    print STDERR "FAIL: $bldnum\n"; 
   
    if ( $is_running == 1 )
        {
        $bldnum += 1;
        $buildbot_color = $warn_color;
        }
    else
        {
        $buildbot_color = $err_color;
        }
    $buildbot_row = HTML_pair_cell( buildbotReports::is_running($is_running),
                                    buildbotQuery::html_FAIL_link( $buildbot_builder, $bldnum, $is_running, $bld_date),
                                    $buildbot_color                                                         );
    }

my $html = HTML_repo_pair( $branch, $jenkins_row, $buildbot_row);

print_HTML_Page( $html, "$branch Repo Builder Status", $buildbot_color );

# print "\n---------------------------\n";
__END__

