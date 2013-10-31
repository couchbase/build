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
                       get_json get_build_revision get_build_date is_running_build is_good_build trigger_jenkins_url );

our %EXPORT_TAGS = ( HTML  => [qw( &get_URL_root  &html_builder_link  &html_OK  &html_ERROR_msg  &html_OK_link  &html_FAIL_link )],
                     JSON  => [qw( &get_json &get_build_revision &get_build_date &is_running_build &is_good_build &trigger_jenkins_url )] );

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
my $URL_ROOT='http://builds.hq.northscale.net:8010';

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
    my $HTML = '<a href="'. $URL_ROOT .'/builders/'. $bder .'" target="_blank">'. $bder .'</a>';
    
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


############                        html_OK_link ( <builder>, <job_number>, <build_num>, <job_date> )
#          
#                                   returns HTML of link to good build results
sub html_OK_link
    {
    my ($bder, $bnum, $rev, $date) = @_;
    
    my $HTML='<a href="'. $URL_ROOT .'/builders/'. $bder .'/builds/'. $bnum .'" target="_blank">'. "$rev".'&nbsp;'."($date)" .'</a>';
    return($HTML);
    }

############                        html_FAIL_link ( <builder>, <build_num>, <is_running>, <build_date> )
#          
#                                   HTML of link to FAILED build results
sub html_FAIL_link
    {
    my ($bder, $bnum, $is_running, $date) = @_;
    
    my $HTML = '<font color="red">FAIL</font>&nbsp;&nbsp;' ."($date)". '&nbsp;&nbsp;'
              .'<a href="'.$URL_ROOT.'/builders/'.$bder.'/builds/'.$bnum.'" target="_blank">build logs</a>';
    
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
    if ($DEBUG)  { print STDERR "\nrequest: $request\n\n"; }
    my $response = $ua->get($request);
    if ($DEBUG)  { print STDERR "respons: $response\n\n";  }
    
    if ($response->is_success)
        {
        $returnref = $json->decode($response->decoded_content);
        return $returnref;
        }
    else
       {
       if ($response->status_line =~ '404')  { return(0); }
       die $response->status_line;
    }  }

sub get_build_revision
    {
    my ($jsonref) = @_;
    
    if ( defined( $$jsonref{properties} ))
        {
        if ($DEBUG)  { print STDERR "(good ref.) $$jsonref{properties}\n"; }
        if ( defined( $$jsonref{properties}))
            {
            my $lol = $$jsonref{properties};
            if ($DEBUG)  { print STDERR "DEBUG: list-of-lists  is $lol\n"; }
            for my $lil (@$lol)
                {
                if ($DEBUG)  { print STDERR "DEBUG: little in list is $lil\n"; }
                if ( $$lil[0] eq 'git_describe' )
                    {
                    if ($DEBUG)     { print STDERR "DEBUG: key is $$lil[0]\n"; }
                    if ($DEBUG)     { print STDERR "DEBUG: 1st is $$lil[1]\n"; }
                    if ($DEBUG)     { print STDERR "DEBUG: 2nd is $$lil[2]\n"; }
                    return $$lil[1];
                    }
                else { if ($DEBUG)  { print STDERR "DEBUG: key is $$lil[0]\n"; }}
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
        
        if ($DEBUG)  { print STDERR "DEBUG: start is $start\n"; }
        if ($DEBUG)  { print STDERR "DEBUG: end   is $end  \n"; }
        my $end_time = int(0+ $end );
        if ($DEBUG)  { print STDERR "DEBUG: found end_time: $end_time\n"; }
        my ($second, $minute, $hour, $dayOfMonth, $month, $year, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime(int($end_time));
        $year  += 1900;
        $month += 1;
     #  return $year .'-'. $month .'-'. $dayOfMonth;
        return $month .'/'. $dayOfMonth .'/'. $year;
        }
    die "Bad Reference\n";
    }


############                        is_running_build ( <json_hash_ref> )
#          
#                                   returns TRUE if "results" value is null
sub is_running_build
    {
    my ($jsonref) = @_;    return ($jsonref) if ($jsonref==0);
    
    if ( defined($$jsonref{results}) && $DEBUG )  { print STDERR "DEBUG: results is: $$jsonref{results}\n"; }
    if ($DEBUG)  { print STDERR "DEBUG: called is_running_build($jsonref)\n"; }
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
        if ($DEBUG)  { print STDERR "DEBUG: results is:$$jsonref{results}:\n"; 
        if     ($$jsonref{results} == 0 ) { print 'TRUE '; }  else { print 'False '; }
                     }
        return ($$jsonref{results} == 0 );
        }
    print STDERR "ERROR: bad ref\n\n";
    return(0 == 1);
    }

############                        trigger_jenkins_url ( <builder>, <bld_num> )
#          
#                                   returns (URL of test job, build number),
#                                        or (0, 0)           if none found,
#                                        or (0, status_code) if not 200
sub trigger_jenkins_url
    {
    my ($builder, $bld_num) = @_;
    my $url_rex = 'curl &#39;(.*)&#39;';
    
    my $request = $URL_ROOT.'/builders/'.$builder.'/builds/'.$bld_num.'/steps/trigger%20jenkins/logs/stdio';
    if ($DEBUG)  { print STDERR "request: $request\n\n";  }
    
    my $response = $ua->get($request);
    if ($DEBUG)  { print STDERR "respons: $response\n\n";  }

    if ($response->is_success)
        {
        if ($DEBUG)  { print STDERR "FOUND IT\n"; }
        my $content = $response->decoded_content;
        if ( $content =~ $url_rex )
            {
            my $curlurl = $1;
            my ($jenkins_url, $version_num) = (0, 0);
            
            if ($DEBUG)  { print STDERR "IT MATCHES\n"; }
            if ($curlurl =~ '(.*)/buildWithParameters'         )  { $jenkins_url = $1; }
            if ($curlurl =~ 'version_number=([0-9a-zA-Z._-]*)' )  { $version_num = $1; }
            return($jenkins_url, $version_num);
            }
        if ($DEBUG)  { print STDERR "cannot find curl request in:\n\n".$content."\n"; }
        return(0);
        }
    else
       {
       if ($DEBUG)  { print STDERR "DEBUG: no response!  Got status line:\n\n".$response->status_line."\n"; }
       if ($response->code eq 404)  { return(0,0); }
       return(0, $response->code);
    }  }

1;
__END__
