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
our @EXPORT_OK   = qw( last_done_sgw_trigger  last_done_sgw_package  last_good_sgw_trigger  last_good_sgw_package \
                       last_done_mobile_bld   last_good_ios_bld      last_done_and_bld      last_good_and_bld     \
                       last_done_query_bld    last_good_query_bld    last_done_java_bld     last_good_java_bld    \
                       get_builder            link_to_package                                                     \
                       last_done_repo         last_commit_valid      last_done_server       last_done_toy_server  \
                     );

our %EXPORT_TAGS = ( SYNC_GATEWAY => [qw( &last_done_sgw_trigger  &last_done_sgw_package   &last_good_sgw_trigger  &last_good_sgw_package )],
                     MOBILE       => [qw( &last_done_mobile_bld   &last_good_ios_bld       &last_done_and_bld      &last_good_and_bld     )],
                     QUERY        => [qw( &last_done_query_bld    &last_good_query_bld                                                    )],
                     MOBILE_JAVA  => [qw( &last_done_java_bld     &last_good_java_bld                                                     )],
                     DEFAULT      => [qw( &get_builder            &link_to_package         \
                                          &last_done_repo         &last_commit_valid       &last_done_server       &last_done_toy_server  )],
                   );

my $DEBUG = 0;   # FALSE

############ 

use jenkinsQuery   qw(:DEFAULT );
use buildbotQuery  qw(:HTML :JSON );

my $installed_URL='http://factory.hq.couchbase.com';
my $run_icon  = '<IMG SRC="' .$installed_URL. '/running_20.gif" ALT="running..." HSPACE="50" ALIGN="LEFT">';
my $done_icon = '&nbsp;';

my $TIMEZONE = `date +%Z`;    chomp($TIMEZONE);

sub date_from_id
    {
    my ($jobID, $brief) = @_;
    
    my ($dat, $hor, $min, $sec);
    my $date_rex = '([0-9-]+)_([0-9]+)-([0-9]+)-([0-9]+)';
    
    if ($jobID =~ $date_rex)
        {
        $dat = $1;  $hor = $2;  $min = $3;  $sec = $4;
        if (defined($brief)) {  return $dat; }
        else                 {  return $dat.'&nbsp;<SMALL>'."$hor:$min:$sec".'&nbsp;'.$TIMEZONE.'</SMALL>'; }
        }
    return $jobID;
    }

############                        get_builder ( platform, branch, "build" or "package", "sgw" or "ios" or "and" )
#          
#                                   returns ( builder )
sub get_builder
    {
    my ($platform, $branch, $type, $prod, $edition) = @_;
    my  $builder;
    
    if ($type eq 'repo')     { $builder = jenkinsQuery::get_repo_builder($branch);  }
    if ($type eq 'trigger')
        {
        if ($prod eq 'sgw')  { $builder = "build_sync_gateway_".$branch;    }
        }
    if ($type eq 'build')
        {
        if ($prod eq 'and')    { $builder = "build_cblite_android_".$branch.'-'.$edition; }
        if ($prod eq 'ios')    { $builder = "build_cblite_ios_".$branch.'-'.$edition;     }
        if ($prod eq 'java')   { $builder = "build_cblite_java_".$branch.'-'.$edition;    }
        if ($prod eq 'query')  { $builder = "build_tuqtng_".$branch;                      }
        }
    if ($type eq 'package')
        {
        my  $plat = $platform;
        if ($plat =~ 'windows-(.*)') { $plat = 'win-2008-'.$1; }
        $builder = "build_sync_gateway_".$branch."_".$plat;
        }
    return($builder);
    }

