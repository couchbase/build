#!/usr/bin/perl

# queries Factory Jenkins JSON api to find latest good build of a
# sync_gateway build or package job.
#  
#  Call with these parameters:
#  
#  PLATFORM        e.g. centos-x64, ..., ubuntu-x86
#  BRANCH          e.g. master, 100
#  TYPE            'build' or 'package'
#  
use warnings;
#use strict;
$|++;

use File::Basename;
use Cwd qw(abs_path);
BEGIN
    {
    $THIS_DIR = dirname( abs_path($0));    unshift( @INC, $THIS_DIR );
    }
my $installed_URL='http://factory.hq.couchbase.com/cgi/show_latest_sgw.cgi';

use jenkinsQuery     qw(:DEFAULT );
use jenkinsReports   qw(:DEFAULT );
use buildbotReports  qw(:DEFAULT );

use CGI qw(:standard);
my  $query = new CGI;

my $DEBUG = 0;

my $delay = 1 + int rand(5.3);    sleep $delay;

my ($good_color, $warn_color, $err_color, $note_color) = ('#CCFFDD', '#FFFFCC', '#FFAAAA', '#CCFFFF');

my %release = ( 'master'   => '0.0.0',
                '100'      => '1.0.0',
                '101'      => '1.0.1',
                '102'      => '1.0.2',
              );
my $builder;

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

sub print_HTML_Page
    {
    my ($frag_left, $frag_right, $page_title, $color) = @_;
    
    print $query->header;
    print $query->start_html( -title   => $page_title,
                              -BGCOLOR => $color,
                            );
    print "\n".'<div style="overflow-x: hidden">'."\n"
         .'<table border="0" cellpadding="0" cellspacing="0"><tr>'."\n".'<td valign="TOP">'.$frag_left.'</td><td valign="TOP">'.$frag_right.'</td></tr>'."\n".'</table>'
         .'</div>'."\n";
    print $query->end_html;
    }


my $usage = "ERROR: must specify 'platform', 'branch', 'type'\n\n"
           ."<PRE>"
           ."For example:\n\n"
           ."    $installed_URL?branch=master&type=trigger\n"
           ."    $installed_URL?platform=ubuntu-x64&branch=102&edition=enterprise&type=package\n"
           ."    $installed_URL?platform=windows-x86&branch=101&edition=community&type=package\n"
           ."</PRE><BR>"
           ."\n"
           ."\n";

my ($platform, $branch, $job_type, $edition);

if ( $query->param('branch') && $query->param('type') )
    {
    $branch   = $query->param('branch');
    $job_type = $query->param('type');
    
    if    ( $job_type eq 'trigger')
        {
        if ($DEBUG)  { print STDERR "job_type is 'trigger'\n"; }
        }
    elsif ( $job_type eq 'package')
        {
        if ( ! $query->param('platform') )
            {
            if ($DEBUG)  { print STDERR "platform required for job_type: $job_type\n"; }
            print_HTML_Page( buildbotQuery::html_ERROR_msg($usage), '&nbsp;', 'invalid call to show_latest_sgw.cgi', $err_color );
            exit;
            }
        $platform = $query->param('platform');
        if ( ! $query->param('edition') )
            {
            if ($DEBUG)  { print STDERR "edition required for job_type: $job_type\n"; }
            print_HTML_Page( buildbotQuery::html_ERROR_msg($usage), '&nbsp;', 'invalid call to show_latest_sgw.cgi', $err_color );
            exit;
            }
        $edition = $query->param('edition');
        if ($edition eq 'EE' )  { $edition = 'enterprise'; }
        if ($edition eq 'CE' )  { $edition = 'community';  }
        }
    else
        {
        if ($DEBUG)  { print STDERR "illegal job_type: $job_type\n"; }
        print_HTML_Page( buildbotQuery::html_ERROR_msg($usage), '&nbsp;', 'invalid call to show_latest_sgw.cgi', $err_color );
        exit;
        }
    if ($DEBUG)  { print STDERR "\nready to start with ($branch, $job_type, $platform, $edition)\n"; }
    }
my ($bldstatus, $bldnum, $rev_numb, $bld_date, $is_running);


#### S T A R T  H E R E 

if ($job_type eq 'trigger') { ($builder, $bldnum,            $is_running, $bld_date, $bldstatus) = jenkinsReports::last_done_sgw_trigger($branch);
                              $rev_numb = $release{$branch}.'-'.$bldnum;
                            }
if ($job_type eq 'package') { ($builder, $bldnum, $rev_numb, $is_running, $bld_date, $bldstatus) = jenkinsReports::last_done_sgw_package($platform, $branch, $edition);
                            }

if ($DEBUG)  { print STDERR "according to last_done_build, is_running = $is_running\n"; }

if ($bldnum < 0)
    {
    if ($DEBUG)  { print STDERR "blndum < 0, no build yet\n"; }
    print_HTML_Page( $bld_date,
                     buildbotReports::is_running($is_running),
                     $builder,
                     $note_color );
    }
elsif ($bldstatus)
    {
    my $made_color;    $made_color = $good_color;
    
    print_HTML_Page( jenkinsQuery::html_OK_link( $builder,  $bldnum,   $rev_numb, $bld_date ),
                     buildbotReports::is_running($is_running),
                     $builder,
                     $made_color );
    }
else
    {
    $made_color = $err_color;
    if ( $is_running == 1 )
        {
        $bldnum += 1;
        $made_color = $warn_color;
        }
    print_HTML_Page( buildbotReports::is_running($is_running),
                     jenkinsQuery::html_FAIL_link( $builder, $bldnum, $is_running, $bld_date),
                     $builder,
                     $made_color );
    }
    


# print "\n---------------------------\n";
__END__

