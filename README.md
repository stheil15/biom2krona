# biom2krona

## Perl libraries

Getopt::Long
File::Basename
XML::Writer
Data::Dumper
Math::Round
Cwd 'abs_path'

## Usage

Create one HTML file with one [Krona](https://github.com/marbl/Krona/wiki) per sample from biom TSV OTU table.

```bash
biom2krona.pl -i otu_table.tsv -o krona.html
```

## Help

```bash
### biom2krona.pl 1.0 ###
#
# AUTHOR:		Sebastien THEIL
# VERSION:		1.0
# LAST MODIF:		2017-09-13
# PURPOSE:		This script is used to parse csv file containing tax_id field and creates Krona charts.
#

USAGE: perl biom2krona.pl -i blast_csv_extended_1 -i blast_csv_extended_2 ... -i blast_csv_extended_n [OPTIONS]

	### OPTIONS ###
	-i|input	<BLAST CSV>  Blast CSV extended file and CSV group file corresponding to blast (optional)
	-o|output	<DIRECTORY>  Output directory
	-help|h		Print this help and exit
```
