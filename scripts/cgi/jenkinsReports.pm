#!/bin/perl
# 
############ 
#use strict;
use warnings;

package jenkinsReports;

use Exporter qw(import);
#use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT      = ();
our @EXPORT_OK   = qw( last_done_sgw_bld last_done_sgw_pkg last_good_sgw_bld last_good_sgw_pkg );

our %EXPORT_TAGS = ( SYNC_GATEWAY => [qw( &last_done_sgw_bld &last_done_sgw_pkg &last_good_sgw_bld &last_good_sgw_pkg)],
                     DEFAULT      => [qw(                                                                            )] );

my $DEBUG = 1;   # FALSE

############ 

use jenkinsQuery   qw(:DEFAULT );
use buildbotQuery  qw(:HTML :JSON );

my $installed_URL='http://factory.hq.couchbase.com';
my $run_icon  = '<IMG SRC="' .$installed_URL. '/running_20.gif" ALT="running..." HSPACE="50" ALIGN="LEFT">';
my $done_icon = '&nbsp;';


############                        last_done_sgw_bld ( platform, branch )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_done_sgw_bld
    {
    my ($platform, $branch) = @_;
    my $builder  = "build_sync_gateway_$branch";
    my ($bldnum, $is_running, $bld_date, $isgood);
   
    if ($DEBUG)  { print STDERR 'DEBUG: running jenkinsQuery::get_json('.$builder.")\n";    }
    my $sumpage = jenkinsQuery::get_json($builder);
    my $len = scalar keys %$sumpage;
    if ($len < 1 )
        {                   if ($DEBUG)  { print STDERR "DEBUG: no builds yet!\n"; }
        $bldnum     = -1;
        $is_running = 'TBD';
        $bld_date   = 'no build yet';
        $isgood     = 0;
        return( $bldnum, $is_running, $bld_date, $isgood );
        }
    
    if (! defined( $$sumpage{'lastCompletedBuild'} ))
        {
        die "no such build: lastCompletedBuild\n";
        }
    if (! defined( $$sumpage{'lastCompletedBuild'}{'number'} ))
        {
        die "no such build: lastCompletedBuild\n";
        }
    $bldnum = $$sumpage{'lastCompletedBuild'}{'number'};
    if ($DEBUG)  { print STDERR "bldnum is: $bldnum\n"; }
    
    my $result  = jenkinsQuery::get_json($builder.'/'.$bldnum);
    $is_running = 'unknown';
    if (defined( $$result{'building'} ))  { $is_running = ($$result{'building'} ne 'false');   if ($DEBUG) {print STDERR "setting is_running to $$result{'building'}\n";}}
 
    $bld_date   = 'unknown';
    if (defined( $$result{'id'}       ))  { $bld_date   =  $$result{'id'};                     if ($DEBUG) {print STDERR "setting bld_date   to $bld_date\n"; }}

    $isgood     = 'unknown';
    if (defined( $$result{'result'}   ))  { $isgood     = ($$result{'result'}   eq 'SUCCESS'); if ($DEBUG) {print STDERR "setting isgood     to :$$result{'result'}:\n";}}
 
    return( $bldnum, $is_running, $bld_date, $isgood );
    }


