#!/bin/perl
# 
############ 
#use strict;
use warnings;

package htmlReports;

use Exporter qw(import);
#use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);
our @EXPORT      = ();
our @EXPORT_OK   = qw(              HTML_pair_cell   HTML_repo_cell   print_HTML_Page );

our %EXPORT_TAGS = ( HTML  => [qw( &HTML_pair_cell  &HTML_repo_cell  &print_HTML_Page )],
                   );

my $DEBUG = 0;   # FALSE

############ 

use jenkinsQuery   qw(:DEFAULT );

my $installed_URL='http://factory.hq.couchbase.com';
my $run_icon  = '<IMG SRC="' .$installed_URL. '/running_20.gif" ALT="running..." HSPACE="50" ALIGN="LEFT">';
my $done_icon = '&nbsp;';


############                        HTML_pair_cell ( <left_element>, <right_element>, [ <color> ] )
#          
#                                   returns ( <html_table> )
sub HTML_pair_cell
    {
    my ($frag_left, $frag_right, $optional_color) = @_;
    my $color_prop = '';
    if( defined( $optional_color) )  {  $color_prop = 'style="background-color:'.$optional_color.';"'; }

    my $HTML = '<table border="0" '.$color_prop.' cellpadding="0" cellspacing="0">'
              .'<tr>'."\n".'<td valign="TOP">'.$frag_left.'</td><td valign="TOP">'.$frag_right.'</td></tr>'."\n"
              .'</table>'."\n";
    return($HTML);
    }

############                        HTML_repo_cell ( <branch>, <jenkins_row>, <buildbot_row>, [ <color> ] )
#          
#                                   returns ( <html_table> )
sub HTML_repo_cell
    {
    my ($branch, $row_top, $row_bot, $optional_color) = @_;
    my $color_prop = '';
    if( defined( $optional_color) )  {  $color_prop = 'style="background-color:'.$optional_color.';"'; }
    
    my $HTML = '<table border="0" '.$color_prop.' cellpadding="0" cellspacing="0">'."\n"
              .'<tr><td valign="LEFT"><H3>'.$branch.'</H3></td></tr>'."\n"
              .'<tr><td valign="TOP">'.$row_top.'</td></tr>'."\n"
              .'<tr><td valign="TOP">'.$row_bot.'</td></tr>'."\n"
              .'</table>';
    return($HTML);
    }

############                        print_HTML_Page ( <html_element>, <page_title>, <color> )
#          
#                                   prints html page to stdout
sub print_HTML_Page
    {
    my ($html_elem, $page_title, $color) = @_;
    
    print $query->header;
    print $query->start_html( -title           => $page_title,
                              -BGCOLOR         => $color,
                              '-cache-control' => 'NO-CACHE',
                               -expires        => -1,
                               -pragma         => 'pragma',
                            );
    print '<div style="overflow-x: hidden">'."\n";
    print  $html_elem                       ."\n";
    print '</div>'                          ."\n";
    print $query->end_html;
    }


1;
__END__

