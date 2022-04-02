#!/usr/bin/perl
use strict;
use Getopt::Long;
Getopt::Long::Configure qw(no_ignore_case);
use File::Basename;
use Parameter::BinList;
use SeqRelated::Seq;
use warnings;

my ($HelpFlag,$BinList,$BeginTime);
my ($Bed,$LogFile,$Dir);
my ($BedGeneAnnoScript,$AnnoInfo,$BedInterScript);
my $HelpInfo = <<USAGE;

 BedGeneInfo_v1.pl
 Auther: zhangdong_xie\@foxmail.com

  This script was used to show the intersections with all the exons of related genes.
  用于统计bed文件和相关基因具体外显子的重叠情况

 -i      ( Required ) Bed file which need to be analysed;
 -o      ( Required ) Result logging file;

 -bin    List for searching of related bin or scripts; 
 -h      Help infomation;

USAGE

GetOptions(
	'i=s' => \$Bed,
	'o=s' => \$LogFile,
	'bin:s' => \$BinList,
	'h!' => \$HelpFlag
) or die $HelpInfo;

if($HelpFlag || !$Bed || !$LogFile)
{
	die $HelpInfo;
}
else
{
	$BeginTime = ScriptBegin();
	
	
	die "[ Error ] Bed file not exist or empty ($Bed).\n" unless(-s $Bed);
	$Dir = dirname $LogFile;
	unless(-d $Dir)
	{
		`mkdir -p $Dir`;
		print "[ Warning ] Directory for logging not exist ($Dir).\n";
	}
	$BinList = BinListGet() if(!$BinList);
	$BedGeneAnnoScript = BinSearch("BedAnno",$BinList);
	$AnnoInfo = BinSearch("Reference",$BinList);
	$BedInterScript = BinSearch("BedInsersect",$BinList);
}


if(1)
{
	# 对bed进行基因标记;
	my $GeneAnnotatedBed = basename $Bed;
	$GeneAnnotatedBed =~ s/bed$/gene.xls/;
	$GeneAnnotatedBed = $Dir . "/" . $GeneAnnotatedBed;
	`perl $BedGeneAnnoScript -i $Bed -o $GeneAnnotatedBed`;
	printf "[ %.2fmin ] Bed related genes confirmed.\n",(time - $BeginTime)/60;
	
	
	# 生成所有基因相关的bed文件;
	my $Return = `cat $GeneAnnotatedBed | grep -v ^'#' | grep -v ^'Chr'\$'\\t' | cut -f 4 | tr -s "," "\\n" | sort | uniq`;
	chomp $Return;
	my @Gene = split /\n/, $Return;
	my $GeneDir = $Dir . "/RelatedGene";
	`mkdir $GeneDir` unless(-d $GeneDir);
	my @GeneBed = ();
	for my $i (0 .. $#Gene)
	{
		$GeneBed[$i] = $GeneDir . "/" . $Gene[$i];
		
		my %GeneInfo = %{ExonCoordInfo($AnnoInfo,$Gene[$i])};
		foreach my $Key (keys %GeneInfo)
		{
			next if($Key eq "All");
			
			my $NMId = $Key;
			my @Start = split /,/, $GeneInfo{$NMId}{"exonStarts"};
			my @End = split /,/, $GeneInfo{$NMId}{"exonEnds"};
			if($GeneInfo{$NMId}{"strand"} eq "-")
			{
				my (@tStart,@tEnd) = ();
				
				for(my $k = $#Start;$k >= 0;$k --)
				{
					push @tStart, $Start[$k];
					push @tEnd, $End[$k];
				}
				@Start = @tStart;
				@End = @tEnd;
			}
			open(GENE,"> $GeneBed[$i]") or die $!;
			for my $k (1 .. $GeneInfo{$NMId}{"exonCount"})
			{
				print GENE join("\t",$GeneInfo{$NMId}{"chrom"},$Start[$k - 1],$End[$k - 1],"Exon"),$k,"\n";
			}
			close GENE;
			
			# 只检查一个转录本;
			last;
		}
	}
	printf "[ %.2fmin ] The exons of genes confirmed.\n",(time - $BeginTime)/60;
	
	
	# 检查所有基因和该bed的区域交叉情况;
	my $CmdLine = "perl $BedInterScript -b $Bed -b " . join(" -b ",@GeneBed) . " -o $LogFile";
	`$CmdLine`;
}
printf "[ %.2fmin ] The end.\n",(time - $BeginTime)/60;


######### Sub functions ##########