############                        link_to_package( prod, revision, platform, edition )
#          
#                                   returns ( HTML )
sub link_to_package
    {
    my ($prod, $revision, $platform, $edition) = @_;
    my  $HTML;
    my ($release, $display, $pkg_name, $URL);

    if ($revision =~ /([0-9.]*)-[0-9]*/)  { $release = $1; }
    
    if    ($prod eq 'and')
        {
        $pkg_name = 'couchbase-lite-android-'.$edition.'_'.$revision.'.zip';
        $display = 'ZIP';
        }
    elsif ($prod eq 'ios')
        {
        $pkg_name = 'couchbase-lite-ios-'.$edition.'_'.$revision.'.zip';
        $display = 'ZIP';
        }
    elsif ($prod eq 'java')
        {
        $pkg_name = 'couchbase-lite-java-'.$edition.'_'.$revision.'.zip';
        $display = 'ZIP';
        }
    else
        {
        my %pkg_sfx = ( 'centos-x64'  => 'x86_64.rpm',
                        'centos-x86'  => 'x86.rpm',
                        'macosx-x64'  => 'x86_64.tar.gz',
                        'ubuntu-x64'  => 'x86_64.deb',
                        'ubuntu-x86'  => 'x86.deb',
                        'windows-x64' => 'x86_64.exe',
                        'windows-x86' => 'x86.exe',
                      );
        $pkg_name = "couchbase-sync-gateway-".$edition."_".$revision."_".$pkg_sfx{$platform};
        
        my %display = ( 'centos-x64'  => 'RPM',  'centos-x86'   => 'RPM',
                        'ubuntu-x64'  => 'DEB',  'ubuntu-x86'   => 'DEB',
                        'macosx-x64'  => 'TGZ',
                        'windows-x64' => 'EXE',  'windows-x86'  => 'EXE',
                      );
        $display = $display{$platform};
        }
    
    my %bucket  = ( 'and'    => "android",
                    'ios'    => "ios",
                    'sgw'    => "sync_gateway",
                  );
    $URL  = "http://packages.couchbase.com/builds/mobile/".$bucket{$prod}."/". $release."/".$revision."/".$pkg_name;
    
    $HTML = '&nbsp;&nbsp;&nbsp;<a href="'.$URL.'">'.$display.'</A>';
    }


############                        last_done_sgw_package ( platform, branch, $edition )
#          
#                                   returns ( job_num, build_num, is_build_running, build_date, status )
sub last_done_sgw_package
    {
    my ($platform, $branch, $edition) = @_;
    my $builder  = get_builder($platform, $branch, "package", "sgw");
    my ($jobnum, $bldnum, $is_running, $bld_date, $isgood);
    
    my %job_branch_token  = ( 'master'        => 'master',
                              'release/1.0.2' => '102',
                              'release/1.0.1' => '101',
                              'release/1.0.0' => '100',
                              'support/1.0.0' => '100',
                              'support/1.0.1' => '101',
                            );
    if ($DEBUG)  { print STDERR 'DEBUG: running jenkinsQuery::get_json('.$builder.")\n";    }
    my $sumpage = jenkinsQuery::get_json($builder);
    my $len = scalar keys %$sumpage;
    if ($len < 1 )
        {                   if ($DEBUG)  { print STDERR "DEBUG: no builds yet!\n"; }
        $jobnum     =  0;
        $bldnum     = -1;
        $is_running =  0;    # 'TBD';
        $bld_date   = 'no package yet';
        $isgood     =  0;
        return( $jobnum, $bldnum, $is_running, $bld_date, $isgood );
        }
    
    if (! defined( $$sumpage{'builds'} ))
        {
        die "no such field: builds\n";
        }
    my $results_array = $$sumpage{'builds'};
    $len = $#$results_array;
    if ($len < 1)
        {
        if ($DEBUG)  { print STDERR "no build results for $builder\n"; }
        $jobnum     =  0;
        $bldnum     = -1;
        $is_running =  0;    # 'TBD';
        $bld_date   = 'no package yet';
        $isgood     =  0;
        return( $jobnum, $bldnum, $is_running, $bld_date, $isgood );
        }
    my @results_numbers;
    my ($found_bldnum, $found_branch, $found_edition);
    for my $item ( 0 .. $len)  { if ($DEBUG) { print STDERR "array[ $item ] is $$results_array[$item]{'number'}\n"; }
                                               push @results_numbers, $$results_array[$item]{'number'};
                                             }
    @job_numbers = reverse sort { $a <=> $b } @results_numbers;
    if ($DEBUG)  { print STDERR "DEBUG: job_numbers: $#job_numbers\n";   print STDERR "@job_numbers\n";                      }
    if ($DEBUG)  { for my $NN ( @job_numbers ) { print STDERR "$NN\n";}  print STDERR "DEBUG: job_numbers: $#job_numbers\n"; }
    for my $jnum (@job_numbers)
        {
        undef($found_bldnum);    undef($found_branch);    undef($found_edition);
        if ($DEBUG) { print STDERR "...checkint $jnum\n"; }
        $bldpage  = jenkinsQuery::get_json($builder.'/'.$jnum);
        
        if (! defined( $$bldpage{'actions'} ))
            {
            die "no such field: actions\n";
            }
        if (! defined( $$bldpage{'actions'}[0] ))
            {
            die "no such field: actions[0]\n";
            }
        if (! defined( $$bldpage{'actions'}[0]{'parameters'} ))
            {
            die "no such field: actions[0]{parameters}\n";
            }
        for my $pp (0 .. scalar keys $$bldpage{'actions'}[0]{'parameters'})
            {
            if ($DEBUG)  { print STDERR "pp is $pp\n"; }
            if ($$bldpage{'actions'}[0]{'parameters'}[$pp]{'name'} eq 'REVISION')
                {
                $found_bldnum  = $$bldpage{'actions'}[0]{'parameters'}[$pp]{'value'};
                if ($DEBUG)    { print STDERR "detected revision: $found_bldnum\n";}
                }
            if ($$bldpage{'actions'}[0]{'parameters'}[$pp]{'name'} eq 'GITSPEC')
                {
                $found_branch  = $$bldpage{'actions'}[0]{'parameters'}[$pp]{'value'};
                if ($DEBUG)    { print STDERR "detected branch:   $found_branch\n";}
                }
            if ($$bldpage{'actions'}[0]{'parameters'}[$pp]{'name'} eq 'EDITION')
                {
                $found_edition = $$bldpage{'actions'}[0]{'parameters'}[$pp]{'value'};
                if ($DEBUG)    { print STDERR "detected edition:  $found_edition\n";}
                }
            last if ( defined($found_bldnum) && defined($found_branch) && defined($found_edition) );
            }
        if (($job_branch_token{$found_branch} eq $branch) && ( $found_edition eq $edition ))  { $jobnum = $jnum; last; }
        }
    if (! defined ($jobnum))
        {
        if ($DEBUG)  { print STDERR "no $branch matching builds for $builder\n"; }
        $jobnum     =  0;
        $bldnum     = -1;
        $is_running =  0;    # 'TBD';
        $bld_date   = 'no package yet';
        $isgood     =  0;
        return( $jobnum, $bldnum, $is_running, $bld_date, $isgood );
        }
    if (! defined ($found_bldnum))
        {
        $found_bldnum = '<I>bld&nbsp;'.$bldnum.'</>';
        }
    if ($DEBUG)  { print STDERR "jobnum is: $jobnum\n"; }
    
    my $result  = jenkinsQuery::get_json($builder.'/'.$jobnum);
    $is_running = 'unknown';
    if (defined( $$result{'building'} ))  { $is_running = ($$result{'building'} ne 'false');        if ($DEBUG) {print STDERR "setting is_running to $$result{'building'}\n";}}
 
    $bld_date   = 'unknown';
    if (defined( $$result{'id'}       ))  { $bld_date   =  date_from_id( $$result{'id'}, 'brief' ); if ($DEBUG) {print STDERR "setting bld_date   to $bld_date\n"; }          }

    $isgood     = 'unknown';
    if (defined( $$result{'result'}   ))  { $isgood     = ($$result{'result'}   eq 'SUCCESS');      if ($DEBUG) {print STDERR "setting isgood     to :$$result{'result'}:\n";}}
 
    return( $builder, $jobnum, $found_bldnum, $is_running, $bld_date, $isgood );
    }



