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
my ($Bam,$DpFile,$Bed,$MinDp,$RMFlag,$DupFlag,$SamtoolsBin,$BedGenBin);
my $HelpInfo = <<USAGE;

 $ThisScriptName
 Auther: zhangdong_xie\@foxmail.com

  This script was used to locate the bed area from bam file approximately.
 This program will generate one bed file for area with depth above specific percent of points ranking from depth low to high;

 -b      ( Required ) Bam file;
 -d      ( Required ) Depth file;
         '-d' and '-b' should at least specific one;
 -o      ( Required ) Bed file for logging;
 
 -min    ( Optional ) Minimal depth (default: average depth);
 -r      ( Optional ) If deleting the depth file;
 -dup    ( Optional ) If there was need to fliter twise;
 -bin    List for searching of related bin or scripts;
 -h      Help infomation;

USAGE

GetOptions(
	'b:s' => \$Bam,
	'd:s' => \$DpFile,
	'o=s' => \$Bed,
	'min:i' => \$MinDp,
	'r!' => \$RMFlag,
	'dup!' => \$DupFlag,
	'bin:s' => \$BinList,
	'h!' => \$HelpFlag
) or die $HelpInfo;

if($HelpFlag || (!$Bam && !$DpFile) || !$Bed)
{
	die $HelpInfo;
}
else
{
	$BeginTime = ScriptBegin(0,$ThisScriptName);
	
	$BinList = BinListGet() if(!$BinList);
	$SamtoolsBin = BinSearch("Samtools",$BinList);
	$BedGenBin = BinSearch("BedGen",$BinList);
}

if($Bam || $DpFile)
{
	unless($DpFile)
	{
		die "[ Error ] Bam not exist: $Bam.\n" unless(-e $Bam);
		$DpFile = $Bed;
		$DpFile =~ s/\.bed$//;
		$DpFile .= ".depth";
		`$SamtoolsBin depth -d 0 -q 30 -Q 30 $Bam | awk '{if(\$3 > 0){print \$0}}' > $DpFile`;
	}
	
	if($DupFlag)
	{
		my $tMinDp = &ThresholdConfirm($DpFile);
		print "[ Info ] Initial minimal depth required: $tMinDp\n";
		
		`$SamtoolsBin depth -d 0 -q 30 -Q 30 $Bam | awk '{if(\$3 > $tMinDp){print \$0}}' > $DpFile`;
	}
	$MinDp = &ThresholdConfirm($DpFile) unless($MinDp);
	print "[ Info ] Minimal depth required: $MinDp\n";
	my $PointFile = $Bed;
	$PointFile =~ s/\.bed$//;
	$PointFile .= ".point.xls";
	`awk '{if(\$3 >= $MinDp){print \$0}}' $DpFile | cut -f 1,2 > $PointFile`;
	`$BedGenBin -i $PointFile -o $Bed`;
	`rm $PointFile` if(-e $PointFile);
	`rm $DpFile` if($RMFlag && -e $DpFile);
	my $BedSize = 0;
	$BedSize = `awk 'BEGIN{SUM = 0}{SUM += \$3 - \$2}END{print SUM}' $Bed` if($Bed);
	chomp $BedSize;
	print "[ Info ] Size of bed area: $BedSize\n";
}
printf "[ %s ] The end.\n",TimeString(time,$BeginTime);


######### Sub functions ##########
sub ThresholdConfirm
{
	my $File = $_[0];
	
	my ($Total,$MeanDp) = (0,0);
	open(DP,"< $File") or die $!;
	while(my $Line = <DP>)
	{
		chomp $Line;
		my @Cols = split /\t/, $Line;
		$Total ++;
		$MeanDp += $Cols[2];
	}
	close DP;
	
	my $tMinDp = 0;
	if($Total > 0)
	{
		$MeanDp = $MeanDp / $Total;
		$tMinDp = int($MeanDp + 0.5);
	}
	
	return $tMinDp;
}