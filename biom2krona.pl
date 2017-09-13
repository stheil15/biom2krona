#!/usr/bin/perl

use strict;
use warnings;
use Getopt::Long;
use File::Basename;
use File::Path qw(make_path);
use Pod::Usage;
use Logger::Logger;
use Tools::Taxonomy;
use Tools::Blast;
use DBI;
use XML::Writer;
use Data::Dumper;
use Math::Round;
use Cwd 'abs_path';

my $VERSION = '1.0' ;
my $lastmodif = '2017-09-13' ;

my $input_file= '';
my $output = '';
my $help;
my $verbosity = 1;
my $data;

GetOptions(
          "i|input:s"      => \$input_file,
          "o|output=s"     => \$output,
          "h|help"         => \$help,
          "v|verbosity=i"  => \$verbosity,
) ;


if($verbosity > 1){
  Logger::Logger->changeMode( $verbosity );
}


&main;


sub main {
  my $self={};
  bless $self;

  _set_options($self);
	$self->_read_biom_tab_file();
}

sub _read_biom_tab_file {
	my ($self)=@_;
	open(CSV,$self->{_input_file}) || $logger->logdie('Cannot open file ' . $self->{_input_file});
	my $tree ={};
	while(<CSV>){
		chomp;
		if(/^#\s/){
			next;
		}
		if(/^#OTU ID/){
			my @headers = split(/\t/,$_);
			for(my $i=1;$i<$#headers;$i++){
				push(@{$self->{_sample_list}},$headers[$i]);
				$self->{_sample_hash}->{$headers[$i]}=1;
			}
		}
		else{
			my $parent = $tree;
			my @data_line = split(/\t/,$_);
			my @taxo = split(';',$data_line[$#data_line]);
			# print Dumper @taxo;
			for(my $i=1;$i<$#data_line;$i++){
				$self->{_total_per_sample}->{ $self->{_sample_list}->[$i-1] } += $data_line[$i];
			}
			for(my $j=0;$j<=$#taxo;$j++){
				$taxo[$j] =~ s/^\s//;
				for(my $i=1;$i<$#data_line;$i++){
					$parent->{$taxo[$j]}->{$self->{_sample_list}->[$i-1]} += $data_line[$i];
				}
				$parent = $parent->{$taxo[$j]};
			}
		}
	}
	close CSV;
	$self->printXML($tree);
}

sub printXML {
  my ($self, $tree) = @_;
  my $output = IO::File->new(">$self->{_krona_file_name}");
  my $writer = XML::Writer->new(OUTPUT => $output, DATA_INDENT => " ", DATA_MODE => 1);
  print $output '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">' . "\n";
  print $output '<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">' . "\n";
  print $output ' <head>' . "\n";
  print $output '  <meta charset="utf-8"/>' . "\n";
  print $output '  <link rel="shortcut icon" href="http://krona.sourceforge.net/img/favicon.ico"/>' . "\n";
  print $output '  <script id="notfound">window.onload=function(){document.body.innerHTML="Could not get resources from \"http://krona.sourceforge.net\"."}</script>' . "\n";
  print $output '  <script src="http://krona.sourceforge.net/src/krona-2.0.js"></script>' . "\n";
  print $output ' </head>' . "\n";
  print $output ' <body>' . "\n";
  print $output '  <img id="hiddenImage" src="http://krona.sourceforge.net/img/hidden.png" style="display:none"/>' . "\n";
  print $output '  <img id="loadingImage" src="http://krona.sourceforge.net/img/loading.gif" style="display:none"/>' . "\n";
  print $output '  <img id="logo" src="http://krona.sourceforge.net/img/logo.png" style="display:none"/>' . "\n";
  print $output '  <noscript>Javascript must be enabled to view this page.</noscript>' . "\n";
  print $output '  <div style="display:none">' . "\n";
  $writer->startTag('krona', 'collapse' => "false", 'key' => "true");
  $writer->startTag('attributes', 'magnitude' => 'magnitude');
  $writer->startTag('attribute', 'display' => 'Total');
  $writer->characters("magnitude");
  $writer->endTag('attribute');
  $writer->endTag('attributes');

  $writer->startTag('datasets');


	for(my $i=0;$i<=$#{$self->{_sample_list}};$i++){
		$writer->startTag('dataset');
		$writer->characters('sample '. $self->{_sample_list}->[$i]);
		$writer->endTag('dataset');
	}
	$writer->endTag('datasets');


  $writer->startTag('node', 'name' => "all");
  $writer->startTag('magnitude');

  for(my $i=0;$i<=$#{$self->{_sample_list}};$i++){
    $writer->dataElement(val => $self->{_total_per_sample}->{ $self->{_sample_list}->[$i] });
  }

  $writer->endTag('magnitude');
  XMLPrinter($self,$tree,$writer);
  $writer->endTag('node');
  $writer->endTag('krona');
  print $output '</div></body></html>' . "\n";
  $writer->end();
}


sub XMLPrinter {
  my ($self,$tree,$writer) = @_;
	my %keysList;
  foreach my $k (keys %{$tree}){
		if(!defined($self->{_sample_hash}->{$k})){
			$keysList{$k} = 1;
		}
	}
	foreach my $c (keys %keysList){
		my $newHash;
		$writer->startTag('node', name => "$c");
		$writer->startTag('magnitude');
		for(my $i=0;$i<=$#{$self->{_sample_list}};$i++){
			$writer->dataElement(val => nearest(0.00001, $tree->{$c}->{$self->{_sample_list}->[$i]}));
		}
		$writer->endTag('magnitude');
		foreach my $k (keys %{$tree->{$c}}){
			if(defined($self->{_sample_hash}->{$k})){
			}
			else{
				$newHash->{$k} = $tree->{$c}->{$k};
			}
		}
		XMLPrinter($self,$newHash,$writer);
		$writer->endTag('node');
	}
}


sub _set_options {
  my ($self)=@_;

  if($input_file ne ''){
		$self->{_input_file} = abs_path($input_file);
  }
  else{
    $logger->error('You must provide at least one csv file.');
    &help;
  }
	if($output ne ''){
		$self->{_krona_file_name} = $output;
	}
	else{
		$self->{_krona_file_name} = 'krona.html';
	}
}



sub help {
my $prog = basename($0) ;
print STDERR <<EOF ;
### $prog $VERSION ###
#
# AUTHOR:     Sebastien THEIL
# VERSION:    $VERSION
# LAST MODIF: $lastmodif
# PURPOSE:    This script is used to parse csv file containing tax_id field and creates Krona charts.
#

USAGE: perl $prog -i blast_csv_extended_1 -i blast_csv_extended_2 ... -i blast_csv_extended_n [OPTIONS]

       ### OPTIONS ###
       -i|input        <BLAST CSV>=<GROUP FILE>  Blast CSV extended file and CSV group file corresponding to blast (optional)
       -o|output       <DIRECTORY>  Output directory
       -help|h				 Print this help and exit
EOF
exit(1) ;
}