############                        last_done_sgw_trigger ( branch )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_done_sgw_trigger
    {
    my ($branch) = @_;
    my $builder  = get_builder('None',  $branch, "trigger", "sgw");
    my $property = 'lastCompletedBuild';
    return($builder, return_build_info($builder, $property));
    }
   
############                        last_good_sgw_trigger ( branch )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_good_sgw_trigger
    {
    my ($branch) = @_;
    my $builder  = get_builder('None', $branch, "trigger", "sgw");
    my $property = 'lastSuccessfulBuild';
    return_build_info($builder, $property);
    }
   


############                        last_done_mobile_bld ( product ('and'/'ios'/'java'), platform, branch, edition )
#          
#                                   returns ( builder, build_num, job_number, is_build_running, build_date, status )
sub last_done_mobile_bld
    {
    my ($product, $platform, $branch, $edition) = @_;
    my ($builder, $bld_num, $job_num, $is_running, $bld_date, $isgood);
    
    $builder  = get_builder($platform, $branch, "build", $product, $edition);
    
    if ($DEBUG)  { print STDERR 'DEBUG: running jenkinsQuery::get_json('.$builder.")\n";    }
    my $sumpage = jenkinsQuery::get_json($builder);
    my $len = scalar keys %$sumpage;
    if ($len < 1 )
        {                   if ($DEBUG)  { print STDERR "DEBUG: no builds yet!\n"; }
        $job_num    =  0;
        $bld_num    = -1;
        $is_running =  0;    # 'TBD';
        $bld_date   = 'no package yet';
        $isgood     =  0;
        return( $builder, $bld_num, $job_num, $is_running, $bld_date, $isgood );
        }
    
    if (! defined( $$sumpage{'builds'} ))
        {
        die "no such field: builds\n";
        }
    my $results_array = $$sumpage{'builds'};
    $len = $#$results_array;
    if ($len < 1)
        {
        if ($DEBUG)  { print STDERR "no build results for $builder\n"; }
        $job_num    =  0;
        $bld_num    = -1;
        $is_running =  0;    # 'TBD';
        $bld_date   = 'no package yet';
        $isgood     =  0;
        return( $builder, $bld_num, $job_num, $is_running, $bld_date, $isgood );
        }
    my @results_numbers;
    my ($found_bldnum, $found_edition);
    for my $item ( 0 .. $len)  { if ($DEBUG) { print STDERR "array[ $item ] is $$results_array[$item]{'number'}\n"; }
                                               push @results_numbers, $$results_array[$item]{'number'};
                                             }
    if ($DEBUG)  { print STDERR "DEBUG: job_numbers: $#results_numbers\n";  print STDERR "@job_numbers\n";                      }
    if ($DEBUG)  { for my $NN ( @job_numbers ) { print STDERR "$NN\n";}     print STDERR "DEBUG: job_numbers: $#job_numbers\n"; }
    @job_numbers = reverse sort { $a <=> $b } @results_numbers;
    for my $jnum (@job_numbers)
        {
        undef($found_bldnum);    undef($found_edition);
        if ($DEBUG) { print STDERR "...checkint $jnum\n"; }
        $bldpage  = jenkinsQuery::get_json($builder.'/'.$jnum);
        
        if (! defined( $$bldpage{'actions'} ))
            {
            die "no such field: actions\n";
            }
        if (! defined( $$bldpage{'actions'}[0] ))
            {
            die "no such field: actions[0]\n";
            }
        if (! defined( $$bldpage{'actions'}[0]{'parameters'} ))
            {
            die "no such field: actions[0]{parameters}\n";
            }
        for my $pp (0 .. scalar keys $$bldpage{'actions'}[0]{'parameters'})
            {
            if ($DEBUG)  { print STDERR "pp is $pp\n"; }
            if ($$bldpage{'actions'}[0]{'parameters'}[$pp]{'name'} eq 'PARENT_BUILD_NUMBER')
                {
                $found_bldnum  = $$bldpage{'actions'}[0]{'parameters'}[$pp]{'value'};
                if ($DEBUG)    { print STDERR "detected bldnum:   $found_bldnum\n";}
                }
            if ($$bldpage{'actions'}[0]{'parameters'}[$pp]{'name'} eq 'EDITION')
                {
                $found_edition = $$bldpage{'actions'}[0]{'parameters'}[$pp]{'value'};
                if ($DEBUG)    { print STDERR "detected edition:  $found_edition\n";}
                }
            last if ( defined($found_bldnum) && defined($found_edition) );
            }
        if ( $found_edition eq $edition )  { $job_num = $jnum;  $bld_num = $found_bldnum;  last; }
        }
        
    if (! defined ($job_num))
        {
        if ($DEBUG)  { print STDERR "no $branch matching builds for $builder\n"; }
        $job_num    =  0;
        $bld_num    = -1;
        $is_running =  0;    # 'TBD';
        $bld_date   = 'no package yet';
        $isgood     =  0;
        return( $builder, $bld_num, $job_num, $is_running, $bld_date, $isgood );
        }
    if (! defined ($found_bldnum))
        {
        $bld_num = '<I>bld&nbsp;'.$bld_num.'</>';
        }
    if ($DEBUG)  { print STDERR "job_num is: $job_num\n"; }
        
    my $result  = jenkinsQuery::get_json($builder.'/'.$job_num);
    $is_running = 'unknown';
    if (defined( $$result{'building'} ))  { $is_running = ($$result{'building'} ne 'false');        if ($DEBUG) {print STDERR "setting is_running to $$result{'building'}\n";}}
 
    $bld_date   = 'unknown';
    if (defined( $$result{'id'}       ))  { $bld_date   =  date_from_id( $$result{'id'}, 'brief' ); if ($DEBUG) {print STDERR "setting bld_date   to $bld_date\n"; }          }

    $isgood     = 'unknown';
    if (defined( $$result{'result'}   ))  { $isgood     = ($$result{'result'}   eq 'SUCCESS');      if ($DEBUG) {print STDERR "setting isgood     to :$$result{'result'}:\n";}}
 
    return( $builder, $bld_num, $job_num, $is_running, $bld_date, $isgood );
    }
   
