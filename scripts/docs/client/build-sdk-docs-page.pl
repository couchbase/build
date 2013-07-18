#!/usr/bin/perl

use strict;
use warnings;
use IO::File;
use Data::Dumper;

my $srcfiles = { 
    'spymemcached' => 'Spymemcached',
    'couchbase-java-client' => 'Couchbase Java Client',
    'couchbase-ruby-client' => 'Couchbase Ruby Client',
};

my ($infile, $outfile, $dirsrc) = @ARGV;

my $targets = {};

foreach my $file (glob("$dirsrc/*"))
{
    next if ($file =~ m/.html$/);
    my $type = 'file';
    my $origfile = $file;
    if (-d $file)
    {
        $type = 'dir';
    }

    $file =~ s{^$dirsrc/}{};
    my $fileident = undef;
    my $version = undef;

    for my $filebase (keys %{$srcfiles})
    {
        $version = $file;

        $version =~ s/\.(zip|tar.gz|tgz)$//g;
        if ($version =~ m/^$filebase/)
        {
            $fileident = $filebase;
        }
    }

    $version =~ s/^$fileident-//;
    $version =~ s/^v//;

    if (defined($fileident))
    {
        $targets->{$fileident}->{$version}->{$type} = $file;
    }
    else
    {
        print STDERR "Unknown product in $origfile\n";
    }
}

#print STDERR Dumper($targets),"\n";

my @fmttext;

foreach my $ident (sort {$srcfiles->{$a} cmp $srcfiles->{$b}} keys %{$srcfiles})
{
    push(@fmttext,"<h3>$srcfiles->{$ident}</h3>");
    push(@fmttext,"<table><tr><th>Version</th><th>Download</th></tr>");

    foreach my $version (sort keys %{$targets->{$ident}})
    {
        push(@fmttext,"<tr><td>",
             (exists($targets->{$ident}->{$version}->{dir}) ? 
              sprintf('<a href="%s/index.html">',$targets->{$ident}->{$version}->{dir}) : ''),
             sprintf('%s v%s',$srcfiles->{$ident},$version),
             (exists($targets->{$ident}->{$version}->{dir}) ? '</a>' : ''),
             '</td><td>',
             (exists($targets->{$ident}->{$version}->{file}) ? 
              sprintf('<a href="%s">Download</a>',$targets->{$ident}->{$version}->{file}) : ''),
             '</td></tr>',
            );
    }
    push(@fmttext,'</table>');
}

my $srcfile = IO::File->new($infile);
binmode($srcfile,':utf8');
my $inplacefile = join('',<$srcfile>);
$srcfile->close();

my $repltext = join('',@fmttext);

$inplacefile =~ s/<!--CONTENT-->/$repltext/msg;

my $targetfile = IO::File->new($outfile, 'w');
binmode($targetfile,':utf8');
print $targetfile $inplacefile;
$targetfile->close();
