#!/usr/bin/perl

use warnings;
#use strict;
$|++;

use File::Basename;
use Cwd qw(abs_path);
BEGIN
    {
    $THIS_DIR = dirname( abs_path($0));    unshift( @INC, $THIS_DIR );
    }

my $URL_ROOT='http://factory.hq.couchbase.com:8080';

use Getopt::Std;

my $usage = "\nuse:  $0 -j job_name -p param -v new_value\n\n";

use LWP::UserAgent;
my $ua = LWP::UserAgent->new;
$ua->timeout(10);
$ua->env_proxy;

use XML::Simple qw(:strict);
my $xml = XML::Simple->new();

my ($job_name, $param, $new_val);

my $DEBUG = 1;
use Data::Dumper;


my ($jenkins_user, $jenkins_api_token) = ('self.jenkins', '871e176226f645f2011fd50c5cb1a1eb');

############                        get_config ( <job_name> )
#          
#                                   returns config file contents if successful,
#
#                                   else returns 0
sub get_config
    {
    my ($job) = @_;
    my  $req;
    my  $config;
    
    my $request_url  = $URL_ROOT .'/job/'. $job .'/config.xml';
    if ($DEBUG)  { print STDERR "\nrequest: $request_url\n\n"; }
    $request = HTTP::Request->new(GET => $request_url);
    $request->authorization_basic($jenkins_user, $jenkins_api_token);
    my $response = $ua->request($request);
    if ($DEBUG)  { print STDERR "respons: ".Dumper($response)."\n\n";  }
 
    if ($response->is_success)
        {
        $config = $response->content;
        return $config;
        }
    else
        {
        if ($response->status_line =~ '404')  { return(0); }
        die $response->status_line;
    }   }

############                        put_config ( <job_name>, <config_file_string> )
#          
#                                   returns config file contents if successful,
#
#                                   else returns 0
sub put_config
    {
    my ($job, $config) = @_;    if ($DEBUG)  { print STDERR "putting config:\n$config\n";  }

    my $request_url  = $URL_ROOT .'/job/'. $job .'/config.xml';
    if ($DEBUG)  { print STDERR "\nrequest: $request_url\n\n"; }
    $request = HTTP::Request->new(POST => $request_url);
    $request->authorization_basic($jenkins_user, $jenkins_api_token);
    $request->content_type('tet/plain');
    $request->content($config);
    my $response = $ua->request($request);
    
    if ($response->is_success)
        {
        $config = $response->content;
        return $config;
        }
    else
        {
        if ($response->status_line =~ '404')  { return(0); }
        my $ERROR = $response->status_line;
        die "$ERROR\n";
    }   }


########################            S T A R T   H E R E

my %options=();
getopts("j:p:v:",\%options);

if  ( defined $options{j} && defined $options{p} && defined $options{v} )
    {
    $job_name  = $options{j};
    $parm_name = $options{p};
    $new_val   = $options{v};
    }
else
    {
    print STDERR "$usage\n";
    exit  99;
    }

my $config = get_config($job_name);
my $xmlref = $xml->XMLin($config, KeyAttr => {}, ForceArray => [] );

my $paramarray = $$xmlref{'properties'}{'hudson.model.ParametersDefinitionProperty'}{'parameterDefinitions'}{'hudson.model.StringParameterDefinition'};

if ($DEBUG)  { print STDERR Dumper($paramarray); }
if ($DEBUG)  { print STDERR "There are $#$paramarray elements in the paramarray.\n\n"; }

foreach my $ii (0..$#$paramarray)
    {
    my $parm = $$paramarray[$ii];
    if ($DEBUG)  { print STDERR "\n......$ii\n", Dumper($parm); print "\n......\n", $$parm{'name'}; print "\n......\n"; }
    if ($$parm{'name'} eq $parm_name)
        {
        $$paramarray[$ii]{'defaultValue'} = $new_val;
        }
    }
$xmlref{'properties'}{'hudson.model.ParametersDefinitionProperty'}{'parameterDefinitions'}{'hudson.model.StringParameterDefinition'} = $paramarray;

if ($DEBUG)  { print STDERR "\n----------------------------------------------------------------------\n\n"; }
if ($DEBUG)  { print STDERR Dumper($xmlref); }
if ($DEBUG)  { print STDERR "\n======================================================================\n\n$job_name"; }

put_config($job_name, $xml->XMLout($xmlref, RootName => 'project', NoSort => 1, NoAttr => 1, KeyAttr => {} ) );


__END__

