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

my $URL_ROOT  = buildbotQuery::get_URL_root();
my $run_icon  = '<IMG SRC="' .$URL_ROOT. '/running_32.gif" ALT="running...">';
my $done_icon = '&nbsp;'

my ($builder, $branch);

############                        is_running ( 0=no | 1=yes )
#          
#                                   returns icon indicating that latest build is not completed
#                                   
#                                   usually called with buildbotQuery::is_good_build()
sub is_running
    {
    my ($status) = @_;
    
    if ($status == 1 )  { return( $run_icon);  }
    else                { return( $done_icon); }
    }


############                        last_done_build ( builder, branch )
#          
#                                   returns ( status, iteration, build_num, build_date )
#                                   
#                                     where   status = buildbotQuery::is_good_build()
sub last_done_build
    {
    ($builder, $branch) = @_;
    my $is_running = 0;
    
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
 #      print STDERR "....$bldnum   $all_build{$bldnum}\n";
        $result = buildbotQuery::get_json($builder, '/'.$bldnum);
 #      print STDERR "....is $bldnum running?\n";
        if ( buildbotQuery::is_running_build( $result) ) { $is_running = 1;
                                                           print STDERR "$bldnum is still running\n"; }
        else                                             { last;                                      }
        }
    
    my $rev_numb = $branch .'-'. buildbotQuery::get_build_revision($result);
 #  print STDERR "... rev_numb is $rev_numb...\n";
    my $bld_date = buildbotQuery::get_build_date($result);
 #  print STDERR "... bld_date is $bld_date...\n";
    
    return( buildbotQuery::is_good_build($result), $bldnum, $rev_numb, $bld_date, $is_running);
    }



############                        last_good_build ( builder, branch )
#          
#                                   returns ( iteration, build_num, build_date )
#                                        or ( 0 )  if no good build
sub last_good_build
    {
    ($builder, $branch) = @_;
    
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
     #  print STDERR "....$bldnum   $all_build{$bldnum}\n";
        $result = buildbotQuery::get_json($builder, '/'.$bldnum);
     #  print STDERR "....is $bldnum running?\n";
        if ( buildbotQuery::is_running_build( $result) )
            {
            print STDERR "$bldnum is still running\n";
            }
        elsif ( ! buildbotQuery::is_good_build( $result) )
            {
            print STDERR "$bldnum did FAIL\n";
            }
        else
            { last; }
        }
    my $rev_numb = $branch .'-'. buildbotQuery::get_build_revision($result);
  # print STDERR "... rev_numb is $rev_numb...\n";
    my $bld_date = buildbotQuery::get_build_date($result);
  # print STDERR "... bld_date is $bld_date...\n";
    
    if  ( buildbotQuery::is_good_build( $result) )
        {
        
        print STDERR "GOOD: $bldnum\n"; 
        return($bldnum, $rev_numb, $bld_date);
        }
    else
        {
        print STDERR "FAIL: $bldnum\n"; 
        return(0);
        }
    }
1;
__END__

