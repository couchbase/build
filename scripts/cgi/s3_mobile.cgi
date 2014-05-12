#!/usr/bin/perl

# queries Factory Jenkins JSON api to find latest good 
# android build of master or release/1.0.0 branch.
#  
#  Call with these parameters:
#  
#  BRANCH          e.g. master, 100
#  
use warnings;
#use strict;
$|++;

use File::Basename;
use Cwd qw(abs_path);
BEGIN
    {
    $THIS_DIR = dirname( abs_path($0));    unshift( @INC, $THIS_DIR );
    }
my $installed_URL='http://factory.hq.couchbase.com/cgi/s3_mobile.cgi';

$DEFAULT_REPO = 's3://packages.couchbase.com/builds/mobile/';

use CGI qw(:standard);
my  $query = new CGI;

sub file_link
    {
    my ($s3_path) = @_;
    my  $HTML;
    my ($html_path);
    
    if ($s3_path =~ /^s3(.*)/ )
        {
        $html_path = 'http'.$1;
        $HTML = '<A href="'.$html_path.'">'.$html_path.'</A>'."\n";
        return $HTML;
        }
    die "Invalid file path: $s3_path\n";
    }

sub dir_link
    {
    my ($s3_path) =  @_;
    my  $HTML;
    
    $HTML = '<A href="'.$installed_URL.'?dir='.$s3_path.'">'.$s3_path.'</A>'."\n";
    return $HTML;
    }
sub expand_dir
    {
    my ($s3_path) =  @_;
    my  $HTML;
    
    $HTML = '<strong>+</strong>';    return $HTML;
    }

sub dir_list
    {
    my ($s3_path) = @_;
    my  $HTML;
    
    my ($left, $right);
    
    open(DIR, "s3cmd ls $s3_path |")  or die "$!";
    while(<DIR>)
        {
        if  ($_ =~ 'DIR')
            {
            my ($DIR, $dir_name)  = split(" ", $_);
            $left  = expand_dir($dir_name);
            $right = dir_link($dir_name);
            }
        else
            {
            my ($dat, $tim, $siz, $filepath) = split(" ", $_);
            $left  = $dat.'&nbsp;'.$tim.'&nbsp;&nbsp;'.$siz.'&nbsp;';
            $right = file_link($filepath)
            }
        $HTML .= html_row($left, $right)."\n";
        }
    
    return $HTML;
    }


my $DEBUG = 1;

my ($good_color, $warn_color, $err_color, $note_color) = ('#CCFFDD', '#FFFFCC', '#FFAAAA', '#CCFFFF');

my $timestamp = "";
sub get_timestamp
    {
    my $timestamp;
    my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    $month =    1 + $month;
    $year  = 1900 + $yearOffset;
    $timestamp = "page generated $hour:$minute:$second  on $year-$month-$dayOfMonth";
    }

sub print_HTML_Page
    {
    my ($contents, $page_title, $color) = @_;
    
    print $query->header;
    print $query->start_html( -title   => $page_title,
                              -BGCOLOR => $color,
                            );
    print $contents;
    print $query->end_html;
    }

my ($repo);

if ( $query->param('dir') )
    {
    $repo   = $query->param('dir');
    }
else
    {
    $repo = $DEFAULT_REPO;
    }
if ($DEBUG)  { print STDERR "\nready to start with ($repo)\n"; }


#### S T A R T  H E R E 

print_HTML_Page( dir_list($repo), $repo, $note_color);


# print "\n---------------------------\n";
__END__