############                        last_good_sgw_bld ( platform, branch )
#          
#                                   returns ( build_num, is_build_running, build_date )
sub last_good_sgw_bld
    {
    my ($platform, $branch) = @_;
    my $builder  = "build_sync_gateway_$branch";
    my ($bldnum, $is_running, $bld_date, $isgood);
   
    if ($DEBUG)  { print STDERR 'DEBUG: running jenkinsQuery::get_json('.$builder.")\n";    }
    my $sumpage = jenkinsQuery::get_json($builder);
    my $len = scalar keys %$sumpage;
    if ($len < 1 )
        {                   if ($DEBUG)  { print STDERR "DEBUG: no builds yet!\n"; }
        $bldnum     = -1;
        $is_running = 'TBD';
        $bld_date   = 'no build yet';
        return( $bldnum, $is_running, $bld_date );
        }
    
    if (! defined( $$sumpage{'lastSuccessfulBuild'} ))
        {
        die "no such build: lastSuccessfulBuild\n";
        }
    if (! defined( $$sumpage{'lastSuccessfulBuild'}{'number'} ))
        {
        die "no such build: lastSuccessfulBuild\n";
        }
    $bldnum = $$sumpage{'lastSuccessfulBuild'}{'number'};
    if ($DEBUG)  { print STDERR "bldnum is: $bldnum\n"; }
    
    my $result  = jenkinsQuery::get_json($builder.'/'.$bldnum);
    $is_running = 'unknown';
    if (defined( $$result{'building'} ))  { $is_running = ($$result{'building'} ne 'false');   if ($DEBUG) {print STDERR "setting is_running to $$result{'building'}\n";}}
 
    $bld_date   = 'unknown';
    if (defined( $$result{'id'}       ))  { $bld_date   =  $$result{'id'};                     if ($DEBUG) {print STDERR "setting bld_date   to $bld_date\n"; }}

    return( $bldnum, $is_running, $bld_date );
    }



############                        last_sync_gateway ( platform, branch, job_name, property )
#          
#                                       my $builder  = "build_sync_gateway_$branch";
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_sync_gateway
    {
    my ($platform, $branch, $job_name, $property) = @_;
    my ($bldnum, $is_running, $bld_date, $isgood);
   
    if ($DEBUG)  { print STDERR 'DEBUG: running jenkinsQuery::get_json('.$job_name.")\n";    }
    my $sumpage = jenkinsQuery::get_json($job_name);
    my $len = scalar keys %$sumpage;
    if ($len < 1 )
        {                   if ($DEBUG)  { print STDERR "DEBUG: no builds yet!\n"; }
        $bldnum     = -1;
        $is_running = 'TBD';
        $bld_date   = 'no build yet';
        $isgood     = 0;
        return( $bldnum, $is_running, $bld_date, $isgood );
        }
    
    if (! defined( $$sumpage{$property} ))
        {
        die "no such build:  $property\n";
        }
    if (! defined( $$sumpage{$property}{'number'} ))
        {
        die "no such build:  $property\n";
        }
    $bldnum = $$sumpage{$property}{'number'};
    if ($DEBUG)  { print STDERR "bldnum is: $bldnum\n"; }
    
    my $result  = jenkinsQuery::get_json($job_name.'/'.$bldnum);
    $is_running = 'unknown';
    if (defined( $$result{'building'} ))  { $is_running = ($$result{'building'} ne 'false');   if ($DEBUG) {print STDERR "setting is_running to $$result{'building'}\n";}}
 
    $bld_date   = 'unknown';
    if (defined( $$result{'id'}       ))  { $bld_date   =  $$result{'id'};                     if ($DEBUG) {print STDERR "setting bld_date   to $bld_date\n"; }}

    $isgood     = 'unknown';
    if (defined( $$result{'result'}   ))  { $isgood     = ($$result{'result'}   eq 'SUCCESS'); if ($DEBUG) {print STDERR "setting isgood     to :$$result{'result'}:\n";}}
 
    return( $bldnum, $is_running, $bld_date, $isgood );
    }


############                        last_done_sgw_pkg ( platform, branch )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_done_sgw_pkg
    {
    ($platform, $branch) = @_;
    my $builder  = "package_sync_gateway-".$platform;
    my $property = 'lastCompletedBuild';
    last_sync_gateway($platform, $branch, $builder, $property);
    }
   
############                        last_good_sgw_pkg ( platform, branch )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_good_sgw_pkg
    {
    ($platform, $branch) = @_;
    my $builder  = "package_sync_gateway-".$platform;
    my $property = 'lastSuccessfulBuild';
    last_sync_gateway($platform, $branch, $builder, $property);
    }
   


1;
__END__