############                        last_good_ios_bld ( platform, branch, edition )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_good_ios_bld
    {
    my ($platform, $branch, $edition) = @_;
    my $builder  = get_builder($platform, $branch, "build", "ios", $edition);
    my $property = 'lastSuccessfulBuild';
    return( $builder,  return_build_info($builder, $property, 'brief') );
    }
   

############                        last_done_and_bld ( platform, branch )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_done_and_bld
    {
    my ($platform, $branch) = @_;
    my $builder  = get_builder($platform, $branch, "build", "and");
    my $property = 'lastCompletedBuild';
    return_build_info($builder, $property);
    }
   
############                        last_good_and_bld ( platform, branch )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_good_and_bld
    {
    my ($platform, $branch, $edition) = @_;
    my $builder  = get_builder($platform, $branch, "build", "and");
    my $property = 'lastSuccessfulBuild';
    return( $builder,  return_build_info($builder, $property, 'brief') );
    }

############                        last_done_java_bld ( platform, branch, edition )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_done_java_bld
    {
    my ($platform, $branch, $edition) = @_;
    my $builder  = get_builder($platform, $branch, "build", "java" , $edition);
    my $property = 'lastCompletedBuild';
    return_build_info($builder, $property);
    }
   
############                        last_good_java_bld ( platform, branch, edition )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_good_java_bld
    {
    my ($platform, $branch, $edition) = @_;
    my $builder  = get_builder($platform, $branch, "build", "java" , $edition);
    my $property = 'lastSuccessfulBuild';
    return( $builder,  return_build_info($builder, $property, 'brief') );
    }
   

