#!/bin/perl
# 
############ 
#use strict;
use warnings;

package buildbotReports;

use Exporter qw(import);
#use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT      = ();
our @EXPORT_OK   = qw( last_done_build last_good_build is_running sanity_url );

our %EXPORT_TAGS = ( DEFAULT => [qw( &last_done_build &last_good_build &is_running sanity_url& )] );

my $DEBUG = 0;   # FALSE

############ 

use buildbotQuery   qw(:HTML :JSON );
use buildbotMapping qw(:DEFAULT);

#my $URL_ROOT  = buildbotQuery::get_URL_root();

my $installed_URL='http://factory.hq.couchbase.com';
my $run_icon  = '<IMG SRC="' .$installed_URL. '/running_20.gif" ALT="running..." HSPACE="50" ALIGN="LEFT">';
my $done_icon = '&nbsp;';

my ($builder, $branch);

my $delay = 1 + int rand(3.3);    sleep $delay;

sub release
    {
    my ($branch_name) = @_;
    my  $branch_numb  = $branch_name;
    if ($branch_numb eq 'master')    { $branch_numb = '0.0.0'; }
    return($branch_numb);
    }

############                        is_running ( 0=no | 1=yes )
#          
#                                   returns icon indicating that latest build is not completed
#                                   
#                                   usually called with buildbotQuery::is_good_build()
sub is_running
    {
    my ($status) = @_;
    
    if ($status == 1 )  { print STDERR "...it's running...\n";  return( $run_icon);  }
    else                { print STDERR "....NOT RUNNING...\n";  return( $done_icon); }
    }


############                        last_done_build ( builder, branch )
#          
#                                   returns ( status, iteration, build_num, build_date )
#                                   
#                                     where   status = buildbotQuery::is_good_build()
sub last_done_build
    {
    ($builder, $branch) = @_;
    my ($bldnum, $next_bldnum, $result, $isgood, $rev_numb, $bld_date);
   
    if ($DEBUG)  { print STDERR 'DEBUG: running buildbotQuery::get_json('.$builder.")\n";    }
    my $all_builds = buildbotQuery::get_json($builder);
    my $len = scalar keys %$all_builds;
    if ($DEBUG)  { print STDERR "\nDEBUG: all we got back was $all_builds\tlength:  $len\n"; }
    
    foreach my $KEY (keys %$all_builds)
        {
        if ($DEBUG)  { print STDERR ".";  }
        my $VAL = $$all_build{$KEY};
        if (! defined $VAL)  { $$all_build{$KEY}="null" }
        }
        if ($DEBUG)  { print STDERR "\n"; }
    
    if ($len < 1 )
        {                   if ($DEBUG)  { print STDERR "DEBUG: no builds yet!\n"; }
        $bldnum     = -1;
        $isgood     = 0;
        $rev_numb   = 0;
        $bld_date   = 'no build yet';
        }
    else
        {
        $bldnum     = (reverse sort { 0+$a <=> 0+$b } keys %$all_builds)[0];
        $result     = buildbotQuery::get_json($builder, '/'.$bldnum);
        $isgood     = buildbotQuery::is_good_build($result);
        sleep $delay;
        
        $rev_numb   = release($branch) .'-'. buildbotQuery::get_build_revision($result);
        $bld_date   = buildbotQuery::get_build_date($result);
        }
    
    my $is_running  = 0;
    
    $next_bldnum    = 1+ $bldnum;                                             # print STDERR "....is $next_bldnum running?\n";
    my $next_build  = buildbotQuery::get_json($builder, '/'.$next_bldnum);
    if ( buildbotQuery::is_running_build( $next_build) ) { $is_running = 1;  print STDERR "$bldnum is still running\n"; }
    

    print STDERR "... bld_date is $bld_date...\n";
    print STDERR "... rev_numb is $rev_numb...\n";
    
    return( buildbotQuery::is_good_build($result), $bldnum, $rev_numb, $bld_date, $is_running);
    }



