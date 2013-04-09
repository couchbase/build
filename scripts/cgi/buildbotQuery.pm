#!/bin/perl
# 
############ 

package buildbotQuery;

use strict;

use Exporter qw(import);
#use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT      = ();
our @EXPORT_OK   = qw( get_URL_root html_builder_link html_OK html_ERROR_msg html_OK_link html_FAIL_link
                       get_json get_build_revision get_build_date is_running_build is_good_build );

our %EXPORT_TAGS = ( HTML  => [qw( &get_URL_root &html_builder_link &html_OK &html_ERROR_msg &html_OK_link &html_FAIL_link )],
                     JSON  => [qw( &get_json  &get_build_revision  &get_build_date  &is_running_build  &is_good_build      )] );

############ 

use CGI qw(header -no_debug);

use JSON;
my $json = JSON->new;

use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

my $USERID='buildbot';
my $PASSWD='buildbot';
my $URL_ROOT='http://qa.hq.northscale.net:8010';

my $DEBUG = 0;


############ HTML


############                        get_URL_root ( )
#          
#                                   returns $URL_ROOT
sub get_URL_root
    {
    return $URL_ROOT;
    }


############                        html_builder_link ( <builder>, <build_num> )
#          
#                                   returns HTML of link to good build results
sub html_builder_link
    {
    my ($bder) = @_;
    my $HTML = '<a href="'. $URL_ROOT .'/builders/'. $bder .'">'. $bder .'</a>';
    
    return($HTML);
    }

############                        html_OK
#          
#                                   returns HTML of greeen OK
sub html_OK
    {
    return '<font color="green">OK</font>';
    }

############                        html_ERROR_msg
#          
#                                   returns HTML of red ERROR message
sub html_ERROR_msg
    {
    my ($msg) = @_;
    
    return '<font color="red">'. $msg .'</font>';
    }


############                        html_OK_link ( <builder>, <build_num> )
#          
#                                   returns HTML of link to good build results
sub html_OK_link
    {
    my ($bder, $bnum, $rev, $date) = @_;
    
    my $HTML='<a href="'. $URL_ROOT .'/builders/'. $bder .'/builds/'. $bnum .'">'. "$rev ($date)" .'</a>';
    return($HTML);
    }

############                        html_FAIL_link ( <builder>, <build_num> )
#          
#                                   HTML of link to FAILED build results
sub html_FAIL_link
    {
    my ($bder, $bnum) = @_;
    my $HTML='';
    
    return($HTML);
    }

###########  JSON


############                        get_json ( <builder>, <optional_URL_extension> )
#          
sub get_json
    {
    my ($bldr, $optpath) = @_;
    my $returnref;
    
    my $request  = $URL_ROOT .'/json/builders/'. $bldr .'/builds';
    if (defined $optpath)  { $request .= $optpath;  }
    if ($DEBUG)  { print "\nrequest: $request\n\n"; }
    my $response = $ua->get($request);
    if ($DEBUG)  { print "respons: $response\n\n";  }
    
    if ($response->is_success)
        {
        $returnref = $json->decode($response->decoded_content);
        return $returnref;
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
        if ($DEBUG)  { print "(good ref.) $$jsonref{properties}\n"; }
        if ( defined( $$jsonref{properties}))
            {
            my $lol = $$jsonref{properties};
            if ($DEBUG)  { print "DEBUG: list-of-lists  is $lol\n"; }
            for my $lil (@$lol)
                {
                if ($DEBUG)  { print "DEBUG: little in list is $lil\n"; }
                if ( $$lil[0] eq 'git_describe' )
                    {
                    if ($DEBUG)  { print "DEBUG: key is $$lil[0]\n"; }
                    if ($DEBUG)  { print "DEBUG: 1st is $$lil[1]\n"; }
                    if ($DEBUG)  { print "DEBUG: 2nd is $$lil[2]\n"; }
                    return $$lil[1];
                    }
                else { if ($DEBUG)  { print "DEBUG: key is $$lil[0]\n"; }}
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
        
        if ($DEBUG)  { print "DEBUG: start is $start\n"; }
        if ($DEBUG)  { print "DEBUG: end   is $end  \n"; }
        my $end_time = int(0+ $end );
        if ($DEBUG)  { print "DEBUG: found end_time: $end_time\n"; }
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
    if ( defined($$jsonref{results}) && $DEBUG )  { print "DEBUG: results is: $$jsonref{results}\n"; }
    if ($DEBUG)  { print "DEBUG: called is_running_build($jsonref)\n"; }
    return (! defined($$jsonref{results}) );
    }


############                        is_good_build ( <json_hash_ref> )
#          
#                                   returns TRUE if "results" value is 0
sub is_good_build
    {
    my ($jsonref) = @_;
    if ( defined($$jsonref{results}) )
        {
        if ($DEBUG)  { print "DEBUG: results is:$$jsonref{results}:\n"; 
        if     ($$jsonref{results} == 0 ) { print 'TRUE '; }  else { print 'False '; }
                     }
        return ($$jsonref{results} == 0 );
        }
    print "ERROR: bad ref\n\n";
    return(0 == 1);
    }

1;
__END__
