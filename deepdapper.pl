#!/usr/bin/perl
use strict;
use warnings;
use WebService::YQL;
use XML::Simple;

use Getopt::Long;
use Pod::Usage;

use Data::Dumper;

# read the command line options
my $next;
my $datadapper;
my $listdapper;
my $nextdapper;
my $nextcount = 1000;    # very very large
my $listoffline;
my $nextoffline;
my $self = 0;
my $debug;
my $verbose = 0;
my $help    = 0;
my $man     = 0;
GetOptions(
	'url=s'       => \$next,
	'd=s'         => \$datadapper,
	'l=s'         => \$listdapper,
	'n=s'         => \$nextdapper,
	'nextcount=i' => \$nextcount,
	'list'        => \$listoffline,
	'next'        => \$nextoffline,
	'self'        => \$self,
	'debug'       => \$debug,
	'v'           => \$verbose,
	'h'           => \$help,
	'man'         => \$man
  )
  or pod2usage(1);    #print usage and exit with a 1

if ($help) {
	pod2usage(0);
}
;                     #exit with a 0 and print the usage if -h is passed
if ($man) {
	pod2usage( -verbose => 2 );
}
;                     #display man

my $yql = WebService::YQL->new;
my $xs  = XML::Simple->new();

my $data = { 'data' => [] };
push( @{ $data->{'data'} }, { 'item' => [] } );

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

while ( $next && $nextcount-- > 0 ) {
	if ( $listdapper && $listoffline ) {
		my $listdata;
		if ( $nextdapper && !$nextoffline ) {
			$listdata =
			  deepdapperyql(
"select * from deepdapper where url='$next' and datadapper='$listdapper' and nextdapper='$nextdapper'"
			  );
		}
		else {
			$listdata =
			  deepdapperyql(
"select * from deepdapper where url='$next' and datadapper='$listdapper'"
			  );
		}

		#    print STDERR Dumper($listdata);
		for my $dataurl (
			@{ path( $listdata, [ 'query', 'results', 'data', 'item' ] ) } )
		{
			my $url     = $dataurl->{'href'};
			my $newdata =
			  deepdapperyql(
"select * from deepdapper where url='$url' and datadapper='$datadapper'"
			  );
			pushRecord( $data, $newdata, $url );
		}
	}
	elsif ( $listdapper && !$listoffline ) {
		my $newdata;
		if ( $nextdapper && !$nextoffline ) {
			$newdata =
			  deepdapperyql(
"select * from deepdapper where url='$next' and listdapper='$listdapper' and nextdapper='$nextdapper' and datadapper='$datadapper'"
			  );
		}
		else {
			$newdata =
			  deepdapperyql(
"select * from deepdapper where url='$next' and listdapper='$listdapper' and datadapper='$datadapper'"
			  );
		}
		pushRecord( $data, $newdata, $next );
	}
	else {
		my $newdata;
		if ( $nextdapper && !$nextoffline ) {
			$newdata =
			  deepdapperyql(
"select * from deepdapper where url='$next' and nextdapper='$nextdapper' and datadapper='$datadapper'"
			  );
		}
		else {
			$newdata =
			  deepdapperyql(
"select * from deepdapper where url='$next' and datadapper='$datadapper'"
			  );
		}
		pushRecord( $data, $newdata, $next );
	}
	if ( $nextdapper && $nextoffline ) {
		my $nextdata =
		  deepdapperyql(
"select * from deepdapper where url='$next' and datadapper='$nextdapper'"
		  );
		$next =
		  path( $nextdata, [ 'query', 'results', 'data', 'item', 'href' ] );
		$next = ( ref($next) eq "ARRAY" ) ? undef: $next;
	}
	else {
		$next = undef;
	}
}

print $xs->XMLout( $data, KeepRoot => 1 );

sub deepdapperyql {
	my $usedeepdapper =
"use 'http://github.com/vicmortelmans/yql-tables/raw/master/data/deepdapper.xml' as deepdapper;";
	my $qs = $usedeepdapper . $_[0];
	if ($verbose) { print STDERR "$qs\n" };
	my $qd;
	eval { $qd = $yql->query($qs); };
	if ($@) {
		print STDERR "Error retrieving data from YQL: "
		  . $@->getMessage() . "\n";
	}
	if ($debug) { print STDERR Dumper( $xs->XMLout($qd) ) }
	return $qd;
}

sub pushRecord {
	( my $data, my $newdata, my $url ) = @_;
	my $item = path( $newdata, [ 'query', 'results', 'data', 'item' ] );
	if ($self) {
		$item->[0]->{'self'} = { 'content' => $url };
	}
	push( @{ $data->{'data'}->[0]->{'item'} }, @{$item} );
}

sub path {

	# returns an array containing hash references or a scalar value
	my $data = [ $_[0] ];
	my $keys = $_[1];
	my $done = 0;
	while ( ( my $key = shift( @{$keys} ) ) && !$done ) {
		if ( !exists $data->[0]->{$key} ) {
			$data = [];
			$done = 1;
		}
		elsif ( ref( $data->[0]->{$key} ) eq "ARRAY" ) {
			$data = $data->[0]->{$key};
		}
		elsif ( ref( $data->[0]->{$key} ) eq "HASH" ) {
			$data = [ $data->[0]->{$key} ];
		}
		else {
			if ( @{$keys} > 0 ) {
				$data = [];    # leaf node reached, but still keys pending
			}
			else {
				$data = $data->[0]->{$key};    # scalar node value
			}
			$done = 1;
		}
	}
	return $data;
}
__END__

=head1 NAME

deepdapper.pl - perform a deepdapper webquery, based on the deepdapper YQL Open Table

=head1 SYNOPSIS

deepdapper.pl [options] [url]

 Options:
  -d <dapper>         name of the datadapper;
  -l <dapper>         name of the listdapper;
  -n <dapper>         name of the nextdapper;
  -nextcount <value>  number of next pages to process (default=infinite);
  -list               perform list extraction offline;
  -next               perform next page extraction offline;
  -self               include the url of the datapage as field in each record;
  -v                  verbose;
  -debug              turn on debug messages;
  -h                  print help/usage
  -man                display man pages

=head1 DESCRIPTION

Refer to the deepdapper Open Table documentation (http://docs.google.com/View?id=ddq89pzk_199f54jdwcb).

=cut