############                        last_done_query_bld ( platform, branch, edition )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_done_query_bld
    {
    my ($platform, $branch, $edition) = @_;
    my $builder  = get_builder($platform, $branch, "build", "query");
    my $property = 'lastCompletedBuild';
    return( $builder, return_build_info($builder, $property) );
    }
   
############                        last_good_query_bld ( platform, branch, edition )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_good_query_bld
    {
    my ($platform, $branch, $edition) = @_;
    my $builder  = get_builder($platform, $branch, "build", "query");
    my $property = 'lastSuccessfulBuild';
    return( $builder,  return_build_info($builder, $property, 'brief') );
    }
   



############                        last_done_repo ( branch )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_done_repo
    {
    my ($branch) = @_;    my $platform = 'N/A';
    my $builder  = get_builder($platform, $branch, "repo","repo");
    my $property = 'lastCompletedBuild';
    return_build_info($builder, $property);
    }
   


############                        return_build_info ( job_name, property, [ brief timestamp ] )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
#          
sub return_build_info
    {
    my ($job_name, $property, $brief) = @_;
    my ($bldnum, $is_running, $bld_date, $isgood);
   
    if ($DEBUG)  { print STDERR 'DEBUG: running jenkinsQuery::get_json('.$job_name.")\n";    }
    my $sumpage = jenkinsQuery::get_json($job_name);
    my $len = scalar keys %$sumpage;
    if ($len < 1 )
        {                                           if ($DEBUG)  { print STDERR "DEBUG: no builds yet!\n"; }
        $bldnum     = -1;
        $is_running = 'TBD';
        $bld_date   = 'no build yet';
        $isgood     = 0;
        return( $bldnum, $is_running, $bld_date, $isgood );
        }
    
    if (! defined( $$sumpage{$property} ))
        {                                           if ($DEBUG)  { print STDERR "DEBUG: no such build:  $property\n"; }
        $bldnum     = -1;
        $is_running = 'TBD';
        $bld_date   = 'no build yet';
        $isgood     = 0;
        return( $bldnum, $is_running, $bld_date, $isgood );
        }
    if (! defined( $$sumpage{$property}{'number'} ))
        {                                           if ($DEBUG)  { print STDERR "DEBUG: no such build:  $property\n"; }
        $bldnum     = -1;
        $is_running = 'TBD';
        $bld_date   = 'no build yet';
        $isgood     = 0;
        return( $bldnum, $is_running, $bld_date, $isgood );
        }
    $bldnum = $$sumpage{$property}{'number'};
    if ($DEBUG)  { print STDERR "bldnum is: $bldnum\n"; }
    
    my $result  = jenkinsQuery::get_json($job_name.'/'.$bldnum);
    $is_running = 'unknown';
    if (defined( $$result{'building'} ))  { $is_running = ($$result{'building'} ne 'false');        if ($DEBUG) { print STDERR "setting is_running to $$result{'building'}\n";}}
     
    $bld_date   = 'unknown';
    if (defined( $$result{'id'}       ))  { $bld_date   =  date_from_id( $$result{'id'}, $brief );  if ($DEBUG) { print STDERR "setting bld_date   to $bld_date\n"; }          }
    
    $isgood     = 'unknown';
    if (defined( $$result{'result'}   ))  { $isgood     = ($$result{'result'}   eq 'SUCCESS');      if ($DEBUG) { print STDERR "setting isgood     to :$$result{'result'}:\n";}}
 
    return( $bldnum, $is_running, $bld_date, $isgood );
    }

