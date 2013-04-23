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


use buildbotQuery   qw(:HTML :JSON );
use buildbotMapping qw(:DEFAULT);

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
           ."    $installed_URL/$SCRIPT_NAME?builder=cs-win2008-x64-20-builder-202&branch=2.0.2\n\n"
           ."    $installed_URL/$SCRIPT_NAME?platform=windows&bits=64&branch=2.0.2\n\n"
           ."<PRE>";

my ($builder, $branch);

if ( $query->param('builder') && $query->param('branch') )
    {
    $builder = $query->param('builder');
    $branch  = $query->param('branch');
    }
elsif( ($query->param('platform')) && ($query->param('bits')) && ($query->param('branch')) )
    {
    $builder = buildbotMapping::get_builder( $query->param('platform'), $query->param('bits'), $query->param('branch') );
    $branch  = $query->param('branch');
    }
else
    {
    print_HTML_Page( buildbotQuery::html_ERROR_msg($usage) );
    exit;
    }

#### S T A R T  H E R E 

my $URL_ROOT=buildbotQuery::get_URL_root();

my $all_builds = buildbotQuery::get_json($builder);

my ($bldnum, $result);
foreach my $KEY (keys %$all_builds)
    {
    my $VAL = $$all_build{$KEY};
    if (! defined $VAL)  { $$all_build{$KEY}="null" }
    }

foreach my $KEY (reverse sort { 0+$a <=> 0+$b } keys %$all_builds)
    {
    $bldnum = $KEY;
    print STDERR "....$bldnum   $all_build{$bldnum}\n";
    $result = buildbotQuery::get_json($builder, '/'.$bldnum);
    print STDERR "....is $bldnum running?\n";
    if ( buildbotQuery::is_running_build( $result) ) { print STDERR "$bldnum is still running\n"; }
    else                                             { last;                                      }
    }

# print "\n---------------------------\n";
# print buildbotQuery::html_builder_link($builder);
# print "\n---------------------------\n";
# print buildbotQuery::html_OK();
# print "\n---------------------------\n";
# print buildbotQuery::html_ERROR_msg("compile failure, jackson");
# print "\n---------------------------\n";

if  ( buildbotQuery::is_good_build( $result) )
    {
    my $rev_numb = $branch .'-'. buildbotQuery::get_build_revision($result);
    print STDERR "... rev_numb is $rev_numb...\n";
    my $bld_date = buildbotQuery::get_build_date($result);
    print STDERR "... bld_date is $bld_date...\n";
    
    print STDERR "GOOD: $bldnum\n"; 
    print_HTML_Page( buildbotQuery::html_OK_link(   $builder, $bldnum, $rev_numb, $bld_date ) );
    }
else
    {
    print STDERR "FAIL: $bldnum\n"; 
    print_HTML_Page( buildbotQuery::html_FAIL_link( $builder, $bldnum ) );
    }

# print "\n---------------------------\n";
__END__

