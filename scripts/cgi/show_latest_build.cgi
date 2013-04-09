#!/usr/bin/perl

# queries buildbot JSON api to find latest good build of a specific builder.
#  
#  Call with these parameters:
#  
#  BUILDER         e.g. cs-win2008-x64-20-builder-202
#  BRANCH          e.g. 2.0.2.  NOTE: must match!
#  

my $builder    = 'cs-win2008-x64-20-builder-202';    my $branch = '2.0.2';

use warnings;
#use strict;

use LWP::UserAgent;
use CGI qw(header -no_debug);


# if we don't do this it will buffer and then print results
# I want to see results immediately as it happens.
# not every server configuration supports this
$|++;

use JSON;
my $json = JSON->new;


my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

my $USERID='buildbot';
my $PASSWD='buildbot';

#my $URL_ROOT='http://'. $USERID .':'. $PASSWD .'@qa.hq.northscale.net:8010';
my $URL_ROOT='http://qa.hq.northscale.net:8010';
 

############                        get_json ( <builder>, <optional_URL_extension> )
#          
sub get_json
    {
    my ($bldr, $optpath) = @_;
    
    my $request  = $URL_ROOT .'/json/builders/'. $bldr .'/builds';
    if (defined $optpath)  { $request .= $optpath; }
    print "\nrequest: $request\n\n";
    my $response = $ua->get($request);
    print "respons: $response\n\n";
    
    if ($response->is_success)
        {
        return $json->decode($response->decoded_content);
        }
    else
       {
       die $response->status_line;
    }  }

sub get_build_revision
    {
    my ($jsonref) = @_;
    
    if ( defined( $$jsonref{properties} ))
        {
        print "(good ref.) $$jsonref{properties}\n";
        if ( defined( $$jsonref{properties}))
            {
            my $lol = $$jsonref{properties};
            print "DEBUG: list-of-lists  is $lol\n";
            for my $lil (@$lol)
                {
                print "DEBUG: little in list is $lil\n";
                if ( $$lil[0] eq 'git_describe' )
                    {
                    print "DEBUG: key is $$lil[0]\n"; 
                    print "DEBUG: 1st is $$lil[1]\n"; 
                    print "DEBUG: 2nd is $$lil[2]\n"; 
                    return $$lil[1];
                    }
                else { print "DEBUG: key is $$lil[0]\n"; }
                }
        }   }
    die "Bad Reference\n";
    }

sub get_build_date
    {
    my ($jsonref) = @_;
    
    if ( defined( $$jsonref{times} ))
        {
        my $times = $$jsonref{times};
        my ($start, $end) = ( $$times[0], $$times[1] );
        
        print "DEBUG: start is $start\n";
        print "DEBUG: end   is $end  \n";
        my $end_time = int(0+ $end );
        print "DEBUG: found end_time: $end_time\n";
        my ($second, $minute, $hour, $dayOfMonth, $month, $year, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime(int($end_time));
        $year += 1900;
        return $year .'-'. $month .'-'. $dayOfMonth;
        }
    die "Bad Reference\n";
    }


############                        is_running_build ( <json_hash_ref> )
#          
#                                   returns TRUE if "results" value is null
sub is_running_build
    {
    my ($jsonref) = @_;
    if ( defined($$jsonref{results}) )  { print "DEBUG: results is: $$jsonref{results}\n"; }
    print "DEBUG: called is_running_build($jsonref)\n";    return (! defined($$jsonref{results}) );
    }


############                        is_good_build ( <json_hash_ref> )
#          
#                                   returns TRUE if "results" value is 0
sub is_good_build
    {
    my ($jsonref) = @_;
    if ( defined($$jsonref{results}) )
        {
        print "DEBUG: results is:$$jsonref{results}:\n";
        if     ($$jsonref{results} == 0 ) { print 'TRUE '; }  else { print 'False '; }
        return ($$jsonref{results} == 0 );
        }
    print "ERROR: bad ref\n\n";
    return(0 == 1);
    }

############                        emit_builder_link ( <builder>, <build_num> )
#          
#                                   returns HTML of link to good build results
sub emit_builder_link
    {
    my ($bder) = @_;
    my $HTML = '<a href="'. $URL_ROOT .'/builders/'. $bder .'">'. $bder .'</a>';
    
    return($HTML);
    }

############                        emit_OK
#          
#                                   returns HTML of greeen OK
sub emit_OK
    {
    return '<font color="green">OK</font>';
    }

############                        emit_ERROR
#          
#                                   returns HTML of red ERROR message
sub emit_ERROR
    {
    my ($msg) = @_;
    
    return '<font color="red">'. $msg .'</font>';
    }


############                        emit_OK_link ( <builder>, <build_num> )
#          
#                                   returns HTML of link to good build results
sub emit_OK_link
    {
    my ($bder, $bnum, $rev, $date) = @_;
    
    my $HTML='<a href="'. $URL_ROOT .'/builders/'. $bder .'/builds/'. $bnum .'">'. "$rev ($date)" .'</a>';
    return($HTML);
    }

############                        emit_FAIL_link ( <builder>, <build_num> )
#          
#                                   HTML of link to FAILED build results
sub emit_FAIL_link
    {
    my ($bder, $bnum) = @_;
    my $HTML='';
    
    return($HTML);
    }



my $all_builds = get_json($builder);

my ($bldnum, $result);
foreach my $KEY (keys $all_builds)
    {
    $VAL = $$all_build{$KEY};
    if (! defined $VAL)  { $$all_build{$KEY}="null" }
    }

foreach $KEY (reverse sort { 0+$a <=> 0+$b } keys $all_builds)
    {
    $bldnum = $KEY;
    print "....$bldnum   $$all_build{$bldnum}\n";
    $result = get_json($builder, '/'.$bldnum);
    print "....is $bldnum running?\n";
    if ( is_running_build( $result) )    { print "$bldnum is still running\n"; }
    else                                 { last;                               }
    }

print "\n---------------------------\n";
print emit_builder_link($builder);
print "\n---------------------------\n";
print emit_OK();
print "\n---------------------------\n";
print emit_ERROR("compile failure, jackson");
print "\n---------------------------\n";

if  ( is_good_build( $result) )
    {
    my $rev_numb = $branch .'-'. get_build_revision($result);
    print "... rev_numb is $rev_numb...\n";
    my $bld_date = get_build_date($result);
    print "... bld_date is $bld_date...\n";
    
    print "GOOD: $bldnum\n"; print emit_OK_link(   $builder, $bldnum, $rev_numb, $bld_date );
    }
else
    { print "FAIL: $bldnum\n"; print emit_FAIL_link( $builder, $bldnum ); }

print "\n---------------------------\n";
__END__

