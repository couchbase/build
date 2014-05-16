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
                       last_done_ios_bld      last_good_ios_bld      last_done_and_bld      last_good_and_bld     \
                       get_builder            link_to_package                                                     \
                       last_done_repo         last_commit_valid      last_done_server                             \
                     );

our %EXPORT_TAGS = ( SYNC_GATEWAY => [qw( &last_done_sgw_trigger  &last_done_sgw_package   &last_good_sgw_trigger  &last_good_sgw_package )],
                     IOS_ANDROID  => [qw( &last_done_ios_bld      &last_good_ios_bld       &last_done_and_bld      &last_good_and_bld     )],
                     DEFAULT      => [qw( &get_builder            &link_to_package         \
                                          &last_done_repo         &last_commit_valid       &last_done_server  )],
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
    my ($platform, $branch, $type, $prod) = @_;
    my  $builder;
    
    if ($type eq 'repo')     { $builder = jenkinsQuery::get_repo_builder($branch);      }
    if ($type eq 'trigger')
        {
        if ($prod eq 'sgw')  { $builder = "build_sync_gateway_".$branch;    }
        }
    if ($type eq 'build')
        {
        if ($prod eq 'ios')  { $builder = "build_cblite_ios_".$branch;      }
        if ($prod eq 'and')  { $builder = "build_cblite_android_".$branch;  }
        }
    if ($type eq 'package')
        {
        my  $plat = $platform;
        if ($plat =~ 'windows-(.*)') { $plat = 'win-2008-'.$1; }
        $builder = "build_sync_gateway_".$branch."_".$plat;
        }
    return($builder);
    }