############                        last_commit_valid ( job_name, branch )
#          
#                                   returns ( build_num, is_build_running, build_date, status, change_url, gerrit_num )
sub last_commit_valid
    {
    my ($builder, $branch) = @_;
    my $property = 'lastCompletedBuild';
    my ($gerrit_url, $gerrit_num);
    
    my ($build_num, $is_running, $bld_date, $bld_stat) = return_build_info($builder, $property);
    
    if ($DEBUG)  { print STDERR "last_commit_valid got build info ($build_num, $is_running, $bld_date, $bld_stat)\n"; }
    
    my $result  = jenkinsQuery::get_json($builder.'/'.$build_num);
    if ($DEBUG)  { print STDERR "result from $builder/$build_num\n"; }
    
    for my $aa (0 .. scalar $$results{'actions'})
        {
        if ($DEBUG)  { print STDERR "-----------------------------aa is $aa\n"; }
        if ( defined( $$results{'actions'}[$aa]{'parameters'} ))
            {
            for my $pp (0 .. scalar keys $$result{'actions'}[$aa]{'parameters'})
                {
                if ($DEBUG)  { print STDERR "pp is $pp-----------------------------\n"; }
                if ($$result{'actions'}[$aa]{'parameters'}[$pp]{'name'} eq 'GERRIT_CHANGE_NUMBER')
                    {
                    $gerrit_num = $$result{'actions'}[$aa]{'parameters'}[$pp]{'value'};
                    if ($DEBUG)  { print STDERR "detected revision: $gerrit_num\n"; }
                    }
                if ($$result{'actions'}[$aa]{'parameters'}[$pp]{'name'} eq 'GERRIT_CHANGE_URL')
                    {
                        $gerrit_url = $$result{'actions'}[$aa]{'parameters'}[$pp]{'value'};
                    if ($DEBUG)  { print STDERR "detected revision: $gerrit_url\n"; }
                    }
                last if (defined( $gerrit_num) && defined( $gerrit_url) );
                }
        }   }
    return($build_num, $is_running, $bld_date, $bld_stat, $gerrit_url, $gerrit_num);
    }
   

