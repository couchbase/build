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

use buildbotQuery qw(:HTML :JSON );


# if we don't do this it will buffer and then print results
# I want to see results immediately as it happens.
# not every server configuration supports this
$|++;

my $URL_ROOT=buildbotQuery::get_URL_root();

 
#### S T A R T  H E R E 

my $all_builds = buildbotQuery::get_json($builder);

my ($bldnum, $result);
foreach my $KEY (keys %$all_builds)
    {
    print ".";
    $VAL = $$all_build{$KEY};
    if (! defined $VAL)  { $$all_build{$KEY}="null" }
    }

foreach $KEY (reverse sort { 0+$a <=> 0+$b } keys %$all_builds)
    {
    $bldnum = $KEY;
    print "....$bldnum   $all_build{$bldnum}\n";
    $result = buildbotQuery::get_json($builder, '/'.$bldnum);
    print "....is $bldnum running?\n";
    if ( buildbotQuery::is_running_build( $result) )    { print "$bldnum is still running\n"; }
    else                                 { last;                               }
    }

print "\n---------------------------\n";
print buildbotQuery::html_builder_link($builder);
print "\n---------------------------\n";
print buildbotQuery::html_OK();
print "\n---------------------------\n";
print buildbotQuery::html_ERROR_msg("compile failure, jackson");
print "\n---------------------------\n";

if  ( buildbotQuery::is_good_build( $result) )
    {
    my $rev_numb = $branch .'-'. buildbotQuery::get_build_revision($result);
    print "... rev_numb is $rev_numb...\n";
    my $bld_date = buildbotQuery::get_build_date($result);
    print "... bld_date is $bld_date...\n";
    
    print "GOOD: $bldnum\n"; print buildbotQuery::html_OK_link(   $builder, $bldnum, $rev_numb, $bld_date );
    }
else
    { print "FAIL: $bldnum\n"; print buildbotQuery::html_FAIL_link( $builder, $bldnum ); }

print "\n---------------------------\n";
__END__

