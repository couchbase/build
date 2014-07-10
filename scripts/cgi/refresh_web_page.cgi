#!/usr/bin/perl

# refreshes HTML page for use on wall displays
# without having everyone's desktop session
# regularly polling the web server, causing
# a glut of calls to jenkins or buildbot
#  
#  Call with these parameters:
#  
#  web_page    PAGE        e.g. s3.html (path relative to ../html)
#  repeat      REPEAT      e.g. 600 (seconds, i.e., 10 minutes)
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
my $DOC_ROOT      = '/data/www/build/scripts/html';
my $URL_ROOT      = 'http://factory.hq.couchbase.com';
my $installed_URL = $URL_ROOT.'/cgi/refresh_web_page.cgi';

use CGI qw(:standard);
my  $query = new CGI;

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

my $page_title = 'no title yet';
sub get_page_title
    {
    my ($page) = @_;
    my  $title;
    
    my $regex = '<TITLE>(.*)</TITLE>';
    
    open WWW, $page  or die "unable to open $page\n";
    while(<WWW>)
        {
        if ($_ =~ $regex)
            {
            $title = $1;
            last;
        }   }
    return($title);
    }

my $ERROR_title   = 'ERROR';
my $ERROR_message = "Error in call to: $installed_URL";
sub print_ERROR_Page
    {
    my ($message, $footer, $color) = @_;
    
    print $query->header;
    print $query->start_html( -title   => $ERROR_title,
                              -BGCOLOR => $color,
                            );
    print "\n".'<h3>'.$message.'</h3>'
         ."\n".'<hr>'
         ."\n".$footer."\n";
    print $query->end_html;
    }

sub print_HTML_Page
    {
    my ($page, $seconds) = @_;

    print $query->header;
    print $query->start_html( -head  => meta( {-http_equiv => 'refresh',
                                               -content    => $seconds} ),
                              -title => $page_title,
                            );
    
    print '<object type="text/html" data="'.$page.'" width="100%" height="2048">';
    
    print $query->end_html;
    } 


my ($web_page, $repeat);

if ( $query->param('web_page') && $query->param('repeat') )
    {
    $web_page = $query->param('web_page');
    $repeat   = $query->param('repeat');
    }
else
    {
    print_ERROR_Page( $ERROR_message,
                      get_timestamp(),
                      $err_color   );
    }
if ($DEBUG)  { print STDERR "\nready to start with ($web_page, $repeat)\n"; }


#### S T A R T  H E R E 

$page_title = get_page_title( $DOC_ROOT.'/'.$web_page);
print_HTML_Page( $URL_ROOT.'/'.$web_page,   $repeat ); 


# print "\n---------------------------\n";
__END__

