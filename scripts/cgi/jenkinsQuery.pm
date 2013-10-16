#!/bin/perl
# 
############ 

package jenkinsQuery;

use strict;

use Exporter qw(import);
#use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT      = ();
our @EXPORT_OK   = qw( test_running_indicator response_code test_job_status trigger_jenkins_url );

our %EXPORT_TAGS = ( DEFALUT  => [qw( &test_running_indicator &response_code &test_job_status &trigger_jenkins_url )] );

############ 

use CGI qw(header -no_debug);

use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

use JSON;
my $json = JSON->new;

#use XML::Parser;
#my $xml = new XML::Parser(Style => 'Tree');

my $USERID='buildbot';
my $PASSWD='buildbot';
my $URL_ROOT='http://builds.hq.northscale.net:8010';

my $DEBUG = 0;



############                        test_running_indicator ( <installed_URL>, <test job number>, <test_job_url> )
#          
#           
sub test_running_indicator
    {
    my ($installed_URL, $test_job_num, $test_job_url) = @_;
    my $run_icon  = 'test&nbsp;'.$test_job_num.'<IMG SRC="' .$installed_URL. '/running_20.gif" ALT="running..." HSPACE="50" ALIGN="TOP">';
    my $run_icon  = 'test&nbsp;<a href="'.$test_job_url.'">'.$test_job_num.'</a>&nbsp;running...';

    return $run_icon;
    }

############                        response_code ( <http response> )
#          
#          
#                                   returns ( http status code )
sub response_code
    {
    my ($resp) = @_;
    my  $stat  = $resp->status_line;
    my  $srex  = '^([0-9]{3})';
    if ($stat =~ $srex)
        {
        my $code = $1;
        if ($DEBUG)  { print STDERR "HTTP code from [ $stat ] = $code\n"; }
        return $code;
        }
    return(0);
    }



############                        test_job_status ( test_job_url, rev_num )
#          
#                                   returns ( test_job_num, job_status, test_running ),
#                                        or ( 0, 0 ),                                  if no matching test (e.g., not completed yet)
#                                        or ( 0, status_code)                          if http response not 200
sub test_job_status
    {
    my ($test_job_url, $rev_num) = @_;           if ($DEBUG)  { print STDERR "calling test_job_status( $test_job_url, $rev_num )\n";  }
    
    my ($test_job_num, $job_status, $test_running) = (0,0,0);
    
    my $request  = $test_job_url .'/api/json/builds/';
    my $response = $ua->get($request);
    my $code = response_code($response);         if ($DEBUG)  { print STDERR "response to $request\n         is $code\n"; }
    
    if (! $response->is_success)
        {
        return(0, $code);
        }
    my $content = $response->decoded_content;    if ($DEBUG)  { print STDERR "content:$content\n"; }
    my $jsonref = $json->decode($content);
    my $results_array = $$jsonref{'builds'};
    my $len = $#$results_array;
    if ($len < 1)
        {
        if ($DEBUG)  { print STDERR "no test results for $test_job_url\n"; }
        return(0,0);
        }
    my @results_numbers;
    my %param_ref;
    for my $item ( 0 .. $len)  { if ($DEBUG) { print STDERR "array[ $item ] is $$results_array[$item]\n"; }
                                               push @results_numbers, $$results_array[$item]{'number'};
                                             }
    for my $tnum ( (reverse sort @results_numbers ) )
        {
        $request  = $test_job_url.'/'.$tnum.'/api/json/builds/';
        if ($DEBUG)  { print STDERR "[ $tnum ]:: $request \n"; }
        $response = $ua->get($request);
        $code = response_code($response);    if ($DEBUG)  { print STDERR "response to $request\n         is $code\n"; }
        $response = $ua->get($request);
        if (! $response->is_success)
            {
            if ($DEBUG) { print STDERR "RESPONSE: $code\n          $response->status_line\n"; }
            return(0, $code);
            }
        $jsonref = $json->decode($response->decoded_content);
        if ( ! defined( $$jsonref{'actions'} ))
            {
            if ($DEBUG)  { print STDERR "no test results for $test_job_url\n"; }
            return(0,0);
            }
        
        if ( ! defined(  $$jsonref{'actions'}[0]{'parameters'} ))
            {
            if ($DEBUG)  { print STDERR "no test results for $test_job_url\n"; }
            return(0,0);
            }
         
        my $param_array = $$jsonref{'actions'}[0]{'parameters'};
        for my $item (0 .. $#$param_array)  { $param_ref{$$param_array[$item]{'name'}} = $$param_array[$item]{'value'};
                                              if ($DEBUG) { print STDERR "item $item has name  $$param_array[$item]{'name'}\n";  }
                                              if ($DEBUG) { print STDERR "item $item has value $$param_array[$item]{'value'}\n"; }
                                            }
        my $version = $param_ref{'version_number'};
        if ($version == $rev_num)
            {
            if ($DEBUG) { print STDERR "item has version $version\n"; }
            $test_job_num = $tnum;
            $test_running = $$jsonref{'building'};
            $job_status   = $$jsonref{'result'};
            last;
        }   }
    
    return ( $test_job_num, $job_status, $test_running );
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
