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
our @EXPORT_OK   = qw( last_done_build last_good_build is_running );

our %EXPORT_TAGS = ( DEFAULT => [qw( &last_done_build &last_good_build &is_running )] );

my $DEBUG = 0;   # FALSE

############ 

use buildbotQuery   qw(:HTML :JSON );
use buildbotMapping qw(:DEFAULT);

#my $URL_ROOT  = buildbotQuery::get_URL_root();

my $installed_URL='http://10.3.2.199';
my $run_icon  = '<IMG SRC="' .$installed_URL. '/running_20.gif" ALT="running..." HSPACE="50" ALIGN="TOP">';
my $done_icon = '&nbsp;';

my ($builder, $branch);

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
    my ($bldnum, $next_bldnum, $result);
   
    if ($DEBUG)  { print 'DEBUG: running buildbotQuery::get_json('.$builder.")\n";    }
    my $all_builds = buildbotQuery::get_json($builder);
    my $len = scalar keys %$all_builds;
    if ($DEBUG)  { print "\nDEBUG: all we got back was $all_builds\tlength:  $len\n"; }
    
    if ($len < 1 )
        {
        if ($DEBUG)  { print "DEBUG: no builds yet!\n"; }
        $isgood     = 0;
        $bldnum     = -1;
        $rev_numb   = 0;
        $bld_date   = 'no build yet';
        $is_running = 0;
        return( $isgood, $bldnum, $rev_numb, $bld_date, $is_running);
        }
    
    foreach my $KEY (keys %$all_builds)
        {
        if ($DEBUG)  { print ".";  }
        my $VAL = $$all_build{$KEY};
        if (! defined $VAL)  { $$all_build{$KEY}="null" }
        }
        if ($DEBUG)  { print "\n"; }
    
    my $is_running  = 0;
    $bldnum         = (reverse sort { 0+$a <=> 0+$b } keys %$all_builds)[0];
    $result         = buildbotQuery::get_json($builder, '/'.$bldnum);
    
    $next_bldnum    = 1+ $bldnum;                                             # print STDERR "....is $next_bldnum running?\n";
    my $next_build  = buildbotQuery::get_json($builder, '/'.$next_bldnum);
    if ( buildbotQuery::is_running_build( $next_build) ) { $is_running = 1;  print STDERR "$bldnum is still running\n"; }
    
    my $rev_numb = $branch .'-'. buildbotQuery::get_build_revision($result);
    my $bld_date = buildbotQuery::get_build_date($result);

 #  print STDERR "... bld_date is $bld_date...\n";
 #  print STDERR "... rev_numb is $rev_numb...\n";
    
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
1;
__END__