############                        last_done_server ( <os>, <arch>, <branch>, <edition> )
#          
#                                   returns ( builder, build_num, job_num, is_build_running, build_date, status )
#          
sub last_done_server
    {
    my ($os, $arch, $branch, $edition) = @_;
    
    my ($builder, $bld_numb, $job_num, $is_running, $bld_date, $isgood);
    
    $builder = jenkinsQuery::get_server_builder($os, $arch, $branch);
    
    if ($DEBUG)  { print STDERR 'DEBUG: running jenkinsQuery::get_json('.$builder.")\n";    }
    my $sumpage = jenkinsQuery::get_json($builder);
    my $len = scalar keys %$sumpage;
    if ($len < 1)
        {
        if ($DEBUG)  { print STDERR "no build results for $builder\n"; }
        $job_num    =  0;
        $bld_num    = -1;
        $is_running =  0;    # 'TBD';
        $bld_date   = 'no package yet';
        $isgood     =  0;
        return( $builder, $bld_num, $job_num, $is_running, $bld_date, $isgood );
        }
    if (! defined( $$sumpage{'builds'} ))
        {
        die "no such field: builds\n";
        }
    my $results_array = $$sumpage{'builds'};
    $len = $#$results_array;
    if ($len < 1)
        {
        if ($DEBUG)  { print STDERR "no build results for $builder\n"; }
        $job_num    =  0;
        $bld_num    = -1;
        $is_running =  0;    # 'TBD';
        $bld_date   = 'no package yet';
        $isgood     =  0;
        return( $builder, $bld_num, $job_num, $is_running, $bld_date, $isgood );
        }
    my @results_numbers;
    my ($found_bldnum, $found_edition, $found_branch, $found_arch);
    if ($arch eq '32' || $arch eq '64')  { $found_arch = $arch; }
    for my $item ( 0 .. $len)  { if ($DEBUG) { print STDERR "array[ $item ] is $$results_array[$item]{'number'}\n"; }
                                               push @results_numbers, $$results_array[$item]{'number'};
                                             }
    if ($DEBUG)  { print STDERR "DEBUG: job_numbers: $#results_numbers\n";  print STDERR "@job_numbers\n";                      }
    if ($DEBUG)  { for my $NN ( @job_numbers ) { print STDERR "$NN\n";}     print STDERR "DEBUG: job_numbers: $#job_numbers\n"; }
    @job_numbers = reverse sort { $a <=> $b } @results_numbers;
    
    for my $jnum (@job_numbers)
        {
        undef($found_bldnum);    undef($found_edition);
        undef($found_branch);    undef($found_arch);
        if ($DEBUG) { print STDERR "...checkint $jnum\n"; }
        $bldpage  = jenkinsQuery::get_json($builder.'/'.$jnum);
        
        if (! defined( $$bldpage{'actions'} ))
            {
            die "no such field: actions\n";
            }
        my ($find_act, $act);
        foreach $find_act ( 0 .. scalar keys $$bldpage{'actions'} )
            {
            if (! defined( $$bldpage{'actions'}[$find_act] ))
                {
                die "no such field: actions[$find_act]\n";
                }
            if (defined( $$bldpage{'actions'}[$find_act]{'parameters'} ))
                {
                $act = $find_act;
                if ($DEBUG)    { print STDERR "parameters are under 'actions'[ ".$act." ]\n"; }
                last;
            }   }
        if (! defined($act) )  { print STDERR "parameters NOT FOUND under 'actions'\n";
                                 die "no parameters found under 'actions'\n";           }
        
        for my $pp (0 .. scalar keys $$bldpage{'actions'}[$act]{'parameters'})
            {
            if ($DEBUG)  { print STDERR "pp is $pp\n"; }
            if ($$bldpage{'actions'}[$act]{'parameters'}[$pp]{'name'} eq 'BLD_NUM')
                {
                $found_bldnum = $$bldpage{'actions'}[$act]{'parameters'}[$pp]{'value'};
                if ($DEBUG)     { print STDERR "detected bldnum:       $found_bldnum\n";}
                }
            if ($$bldpage{'actions'}[$act]{'parameters'}[$pp]{'name'} eq 'RELEASE')
                {
                $found_branch = $$bldpage{'actions'}[$act]{'parameters'}[$pp]{'value'};
                if ($DEBUG)     { print STDERR "detected branch:       $found_branch\n";}
                }
            if ( ($$bldpage{'actions'}[$act]{'parameters'}[$pp]{'name'} eq 'EDITION') ||
                 ($$bldpage{'actions'}[$act]{'parameters'}[$pp]{'name'} eq 'LICENSE')  )
                {
                $found_edition = $$bldpage{'actions'}[$act]{'parameters'}[$pp]{'value'};
                if ($DEBUG)     { print STDERR "detected edition:      $found_edition\n";}
                }
            if ($$bldpage{'actions'}[$act]{'parameters'}[$pp]{'name'} eq 'ARCHITECTURE')
                {
                $found_arch   = $$bldpage{'actions'}[$act]{'parameters'}[$pp]{'value'};
                if ($DEBUG)     { print STDERR "detected architecture: $found_arch\n";}
                }
            last if ( defined($found_bldnum) && defined($found_edition) && defined($found_branch) && defined($found_arch) );
            }
        if ( $found_edition eq $edition && $found_arch eq $arch && $found_branch eq $branch )  { $bld_num = $found_bldnum;  $job_num = $jnum;  last; }
        }
    
    if (! defined($job_num) )
        {
        if ($DEBUG)  { print STDERR "no builds of $edition by $builder\n"; }
        $job_num    =  0;
        $bld_num    = -1;
        $is_running =  0;    # 'TBD';
        $bld_date   = 'no package yet';
        $isgood     =  0;
        return( $builder, $bld_num, $job_num, $is_running, $bld_date, $isgood );
        }
    
    my $result  = jenkinsQuery::get_json($builder.'/'.$job_num);
    $is_running = 'unknown';
    if (defined( $$result{'building'} ))  { $is_running = ($$result{'building'} ne 'false');        if ($DEBUG) {print STDERR "setting is_running to $$result{'building'}\n";}}
    
    $bld_date   = 'unknown';
    if (defined( $$result{'id'}       ))  { $bld_date   =  date_from_id( $$result{'id'}, 'brief' ); if ($DEBUG) {print STDERR "setting bld_date   to $bld_date\n"; }          }
    
    $isgood     = 'unknown';
    if (defined( $$result{'result'}   ))  { $isgood     = ($$result{'result'}   eq 'SUCCESS');      if ($DEBUG) {print STDERR "setting isgood     to :$$result{'result'}:\n";}}
    
    return( $builder, $bld_num, $job_num, $is_running, $bld_date, $isgood );
    }


