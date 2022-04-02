#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
Getopt::Long::Configure qw(no_ignore_case);
use File::Basename;
use Statistics::R;
use FindBin qw($Bin);
use lib "$Bin/.Modules";
use Parameter::BinList;
use Sort::ChrPos;

my ($HelpFlag,$BinList,$BeginTime);
my $ThisScriptName = basename $0;
my $LogFile;
my (@Bed,@BedCol4Flag);
my $HelpInfo = <<USAGE;

 $ThisScriptName
 Auther: zhangdong_xie\@foxmail.com

  This script was used to show the intersecting status of two or more bed areas.
  这个脚本用于统计、展示两个或者多个bed区域的交集、并集的情况。
  
  和上一版本相比，显著提高了运行速度。

 -b      ( Required ) Bed format files (multi times);
 -o      ( Required ) The file for logging;

 -bin    List for searching of related bin or scripts; 
 -h      Help infomation;

USAGE

GetOptions(
	'b=s' => \@Bed,
	'o=s' => \$LogFile,
	'bin:s' => \$BinList,
	'h!' => \$HelpFlag
) or die $HelpInfo;

if($HelpFlag || !@Bed || !$LogFile)
{
	die $HelpInfo;
}
else
{
	$BeginTime = ScriptBegin(0,$ThisScriptName);
	
	for my $i (0 .. $#Bed)
	{
		die "[ Error ] File not exist ($Bed[$i]).\n" unless(-e $Bed[$i]);
	}
	my $Dir = dirname $LogFile;
	unless($Dir && -d $Dir)
	{
		`mkdir -p $Dir`;
		print "[ Warning ] Directory for logging not exist ($Dir).\n";
	}
	$BinList = BinListGet() if(!$BinList);
}

if(1)
{
	# 输入所有bed相关的坐标信息;
	my %Base = ();
	for my $i (0 .. $#Bed)
	{
		my $BedId = $i + 1;
		
		open(TBED,"cat $Bed[$i] | grep -v ^# | grep -v ^'Chr'\$'\\t' |") or die $! unless($Bed[$i] =~ /\.gz$/);
		open(TBED,"zcat $Bed[$i] | grep -v ^# | grep -v ^'Chr'\$'\\t' |") or die $! if($Bed[$i] =~ /\.gz$/);
		while(my $Line = <TBED>)
		{
			chomp $Line;
			my @Cols = split /\t/, $Line;
			@Cols = split /\s+/, $Line if($#Cols < 2);
			my $tString = substr($Cols[0],3);
			if($tString =~ /[^\dMXY]/)
			{
				print "[ Info ] Ignore $Line \n";
				next;
			}
			
			for my $j ($Cols[1] + 1 .. $Cols[2])
			{
				my $Key = $Cols[0] . "\t" . $j;
				if($Base{$Key})
				{
					$Base{$Key} .= "\t" . $BedId;
				}
				else
				{
					$Base{$Key} = $BedId;
				}
			}
		}
		close TBED;
		
		my $Col4 = "";
		$Col4 = `cat $Bed[$i] | head -n1 | cut -f 4` unless($Bed[$i] =~ /\.gz$/);
		$Col4 = `zcat $Bed[$i] | head -n1 | cut -f 4` if($Bed[$i] =~ /\.gz$/);
		chomp $Col4;
		$BedCol4Flag[$i] = 0;
		$BedCol4Flag[$i] = 1 if($Col4);
	}
	printf "[ %s ] Info collection done.\n",TimeString(time,$BeginTime);
	
	# 定位连续的区域;
	my (@Chr,@Start,@End) = ();
	if(%Base)
	{
		my (@SortChr,@SortFrom,@SortTo,@SortOther) = ();
		foreach my $Key (keys %Base)
		{
			my ($tChr,$tPos) = split /\t/, $Key;
			my $tPrePos = $tPos - 1;
			my $tPreKey = join("\t",$tChr,$tPrePos);
			my $tPastPos = $tPos + 1;
			my $tPastKey = join("\t",$tChr,$tPastPos);
			next if($Base{$tPreKey} && $Base{$tPastKey});
			
			if(!$Base{$tPreKey})
			{
				push @SortChr, $tChr;
				push @SortFrom, $tPos;
				push @SortTo, $tPos;
				push @SortOther, $tPos;
			}
			if(!$Base{$tPastKey})
			{
				push @SortChr, $tChr;
				push @SortFrom, $tPos;
				push @SortTo, $tPos;
				push @SortOther, $tPos;
			}
		}
		
		my ($ChrRef,$FromRef,$ToRef,$OtherRef) = ChrPosAndOther(\@SortChr,\@SortFrom,\@SortTo,\@SortOther);
		@SortChr = @{$ChrRef};
		@SortFrom = @{$FromRef};
		my $ItemNum = @SortChr;
		die "[ Error ] The number of Start and End points of related areas not even.\n" unless($ItemNum % 2 == 0);
		$ItemNum = int($ItemNum / 2);
		for my $i (0 .. $ItemNum - 1)
		{
			my $SId = $i * 2;
			my $EId = $SId + 1;
			
			my ($SChr,$SPos) = ($SortChr[$SId],$SortFrom[$SId]);
			my ($EChr,$EPos) = ($SortChr[$EId],$SortFrom[$EId]);
			die "[ Error ] Diff chr of same area ($SortChr[$SId],$SortFrom[$SId] - $SortChr[$EId],$SortFrom[$EId]).\n" unless($SChr eq $EChr);
			die "[ Error ] End position smaller ($SortChr[$SId],$SortFrom[$SId] - $SortChr[$EId],$SortFrom[$EId]).\n" unless($EPos >= $SPos);
			
			push @Chr, $SChr;
			push @Start, $SPos;
			push @End, $EPos;
		}
	}
	printf "[ %s ] Localization of consecutive area done.\n",TimeString(time,$BeginTime);
	
	# 在连续区域内按样本信息分组输出（并连带输出bed中第4列信息）;
	open(LOG,"> $LogFile") or die $! unless($LogFile =~ /\.gz$/);
	open(LOG,"| gzip > $LogFile") or die $! if($LogFile =~ /\.gz$/);
	print LOG "#Chr\tStart\tEnd\tFiles\n";
	for my $i (0 .. $#Chr)
	{
		my $PrePos = $Start[$i];
		my $Key = $Chr[$i] . "\t" . $PrePos;
		my $PreId = $Base{$Key};
		my $CurrPos = $PrePos + 1;
		while($CurrPos <= $End[$i])
		{
			$Key = $Chr[$i] . "\t" . $CurrPos;
			my $CurrId = $Base{$Key};
			if($CurrId ne $PreId)
			{
				my $IdString = &IdTrans($PreId,$Chr[$i],$PrePos - 1,$CurrPos - 1);
				print LOG "$Chr[$i]\t",$PrePos - 1,"\t",$CurrPos - 1,"\t",$IdString,"\n";
				
				$PrePos = $CurrPos;
				$PreId = $CurrId;
			}
			$CurrPos ++;
		}
		my $IdString = &IdTrans($PreId,$Chr[$i],$PrePos - 1,$CurrPos - 1);
		print LOG "$Chr[$i]\t",$PrePos - 1,"\t",$CurrPos - 1,"\t",$IdString,"\n";
	}
	close LOG;
}
printf "[ %s ] All done.\n",TimeString(time,$BeginTime);


######### Sub functions ##########
sub IdTrans
{
	my ($String,$Chr,$From,$To) = @_;
	
	my $TransInfo = "";
	# String中记录了相关bed的index号;
	my @Cols = split /\t/, $String;
	for my $i (0 .. $#Cols)
	{
		my $BedId = $Cols[$i] - 1;
		my $BaseName = basename $Bed[$BedId];
		$TransInfo .= ", " . $BaseName;
		
		# 获得Bed文件中的第4列信息，假如有的话;
		if($BedCol4Flag[$BedId])
		{
			my $tInfo = `grep ^'$Chr'\$'\\t' $Bed[$BedId] | awk '{if($From > \$3){next};if($From <= \$3 && $To >= \$2){print \$4};if($To < \$2){exit}}'`;
			chomp $tInfo;
			if($tInfo && $tInfo =~ /[^\n]/)
			{
				my @Items = split /\n/, $tInfo;
				$TransInfo .= "(" . join(",",@Items) . ")";
			}
		}
	}
	$TransInfo =~ s/^, //;
	
	return $TransInfo;
}