############                        link_to_package( prod, revision, platform, edtion )
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
        if ($edition eq 'community') { $pkg_name = 'couchbase-lite-'.$revision.'-android-community.zip'; }
        else                         { $pkg_name = 'couchbase-lite-'.$revision.'-android.zip';           }
        $display = 'ZIP';
        }
    elsif ($prod eq 'ios')
        {
        if ($edition eq 'community') { $pkg_name = 'cblite_ios_'    .$revision.'-community.zip';         }
        else                         { $pkg_name = 'cblite_ios_'    .$revision.'.zip';                   }
        $display = 'ZIP';
        }
    else
        {
        my %pkg_sfx = ( 'enterprise' => { 'centos-x64' => 'x86_64.rpm',
                                          'centos-x86' => 'i386.rpm',
                                          'macosx-x64' => 'macosx-x86_64.tar.gz',
                                          'ubuntu-x64' => 'amd64.deb',
                                          'ubuntu-x86' => 'i386.deb',
                                        },
                        'community'  => { 'centos-x64' => 'x86_64-community.rpm',
                                          'centos-x86' => 'i386-community.rpm',
                                          'macosx-x64' => 'macosx-x86_64-community.tar.gz',
                                          'ubuntu-x64' => 'amd64-community.deb',
                                          'ubuntu-x86' => 'i386-community.deb',
                      },                );
        $pkg_name = "couchbase-sync-gateway"."_".$revision."_".$pkg_sfx{$edition}{$platform};
        
        my %display = ( 'centos-x64' => 'RPM',  'centos-x86' => 'RPM',
                        'ubuntu-x64' => 'DEB',  'ubuntu-x86' => 'DEB',
                        'macosx-x64' => 'TGZ',
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


############                        last_done_sgw_package ( platform, branch )
#          
#                                   returns ( job_num, build_num, is_build_running, build_date, status )
sub last_done_sgw_package
    {
    my ($platform, $branch) = @_;
    my $builder  = get_builder($platform, $branch, "package", "sgw");
    my ($jobnum, $bldnum, $is_running, $bld_date, $isgood);
    
    my %job_branch_token = ( 'master'        => 'master',
                             'release/1.0.0' => '100',
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
    my ($found_bldnum, $found_branch);
    for my $item ( 0 .. $len)  { if ($DEBUG) { print STDERR "array[ $item ] is $$results_array[$item]{'number'}\n"; }
                                               push @results_numbers, $$results_array[$item]{'number'};
                                             }
    @job_numbers = reverse sort { $a <=> $b } @results_numbers;
    if ($DEBUG)  { print STDERR "DEBUG: job_numbers: $#job_numbers\n";   print STDERR "@job_numbers\n";                      }
    if ($DEBUG)  { for my $NN ( @job_numbers ) { print STDERR "$NN\n";}  print STDERR "DEBUG: job_numbers: $#job_numbers\n"; }
    for my $jnum (@job_numbers)
        {
        undef($found_bldnum);    undef($found_branch);
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
        for my $pp (0 .. scalar $$bldpage{'actions'}[0]{'parameters'})
            {
            if ($DEBUG)  { print STDERR "pp is $pp\n"; }
            if ($$bldpage{'actions'}[0]{'parameters'}[$pp]{'name'} eq 'REVISION')
                {
                $found_bldnum = $$bldpage{'actions'}[0]{'parameters'}[$pp]{'value'};
                if ($DEBUG)  { print STDERR "detected revision: $found_bldnum\n"; }
                }
            if ($$bldpage{'actions'}[0]{'parameters'}[$pp]{'name'} eq 'GITSPEC')
                {
                $found_branch = $$bldpage{'actions'}[0]{'parameters'}[$pp]{'value'};
                if ($DEBUG)  { print STDERR "detected branch:   $found_branch\n"; }
                }
            last if ( defined($found_bldnum) && defined($found_branch) );
            }
        if ($job_branch_token{$found_branch} eq $branch)  { $jobnum = $jnum; last; }
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
 
    return( $jobnum, $found_bldnum, $is_running, $bld_date, $isgood );
    }



############                        last_done_sgw_trigger ( branch )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_done_sgw_trigger
    {
    ($branch) = @_;
    my $builder  = get_builder('None',  $branch, "trigger", "sgw");
    my $property = 'lastCompletedBuild';
    return_build_info($builder, $property);
    }
   
############                        last_good_sgw_trigger ( branch )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_good_sgw_trigger
    {
    ($branch) = @_;
    my $builder  = get_builder('None', $branch, "trigger", "sgw");
    my $property = 'lastSuccessfulBuild';
    return_build_info($builder, $property);
    }
   


############                        last_done_ios_bld ( platform, branch )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_done_ios_bld
    {
    ($platform, $branch) = @_;
    my $builder  = get_builder($platform, $branch, "build", "ios");
    my $property = 'lastCompletedBuild';
    return_build_info($builder, $property);
    }
   
############                        last_good_ios_bld ( platform, branch )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_good_ios_bld
    {
    ($platform, $branch) = @_;
    my $builder  = get_builder($platform, $branch, "build", "ios");
    my $property = 'lastSuccessfulBuild';
    return_build_info($builder, $property, 'brief');
    }
   

############                        last_done_and_bld ( platform, branch )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_done_and_bld
    {
    ($platform, $branch) = @_;
    my $builder  = get_builder($platform, $branch, "build", "and");
    my $property = 'lastCompletedBuild';
    return_build_info($builder, $property);
    }
   
############                        last_good_and_bld ( platform, branch )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_good_and_bld
    {
    ($platform, $branch) = @_;
    my $builder  = get_builder($platform, $branch, "build", "and");
    my $property = 'lastSuccessfulBuild';
    return_build_info($builder, $property, 'brief');
    }
   



############                        last_done_repo ( branch )
#          
#                                   returns ( build_num, is_build_running, build_date, status )
sub last_done_repo
    {
    ($branch) = @_;
    my $builder  = get_builder($platform,$branch, "repo","repo");
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
#                                   returns ( build_num, is_build_running, build_date, status, change_url )
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
            for my $pp (0 .. scalar $$result{'actions'}[$aa]{'parameters'})
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
   

############                        last_done_server ( <os>, <arch>, <branch> )
#          
#                                   returns ( build_num, is_build_running, build_date, status, change_url )
#          
sub last_done_server
    {
    my ($os, $arch, $branch) = @_;
    
    my $builder  = jenkinsQuery::get_server_builder($os, $arch, $branch);
    my $property = 'lastCompletedBuild';
    return_build_info($builder, $property);
    }

1;
__END__