############                        last_good_build ( builder, branch )
#          
#                                   returns ( iteration, build_num, build_date )
#                                        or ( 0 )  if no good build
sub last_good_build
    {
    ($builder, $branch) = @_;
    my ($bldnum, $last_bldnum, $next_bldnum, $result);
    
    my $all_builds = buildbotQuery::get_json($builder);
    
    foreach my $KEY (keys %$all_builds)
        {
        my $VAL = $$all_build{$KEY};
        if (! defined $VAL)  { $$all_build{$KEY}="null" }
        }
    my $is_running  = 0;
    $last_bldnum    = (reverse sort { 0+$a <=> 0+$b } keys %$all_builds)[0];
    $next_bldnum    = 1+ $last_bldnum;                                     # print STDERR "......is $next_bldnum running?\n";
    my $next_build  = buildbotQuery::get_json($builder, '/'.$next_bldnum);
    if ( buildbotQuery::is_running_build( $next_build) ) { $is_running = 1;  print STDERR "$next_bldnum is still running.\n"; }
    
    foreach my $KEY (reverse sort { 0+$a <=> 0+$b } keys %$all_builds)
        {
        $bldnum = $KEY;
     #  print STDERR "....$bldnum   $$all_build{$bldnum}\n";
        $result = buildbotQuery::get_json($builder, '/'.$bldnum);
     #  print STDERR "....is $bldnum running?\n";
        if ( buildbotQuery::is_running_build( $result) )
            {
            print STDERR "$bldnum is still running\n";
            $is_running = 1;
            }
        elsif ( ! buildbotQuery::is_good_build( $result) )
            {
            print STDERR "$bldnum did FAIL\n";
            }
        else
            { last; }
        }
    my $rev_numb = $branch .'-'. buildbotQuery::get_build_revision($result);
    my $bld_date = buildbotQuery::get_build_date($result);
    
  # print STDERR "... rev_numb is $rev_numb...\n";
  # print STDERR "... bld_date is $bld_date...\n";
    
    if  ( buildbotQuery::is_good_build( $result) )
        {
        
        print STDERR "GOOD: $bldnum\n"; 
        return($bldnum, $rev_numb, $bld_date, $is_running);
        }
    else
        {
        print STDERR "FAIL: $bldnum\n"; 
        return(0);
        }
    }

############                        sanity_url ( builder, build_number )
#          
#                                   returns ( url of test job run, boolean did it apss )
#                                        or ( 0 )  if no good build
sub sanity_url
    {
    my ($builder, $bld_num) = @_;
    my ($tindex, $test_url_root);
    my  $url_rex = '[htps]*://([a-zA-Z0-9.:_-]*)/+job/+([a-zA-Z0-9_-]*)';
    if ($DEBUG)     { print STDERR "============================\nentering sanity_url($builder, $bld_num)\n"; }
    
    my ($test_url, $bld_revision) = buildbotQuery::trigger_jenkins_url($builder, $bld_num);
    
    if ($DEBUG)     { print STDERR "we got to here..........\n"; }
    return(0) if (! defined ($bld_revision) );    
    if ($DEBUG)     { print STDERR "we got to here..........\n"; }
    
    if ($DEBUG)     { print STDERR "returned: ($test_url, $bld_revision)\n";             }
    
    if ($test_url =~ $url_rex)
        {
        $test_url_root = $1;
        $test_job_name = $2;
        if ($DEBUG)  { print STDERR "extracted (url domain, test job) = ( $test_url_root , $test_job_name)\n     from $test_url\n"; }
        return($test_url_root, $test_job_name);
        }
    else
        {
        if ($DEBUG)  { print STDERR "$test_url is NOT a jenkins URL\n\n"; }
        return(0);
        }
    ($test_url, $tindex) = buildbotQuery::get_URL_root($test_url_root);
    if ($DEBUG)     { print STDERR "returned: ($test_url, $tindex)\n";                }
    $test_url = $test_url.'/job/'.$test_job_name;
    
    my ($did_pass, $test_job_url, $test_job_num) = buildbotQuery::test_job_results($test_url, $bld_revision);
    if ($DEBUG)  { print STDERR "test_job_results are: ($did_pass, $test_job_num)\n"; }
    if ($did_pass)  { if ($DEBUG)  { print STDERR "it passed\n";  }                   }
    if ($DEBUG)  { print STDERR "It was $test_job_num that tested $bld_revision\n";   }
    return($test_job_num, $did_pass, $test_job_num);
    }

1;
__END__