############                        last_done_toy_server ( <os>, <arch>, <branch>, <manifest> )
#          
#                                   returns ( builder, job_num, is_build_running, build_date, status )
#          
sub last_done_toy_server
    {
    my ($os, $arch, $branch, $manifest) = @_;
    
    my $builder  = jenkinsQuery::get_server_builder($os, $arch, $branch, $manifest);
    
    if ($DEBUG)  { print STDERR 'DEBUG: running jenkinsQuery::get_json('.$builder.")\n";    }
    my $sumpage = jenkinsQuery::get_json($builder);
    my $len = scalar keys %$sumpage;
    if ($len < 1 )
        {                   if ($DEBUG)  { print STDERR "DEBUG: no builds yet!\n"; }
        $job_num    = -1;
        $is_running =  0;    # 'TBD';
        $bld_date   = 'no package yet';
        $isgood     =  0;
        return( $builder, $job_num, $is_running, $bld_date, $isgood );
        }
    if (! defined( $$sumpage{'builds'} ))
        {
        die "no such field: builds\n";
        }
    my $results_array = $$sumpage{'builds'};
    $len = $#$results_array;
    if ($len < 1)
        {
        if ($DEBUG)  { print STDERR "no build results for $builder\n"; }
        $job_num    = -1;
        $is_running =  0;    # 'TBD';
        $bld_date   = 'no package yet';
        $isgood     =  0;
        return( $builder, $job_num, $is_running, $bld_date, $isgood );
        }
    my @results_numbers;
    my ($found_bldnum, $found_edition);
    for my $item ( 0 .. $len)  { if ($DEBUG) { print STDERR "array[ $item ] is $$results_array[$item]{'number'}\n"; }
                                               push @results_numbers, $$results_array[$item]{'number'};
                                             }
    if ($DEBUG)  { print STDERR "DEBUG: job_numbers: $#results_numbers\n";  print STDERR "@job_numbers\n";                      }
    if ($DEBUG)  { for my $NN ( @job_numbers ) { print STDERR "$NN\n";}     print STDERR "DEBUG: job_numbers: $#job_numbers\n"; }
    @job_numbers = reverse sort { $a <=> $b } @results_numbers;
    
    for my $jnum (@job_numbers)
        {
        undef($found_manifest);
        if ($DEBUG) { print STDERR "...checkint $jnum\n"; }
        $bldpage  = jenkinsQuery::get_json($builder.'/'.$jnum);
        
        if (! defined( $$bldpage{'actions'} ))
            {
            die "no such field: actions\n";
            }
        if (! defined( $$bldpage{'actions'}[0] ))
            {
            die "no such field: actions[0]\n";
            }
        if (! defined( $$bldpage{'actions'}[0]{'parameters'} ))
            {
            die "no such field: actions[0]{parameters}\n";
            }
        for my $pp (0 .. scalar keys $$bldpage{'actions'}[0]{'parameters'})
            {
            if ($DEBUG)  { print STDERR "pp is $pp\n"; }
            if ($$bldpage{'actions'}[0]{'parameters'}[$pp]{'name'} eq 'MANIFEST')
                {
                $found_manifest = $$bldpage{'actions'}[0]{'parameters'}[$pp]{'value'};
                if ($DEBUG)     { print STDERR "detected manifest:   $found_manifest\n";}
                }
            last if ( defined($found_manifest) );
            }
        if ( $found_manifest eq $manifest )  { $job_num = $jnum;  last; }
        }
    if (! defined($job_num) )
        {
        if ($DEBUG)  { print STDERR "no builds of $manifest by $builder\n"; }
        $job_num    = -1;
        $is_running =  0;    # 'TBD';
        $bld_date   = 'no package yet';
        $isgood     =  0;
        return( $builder, $job_num, $is_running, $bld_date, $isgood );
        }
    
    my $result  = jenkinsQuery::get_json($builder.'/'.$job_num);
    $is_running = 'unknown';
    if (defined( $$result{'building'} ))  { $is_running = ($$result{'building'} ne 'false');        if ($DEBUG) {print STDERR "setting is_running to $$result{'building'}\n";}}
    
    $bld_date   = 'unknown';
    if (defined( $$result{'id'}       ))  { $bld_date   =  date_from_id( $$result{'id'}, 'brief' ); if ($DEBUG) {print STDERR "setting bld_date   to $bld_date\n"; }          }
    
    $isgood     = 'unknown';
    if (defined( $$result{'result'}   ))  { $isgood     = ($$result{'result'}   eq 'SUCCESS');      if ($DEBUG) {print STDERR "setting isgood     to :$$result{'result'}:\n";}}
    
    return( $builder, $job_num, $is_running, $bld_date, $isgood );
    }

1;
__END__

