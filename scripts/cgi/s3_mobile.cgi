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
$S3CMD        = 's3cmd --config=/var/www/.s3cfg';

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
    
    open(DIR, "$S3CMD ls $s3_path |")  or die "$!";
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
        $HTML .= "    ".html_row($left, $right)."\n";
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

sub html_row
    {
    my ($frag_left, $frag_right) = @_;
    
    my $HTML = "\n".'<tr>'."\n".'<td valign="TOP">'.$frag_left.'</td><td valign="TOP">'.$frag_right.'</td></tr>'."\n";
    return $HTML;
    }

sub print_HTML_Page
    {
    my ($table_rows, $page_title, $color) = @_;
    
    print $query->header;
    print $query->start_html( -title   => $page_title,
                              -BGCOLOR => $color,
                            );
    print "\n".'<div style="overflow-x: hidden">'."\n".'<table border="0" cellpadding="0" cellspacing="0">'
              .$table_rows
         ."\n".'</table>'
              .'</div>'."\n";
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

