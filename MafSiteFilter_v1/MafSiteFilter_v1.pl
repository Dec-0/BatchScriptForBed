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
my ($OriBed,$Dir,$Prefix,$Bedtools);
my (@CutInfo,@Population,@ColId,@MinFreq,@ChrSplitFile);
my @ChrList = ("chr1","chr2","chr3","chr4","chr5","chr6","chr7","chr8","chr9","chr10","chr11","chr12","chr13","chr14","chr15","chr16","chr17","chr18","chr19","chr20","chr21","chr22","chrX","chrY");
my $HelpInfo = <<USAGE;

 $ThisScriptName
 Auther: zhangdong_xie\@foxmail.com

  This script was used to confirm the snp sites in a given bed area.
  本脚本主要用于确定给定bed文件中的人群多态性位点列表。

 -i      ( Required ) A bed file;
 -o      ( Required ) Directory for result logging;
 -prefix ( Required ) Prefix of the file name;

 -c      ( Optional ) CutOff for population and minimal allele frequency required, default 'East_Asian,0.01' and 'Total,0.01' [ Multi times ];
                      用于指定人群及最低频率要求，比如“East_Asian,0.01”
 -bin    ( Optional ) List for searching of related bin or scripts; 
 -h      ( Optional ) Help infomation;

USAGE

GetOptions(
	'i=s' => \$OriBed,
	'o=s' => \$Dir,
	'prefix=s' => \$Prefix,
	'c:s' => \@CutInfo,
	'bin:s' => \$BinList,
	'h!' => \$HelpFlag
) or die $HelpInfo;

if($HelpFlag || !$OriBed || !$Dir || !$Prefix)
{
	die $HelpInfo;
}
else
{
	$BeginTime = ScriptBegin(0,$ThisScriptName);
	IfFileExist($OriBed);
	IfDirExist($Dir);
	unless(@CutInfo)
	{
		@CutInfo = ("East_Asian,0.01");
		push @CutInfo, "Total,0.01";
	}
	if(@CutInfo)
	{
		my %DupFlag = ();
		for my $i (0 .. $#CutInfo)
		{
			my @Cols = split /,/, $CutInfo[$i];
			die "[ Error ] Unappropriate cutoff format ($CutInfo[$i]), default like 'East_Asian,0.01'.\n" unless($Cols[1] >= 0 && $Cols[1] <= 1);
			die "[ Error ] Multi times for $Cols[0]\n" if($DupFlag{$Cols[0]});
			$DupFlag{$Cols[0]} = 1;
			push @Population, $Cols[0];
			push @MinFreq, $Cols[1];
		}
	}
	
	$BinList = BinListGet() if(!$BinList);
	$Bedtools = BinSearch("Bedtools",$BinList);
	for my $i (0 .. $#ChrList)
	{
		$ChrSplitFile[$i] = BinSearch($ChrList[$i],$BinList);
	}
}

if(1)
{
	if(1)
	{
		# 检查人群信息;
		for my $i (0 .. $#Population)
		{
			my $Return = "";
			$Return = `zcat $ChrSplitFile[0] | awk '{if(/^#/){print \$0}else{exit}}' | tail -n1` if($ChrSplitFile[0] =~ /\.gz$/);
			$Return = `cat $ChrSplitFile[0] | awk '{if(/^#/){print \$0}else{exit}}' | tail -n1` unless($ChrSplitFile[0] =~ /\.gz$/);
			chomp $Return;
			my @Cols = split /\t/, $Return;
			my $MatchFlag = 0;
			for my $j (0 .. $#Cols)
			{
				next unless($Cols[$j] eq $Population[$i]);
				push @ColId, $j;
				$MatchFlag = 1;
			}
			die "[ Error ] Cannot locate $Population[$i] in $Return\n" unless($MatchFlag);
		}
	}
	
	# 得到原始文件;
	my $VarList = $Dir . "/" . $Prefix . ".MafAll.gz";
	if(1)
	{
		`zcat $ChrSplitFile[0] | awk '{if(/^#/){print \$0}else{exit}}' | gzip > $VarList` if($ChrSplitFile[0] =~ /\.gz$/);
		`cat $ChrSplitFile[0] | awk '{if(/^#/){print \$0}else{exit}}' | gzip > $VarList` unless($ChrSplitFile[0] =~ /\.gz$/);
		
		for my $i (0 .. $#ChrList)
		{
			`zcat $OriBed | grep ^'$ChrList[$i]'\$'\\t' | $Bedtools intersect -a $ChrSplitFile[$i] -b - | gzip >> $VarList` if($OriBed =~ /\.gz$/);
			`cat $OriBed | grep ^'$ChrList[$i]'\$'\\t' | $Bedtools intersect -a $ChrSplitFile[$i] -b - | gzip >> $VarList` unless($OriBed =~ /\.gz$/);
			printf "[ %s ] Info collect done for %s.\n",TimeString(time,$BeginTime),$ChrList[$i];
		}
	}
	
	# 过滤人群频率及snp;
	my $VarFlt = $VarList;
	$VarFlt =~ s/gz$/Flt.gz/;
	if(1)
	{
		open(ORI,"zcat $VarList |") or die $!;
		open(FLT,"| gzip > $VarFlt") or die $!;
		while(my $Line = <ORI>)
		{
			if($Line =~ /^#/)
			{
				print FLT $Line;
				next;
			}
			
			# 过滤snv;
			chomp $Line;
			my @Cols = split /\t/, $Line;
			next if(length($Cols[3]) > 1);
			my @Alt = split /,/, $Cols[4];
			my @SnvFlag = ();
			for my $i (0 .. $#Alt)
			{
				push @SnvFlag, $i if(length($Alt[$i]) == 1);
			}
			next unless(@SnvFlag);
			
			# 任何一种snv，任何一个人群达标，均保留下来;
			my $FltFlag = 1;
			for my $i (0 .. $#ColId)
			{
				my ($AllNum,$AltString) = split /:/, $Cols[$ColId[$i]];
				next unless($AllNum > 0);
				my @AltNum = split /,/, $AltString;
				
				for my $j (0 .. $#SnvFlag)
				{
					if($AltNum[$SnvFlag[$j]] / $AllNum >= $MinFreq[$i])
					{
						$FltFlag = 0;
						last;
					}
				}
				last unless($FltFlag);
			}
			print FLT $Line,"\n" unless($FltFlag);
		}
		close ORI;
		close FLT;
	}
	printf "[ %s ] Filteration done.\n",TimeString(time,$BeginTime);
	
	# 生成新的bed;
	my $Bed4SNP = $VarList;
	$Bed4SNP =~ s/gz$/bed/;
	if(1)
	{
		`zcat $VarFlt | grep -v ^# | cut -f 1,2 | awk '{Start = \$2 - 1;print \$1"\\t"Start"\\t"\$2}' | bedtools sort -i - | bedtools merge -i - > $Bed4SNP`;
	}
}
printf "[ %s ] The end.\n",TimeString(time,$BeginTime);


######### Sub functions ######