#!/usr/bin/perl
use strict;
use warnings;
use WebService::YQL;
use XML::Simple;

use Getopt::Long;
use Pod::Usage;

use Data::Dumper;

# read the command line options
my $datadapper;
my $listdapper;
my $nextdapper;
my $nextcount = 1000; // very very large
my $listoffline;
my $nextoffline;
my $debug;
my $verbose = 0;
my $help = 0;
GetOptions(
  'd=s' => \$datadapper,
  'l=s' => \$listdapper,
  'n=s' => \$nextdapper,
  'nextcount=i' => \$nextcount,
  'list' => \$listoffline,
  'next' => \$nextoffline,
  'd' => \$debug,
  'v' => \$verbose,
  'h' => \$help
) or pod2usage(1); #print usage and exit with a 1
if ($help) {
  pod2usage(0)
}; #exit with a 0 and print the usage if -h is passed

my $yql = WebService::YQL->new;

my $data = { 'item' => [] };
#<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
#<data>
#    <item dataType="RawString" fieldName="item" href="http://developer.yahoo.net/forum/index.php?showtopic=3308" originalElement="a" type="field">New Elance YDN Section</item>
#    <item dataType="RawString" fieldName="item" href="http://developer.yahoo.net/forum/index.php?showtopic=5576" originalElement="a" type="field">Newbie YQL question</item>
#</data>
#
#$VAR1 = {
#          'item' => [
#                    {
#                      'originalElement' => 'a',
#                      'href' => 'http://developer.yahoo.net/forum/index.php?showtopic=3308',
#                      'dataType' => 'RawString',
#                      'content' => 'New Elance YDN Section',
#                      'type' => 'field',
#                      'fieldName' => 'item'
#                    },
#                    {
#                      'originalElement' => 'a',
#                      'href' => 'http://developer.yahoo.net/forum/index.php?showtopic=5576',
#                      'dataType' => 'RawString',
#                      'content' => 'Newbie YQL question',
#                      'type' => 'field',
#                      'fieldName' => 'item'
#                    }
#                  ]
#        };

my $next = $shift;

while ($next && $nextcount-- > 0) {
  if ($listdapper && $listoffline) {
    my $listdata;
    if ($nextdapper && !$nextoffline) {
      $listdata = deepdapperyql("select * from deepdapper where url='$next' and datadapper='$listdapper' and nextdapper='$nextdapper'");
    } 
    else {
      $listdata = deepdapperyql("select * from deepdapper where url='$next' and datadapper='$listdapper'");
    }
    print Dumper($listdata);
    for my $dataurl ( @{ $listdata->{'query'}{'results'}{'data'}{'item'} } ) { //TODO
      my $newdata = deepdapperyql("select * from deepdapper where url='$dataurl->{'href'}' and datadapper='$datadapper'");
      push($data->{'item'},{ $newdata->{'query'}{'results'}{'data'}{'item'} });
    }
  } 
  elsif ($listdapper && !$listoffline) {
    my $newdata;
    if ($nextdapper && !$nextoffline) {
      $newdata = deepdapperyql("select * from deepdapper where url='$dataurl->{'href'}' and listdapper='$listdapper' and nextdapper='$nextdapper' and datadapper='$datadapper'");
    }
    else {
      $newdata = deepdapperyql("select * from deepdapper where url='$dataurl->{'href'}' and listdapper='$listdapper' and datadapper='$datadapper'");
    }
    push($data->{'item'},{ $newdata->{'query'}{'results'}{'data'}{'item'} });
  }
  else {
    my $newdata;
    if ($nextdapper && !$nextoffline) {
      $newdata = deepdapperyql("select * from deepdapper where url='$dataurl->{'href'}' and nextdapper='$nextdapper' and datadapper='$datadapper'");
    }
    else {
      $newdata = deepdapperyql("select * from deepdapper where url='$dataurl->{'href'}' and datadapper='$datadapper'");
    }
    push($data->{'item'},{ $newdata->{'query'}{'results'}{'data'}{'item'} });
  }
  if ($nextdapper && $nextoffline) {
    $nextdata = deepdapperyql("select * from deepdapper where url='$dataurl->{'href'}' and datadapper='$nextdapper'");
    $next = $nextdata->{'query'}{'results'}{'data'}{'item'}[0]{'href'};
  }
  else {
    $next = '';
  }
}

print $xs->XMLout($data);

sub deepdapperyql {
  my $usedeepdapper = "use 'http://github.com/vicmortelmans/yql-tables/raw/master/data/deepdapper.xml' as deepdapper;";
  my $qs = $usedeepdapper + @_;
  if ($verbose) {print STDERR "$qs\n"}
  my $qd = $yql->query($qs);
  if ($debug) {print STDERR Dumper($xs->XMLout($qd)}
  return $qd;
}

__END__

=head1 NAME

deepdapper - perform a deepdapper webquery, based on the deepdapper YQL Open Table

=head1 SYNOPSIS

deepdapper [options] [url]

Options:
-d <dapper> name of the datadapper;
-l <dapper> name of the listdapper;
-n <dapper> name of the nextdapper;
-nextcount <value> number of next pages to process (default=infinite);
-list perform list extraction offline;
-next perform next page extraction offline;
-v verbose;
-d turn on debug messages;
-h print help/usage

=back

=head1 DESCRIPTION

Refer to the deepdapper Open Table documentation (http://docs.google.com/View?id=ddq89pzk_199f54jdwcb).

=cut
