#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
Getopt::Long::Configure qw(no_ignore_case);
use File::Basename;
use FindBin qw($Bin);
use lib "$Bin/.Modules";
use Parameter::BinList;

my ($HelpFlag,$BinList,$BeginTime);
my $ThisScriptName = basename $0;
my ($InBed,$OutBed,$AnnoInfo);
my $HelpInfo = <<USAGE;

 $ThisScriptName
 Auther: zhangdong_xie\@foxmail.com

   This script was used to annotate bed with genes.

 -i      ( Required ) Input bed file;
 -o      ( Required ) Output bed file;
 
 -bin    List for searching of related bin or scripts;
 -h      Help infomation;

USAGE

GetOptions(
	'i=s' => \$InBed,
	'o=s' => \$OutBed,
	'bin:s' => \$BinList,
	'h!' => \$HelpFlag
) or die $HelpInfo;

if($HelpFlag || !$InBed || !$OutBed)
{
	die $HelpInfo;
}
else
{
	$BeginTime = ScriptBegin();
	
	die "[ Error ] Bed not exist ($InBed).\n" unless(-s $InBed);
	$BinList = BinListGet() if(!$BinList);
	$AnnoInfo = BinSearch("refGene",$BinList);
}

if($InBed)
{
	open(IN,"zcat $InBed |") or die $! if($InBed =~ /\.gz$/);
	open(IN,"< $InBed") or die $! unless($InBed =~ /\.gz$/);
	open(OUT,"| gzip > $OutBed") or die $! if($OutBed =~ /\.gz$/);
	open(OUT,"> $OutBed") or die $! unless($OutBed =~ /\.gz$/);
	while(my $Line = <IN>)
	{
		chomp $Line;
		my @Cols = split /\t/, $Line;
		my $GeneList = &GenGet($Cols[0],$Cols[1],$Cols[2]);
		
		print OUT "$Line\t$GeneList\n";
	}
	close IN;
	close OUT;
}
printf "[ %.2fmin ] The end.\n",(time - $BeginTime)/60;




sub GenGet
{
	my ($Chr,$Start,$End) = @_;
	my $Gene = "";
	my @tGene = ();
	
	my $Return = ();
	$Return = `zcat $AnnoInfo | awk '{if(\$3 == \"$Chr\" && \$5 <= $End && \$6 >= $Start){print \$0}}' | cut -f 13 | sort | uniq` if($AnnoInfo =~ /\.gz$/);
	$Return = `cat $AnnoInfo | awk '{if(\$3 == \"$Chr\" && \$5 <= $End && \$6 >= $Start){print \$0}}' | cut -f 13 | sort | uniq` unless($AnnoInfo =~ /\.gz$/);
	@tGene = split /\n/, $Return if($Return);
	$Gene = join(",",@tGene) if($#tGene >= 0);
	
	return $Gene;
}
