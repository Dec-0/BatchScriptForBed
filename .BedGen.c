#include <stdio.h>
#include <stdlib.h>  // for file handle;
#include <getopt.h> // for argument;
#include <time.h>
#include <errno.h>
#include <sys/types.h>
#include <unistd.h>
#include <string.h>

time_t start,end,dur_min,dur_sec,dur_hour;
FILE *fid,*fod;
unsigned char *InPath,*OutPath;
unsigned char Id1 = 0;
unsigned char Id2 = 1;
unsigned char BuffContent[1000000];
unsigned char *tChr,**Chr;
unsigned int *Pos,**Flag;
unsigned int MaxArraySize,MaxCharSize,HeadFlag;
unsigned int BuffSize,LineStart,LineEnd,AccumId;
unsigned int MaxBuffSize = 1000000;


// _________________________________________________
//
//                  Sub functions
// _________________________________________________

//*************
//  logging
int TimeLog(unsigned char *String)
{
	time(&end);
	dur_sec = end - start;
	if(dur_sec < 60)
	{
		printf("[ %ds ] %s.\n",dur_sec,String);
	}
	else
	{
		dur_min = (int)(dur_sec / 60);
		dur_sec = (int)(dur_sec % 60);
		if(dur_min < 60)
		{
			printf("[ %dmin%ds ] %s.\n",dur_min,dur_sec,String);
		}
		else
		{
			dur_hour = (int)(dur_min / 60);
			dur_min = (int)(dur_min % 60);
			printf("[ %dh%dmin ] %s.\n",dur_hour,dur_min,String);
		}
	}
	
	return 1;
}

int OptGet(int argc, char *argv[])
{
	unsigned char InFile[10] = "infile";
	unsigned char OutFile[10] = "outfile";
	unsigned char Header[10] = "Header";
	unsigned char Help[5] = "help";
	unsigned char OptHash[5];
	unsigned char Info[2000] = "\n  BedGen      2019.5.10\n  Contact:zhangdong_xie@foxmail.com\n\
  It's used for generate bed according position.\n\nArguments:\n\
 -i/-infile   ( Required ) File recording chr and pos.\n\
 -o/-outfile  ( Required ) Bed file.\n\
 -H/-Header   ( Required ) If the first line is a header.\n\
 -h/-help     ( Optional ) Help info.\n\n";
	unsigned int tmp,i,j,k;
	
	// no or too much arguments;
	if(argc == 1)
	{
		printf("[ Error ] No argument specified.%s",Info);
		exit(1);
	}
	else if(argc > 6)
	{
		printf("[ Error ] Too much arguments.%s",Info);
		exit(1);
	}
	
	// opthash 
	memset(OptHash,0,5);
	for(i = 1;i < argc;i ++)
	{
		if(argv[i][0] == '-')
		{
			j = 1;
			if(argv[i][j] == '-')
			{
				j ++;
			}
			
			if(argv[i][j] == InFile[0])
			{
				if(OptHash[1])
				{
					printf("[ Error ] Argument -i/-infile specifed more than once.\n");
					exit(1);
				}
				
				// match with "infile";
				if(argv[i][j + 1])
				{
					if(argv[i][j + 6] == 0)
					{
						tmp = 1;
						for(k = j + 1;k < j + 6;k ++)
						{
							if(argv[i][k] != InFile[tmp])
							{
								printf("[ Error ] Wrong format for -infile.%s",Info);
								exit(1);
							}
							tmp ++;
						}
					}
					else
					{
						printf("[ Error ] Wrong format for -i.%s",Info);
						exit(1);
					}
				}
				
				// must followed with value;
				i ++;
				InPath = argv[i];
				OptHash[1] = 1;
			}
			else if(argv[i][j] == OutFile[0])
			{
				if(OptHash[2])
				{
					printf("[ Error ] Argument -o/-outfile specifed more than once.\n");
					exit(1);
				}
				
				// match with "outfile";
				if(argv[i][j + 1])
				{
					if(argv[i][j + 7] == 0)
					{
						tmp = 1;
						for(k = j + 1;k < j + 7;k ++)
						{
							if(argv[i][k] != OutFile[tmp])
							{
								printf("[ Error ] Wrong format for -outfile.%s",Info);
								exit(1);
							}
							tmp ++;
						}
					}
					else
					{
						printf("[ Error ] Wrong format for -o.%s",Info);
						exit(1);
					}
				}
				
				// must followed with value;
				i ++;
				OutPath = argv[i];
				OptHash[2] = 1;
			}
			else if(argv[i][j] == Header[0])
			{
				if(OptHash[3])
				{
					printf("[ Error ] Argument -H/-Header specifed more than once.\n");
					exit(1);
				}
				
				// match with "outfile";
				if(argv[i][j + 1])
				{
					if(argv[i][j + 6] == 0)
					{
						tmp = 1;
						for(k = j + 1;k < j + 7;k ++)
						{
							if(argv[i][k] != Header[tmp])
							{
								printf("[ Error ] Wrong format for -Header.%s",Info);
								exit(1);
							}
							tmp ++;
						}
					}
					else
					{
						printf("[ Error ] Wrong format for -H.%s",Info);
						exit(1);
					}
				}
				
				// must followed with value;
				OptHash[3] = 1;
			}
			else if(argv[i][j] == Help[0])
			{
				// match with "help";
				if(argv[i][j + 1])
				{
					if(argv[i][j + 4] == 0)
					{
						tmp = 1;
						for(k = j + 1;k < j + 4;k ++)
						{
							if(argv[i][k] != Help[tmp])
							{
								printf("[ Error ] Wrong format for -help.%s",Info);
								exit(1);
							}
							tmp ++;
						}
					}
					else
					{
						printf("[ Error ] Wrong format for -h.%s",Info);
						exit(1);
					}
				}
				
				printf("%s",Info);
				exit(1);
			}
		}
		else
		{
			printf("[ Error ] Unknown argument: %s.",argv[i]);
			exit(1);
		}
	}
	
	if(OptHash[1] == 0)
	{
		printf("[ Error ] No infile specified.%s",Info);
		exit(1);
	}
	if(OptHash[2] == 0)
	{
		printf("[ Error ] No outfile specified.%s",Info);
		exit(1);
	}
	if(OptHash[3])
	{
		HeadFlag = 1;
	}
	else
	{
		HeadFlag = 0;
	}
	
	return 1;
}

int LineCap()
{
	int BackShift;
	
	if(LineEnd == BuffSize)
	{
		BuffSize = fread(BuffContent,1,MaxBuffSize,fid);
		if(BuffSize == 0)
		{
			return 0;
		}
		LineStart = 0;
		LineEnd = 0;
	}
	else
	{
		LineStart = LineEnd + 1;
		LineEnd = LineStart;
	}
	
	for(LineEnd;LineEnd < BuffSize;LineEnd ++)
	{
		if(BuffContent[LineEnd] == '\n')
		{
			return 1;
		}
	}
	
	// relocating;
	BackShift = LineStart - BuffSize;
	fseek(fid,BackShift,SEEK_CUR);
	BuffSize = fread(BuffContent,1,MaxBuffSize,fid);
	if(BuffSize == 0)
	{
		return 0;
	}
	LineStart = 0;
	LineEnd = 0;
	for(LineEnd;LineEnd < BuffSize;LineEnd ++)
	{
		if(BuffContent[LineEnd] == '\n')
		{
			return 1;
		}
	}
	
	return 0;
}

int MaxArrayConfirm(unsigned char *File)
{
	unsigned int i,tmpId,tmpNum;
	
	MaxArraySize = 0;
	MaxCharSize = 0;
	tmpId = 0;
	tmpNum = 0;
	fid = fopen(File,"r");
	if(fid == NULL)
	{
		printf("File cannot be open: %s\n",File);
		exit(1);
	}
	while(BuffSize = fread(BuffContent,1,MaxBuffSize,fid))
	{
		for(i = 0;i < BuffSize;i ++)
		{
			if(BuffContent[i] == '\t')
			{
				tmpId ++;
			}
			if(tmpId < 1)
			{
				tmpNum ++;
			}
			if(BuffContent[i] == '\n')
			{
				MaxArraySize ++;
				if(tmpNum > MaxCharSize)
				{
					MaxCharSize = tmpNum;
				}
				tmpId = 0;
				tmpNum = 0;
			}
		}
	}
	fclose(fid);
	MaxArraySize = (unsigned int)(MaxArraySize * 1.05);
	
	return 1;
}

//**************************
//   arguments initiating
int ArgumentsInit(int argc, char *argv[])
{
	// Get the input and output file path;
	OptGet(argc,argv);
	
	// confirm the maximal array size;
	MaxArrayConfirm(InPath);
	
	return 1;
}


int MemoryRequire1()
{
	unsigned char i;
	
	if((tChr = (unsigned char *)malloc(MaxArraySize * sizeof(unsigned char))) == NULL)
	{
		printf("[ Error ] Malloc memory unsuccessfully ( tChr %d).\n",MaxArraySize);
		exit(1);
	}
	if((Chr = (unsigned char **)malloc(MaxCharSize * sizeof(unsigned char *))) == NULL)
	{
		printf("[ Error ] Malloc memory unsuccessfully ( ChrFull %d).\n",MaxCharSize);
		exit(1);
	}
	for(i = 0;i < MaxCharSize;i ++)
	{
		if((Chr[i] = (unsigned char *)malloc(MaxArraySize * sizeof(unsigned char))) == NULL)
		{
			printf("[ Error ] Malloc memory unsuccessfully ( Chr%d %d).\n",i,MaxArraySize);
			exit(1);
		}
	}
	if((Pos = (unsigned int *)malloc(MaxArraySize * sizeof(unsigned int))) == NULL)
	{
		printf("[ Error ] Malloc memory unsuccessfully ( Pos %d).\n",MaxArraySize);
		exit(1);
	}
	if((Flag = (unsigned int **)malloc(2 * sizeof(unsigned int *))) == NULL)
	{
		printf("[ Error ] Malloc memory unsuccessfully ( Flag %d).\n",2);
		exit(1);
	}
	for(i = 0;i < 2;i ++)
	{
		if((Flag[i] = (unsigned int *)malloc(MaxArraySize * sizeof(unsigned int))) == NULL)
		{
			printf("[ Error ] Malloc memory unsuccessfully ( Flag%d %d).\n",i,MaxArraySize);
			exit(1);
		}
	}
	
	return 1;
}


int MemoryFree1()
{
	free(Flag);
	free(tChr);
	free(Chr);
	free(Pos);
	
	return 1;
}

unsigned int Char2Num(unsigned char *String)
{
	unsigned int i,Multi,Total;
	
	Multi = 10;
	Total = 0;
	i = 0;
	while(String[i])
	{
		Total = Total * Multi + String[i] - 48;
		i ++;
	}
	
	return Total;
}

unsigned char Chr2Num(unsigned char *String)
{
	unsigned char i,Len,CharFlag,Multi,Total;
	
	Len = 0;
	while(String[Len])
	{
		Len ++;
	}
	
	CharFlag = 0;
	for(i = 3;i < Len;i ++)
	{
		if(String[i] < 48 || String[i] > 57)
		{
			CharFlag = 1;
			break;
		}
	}
	
	if(CharFlag)
	{
		if(Len == 4)
		{
			if(String[3] == 'M' || String[3] == 'm')
			{
				return 0;
			}
			else if(String[3] == 'X' || String[3] == 'x')
			{
				return 23;
			}
			else if(String[3] == 'Y' || String[3] == 'y')
			{
				return 24;
			}
			else
			{
				return 25;
			}
		}
		else
		{
			return 25;
		}
	}
	else
	{
		if(Len <= 5)
		{
			Multi = 10;
			Total = 0;
			i = 3;
			while(String[i])
			{
				Total = Total * Multi + String[i] - 48;
				i ++;
			}
			
			return Total;
		}
		else
		{
			return 25;
		}
	}
	
	return 0;
}

//*************************************
//        collect read info
int InfoCollect(unsigned char *FilePath)
{
	unsigned char tmpChr[30],tmpPos[30];
	unsigned int i;
	unsigned int tmpId,TabNum;
	
	MemoryRequire1();
	
	LineEnd = 0;
	BuffSize = 0;
	AccumId = 0;
	fid = fopen(FilePath,"r");
	if(fid == NULL)
	{
		printf("File cannot be open: %s\n",FilePath);
		exit(1);
	}
	if(HeadFlag)
	{
		LineCap();
	}
	while(LineCap())
	{
		TabNum = 0;
		tmpId = 0;
		for(i = LineStart;i < LineEnd;i ++)
		{
			if(BuffContent[i] == '\t')
			{
				TabNum ++;
				tmpId = 0;
			}
			else
			{
				if(TabNum == 0)
				{
					tmpChr[tmpId] = BuffContent[i];
					tmpId ++;
					tmpChr[tmpId] = '\0';
				}
				else if(TabNum == 1)
				{
					tmpPos[tmpId] = BuffContent[i];
					tmpId ++;
					tmpPos[tmpId] = '\0';
				}
			}
		}
		
		*(tChr + AccumId) = Chr2Num(tmpChr);
		for(i = 0;i < MaxCharSize;i ++)
		{
			*(Chr[i] + AccumId) = '\0';
		}
		tmpId = 0;
		while(tmpChr[tmpId])
		{
			*(Chr[tmpId] + AccumId) = tmpChr[tmpId];
			tmpId ++;
		}
		*(Pos + AccumId) = Char2Num(tmpPos);
		AccumId ++;
	}
	*(tChr + AccumId) = '\0';
	for(i = 0;i < MaxCharSize;i ++)
	{
		*(Chr[i] + AccumId) = '\0';
	}
	*(Pos + AccumId) = '\0';
	fclose(fid);
	
	return 1;
}

int MapCompar(unsigned int First, unsigned int Second)
{
	unsigned int i;
	
	if(*(tChr + First) > *(tChr + Second))
	{
		return 2;
	}
	else if(*(tChr + First) < *(tChr + Second))
	{
		return 0;
	}
	
	for(i = 0;i < MaxCharSize;i ++)
	{
		if(*(Chr[i] + First) > *(Chr[i] + Second))
		{
			return 2;
		}
		else if(*(Chr[i] + First) < *(Chr[i] + Second))
		{
			return 0;
		}
	}
	
	if(*(Pos + First) > *(Pos + Second))
	{
		return 2;
	}
	else if(*(Pos + First) < *(Pos + Second))
	{
		return 0;
	}
	
	return 1;
}


int Rank()
{
	unsigned int i,j,tmp,tmpId;
	unsigned int MaxDulSpan,DulSpan,MinSpan;
	unsigned int LeftBegin,LeftEnd,RightBegin,RightEnd;
	
	for(i = 0;i < AccumId;i ++)
	{
		*(Flag[Id1] + i) = i;
	}
	
	// Combine of the sorted mini-array;
	MaxDulSpan = AccumId << 1;
	for(DulSpan = 2;DulSpan < MaxDulSpan;DulSpan = DulSpan << 1)
	{
		MinSpan = DulSpan >> 1;
		tmpId = 0;
		
		for(i = 0;i < AccumId;i += DulSpan)
		{
			LeftBegin = i;
			RightBegin = LeftBegin + MinSpan;
			if(RightBegin < AccumId)
			{
				LeftEnd = RightBegin - 1;
				RightEnd = LeftEnd + MinSpan;
				if(RightEnd > AccumId - 1)
				{
					RightEnd = AccumId - 1;
				}
				
				while(LeftBegin <= LeftEnd || RightBegin <= RightEnd)
				{
					if(LeftBegin > LeftEnd)
					{
						*(Flag[Id2] + tmpId) = *(Flag[Id1] + RightBegin);
						RightBegin ++;
					}
					else if(RightBegin > RightEnd)
					{
						*(Flag[Id2] + tmpId) = *(Flag[Id1] + LeftBegin);
						LeftBegin ++;
					}
					else if(MapCompar(*(Flag[Id1] + LeftBegin),*(Flag[Id1] + RightBegin)) > 1)
					{
						*(Flag[Id2] + tmpId) = *(Flag[Id1] + RightBegin);
						RightBegin ++;
					}
					else
					{
						*(Flag[Id2] + tmpId) = *(Flag[Id1] + LeftBegin);
						LeftBegin ++;
					}
					tmpId ++;
				}
			}
			else
			{
				for(j = LeftBegin;j < AccumId;j ++)
				{
					*(Flag[Id2] + tmpId) = *(Flag[Id1] + j);
					tmpId ++;
				}
			}
		}
		tmp = Id1;
		Id1 = Id2;
		Id2 = tmp;
	}
	
	
	return 1;
}

unsigned char ChrCompar(unsigned int First, unsigned int Second)
{
	unsigned char i;
	
	for(i = 0;i < MaxCharSize;i ++)
	{
		if(*(Chr[i] + First) > *(Chr[i] + Second))
		{
			return 2;
		}
		else if(*(Chr[i] + First) < *(Chr[i] + Second))
		{
			return 0;
		}
	}
	
	return 1;
}

unsigned int BuffChrFill(unsigned char *Buff, unsigned int Id, unsigned tmp)
{
	unsigned char i;
	
	for(i = 0;i < MaxCharSize;i ++)
	{
		if(*(Chr[i] + tmp))
		{
			Buff[Id] = *(Chr[i] + tmp);
			Id ++;
		}
		else
		{
			break;
		}
	}
	
	return Id;
}

unsigned int BuffPosFill(unsigned char *Buff, unsigned int Id, unsigned int Num)
{
	unsigned int i,BitNum,tmpId;
	
	BitNum = 10;
	for(i = 1;i < 20;i ++)
	{
		if(Num < BitNum)
		{
			break;
		}
		BitNum = BitNum * 10;
	}
	BitNum = BitNum / 10;
	
	tmpId = 0;
	while(BitNum)
	{
		Buff[Id] = (unsigned int)(Num / BitNum) % 10 + 48;
		BitNum = (unsigned int)(BitNum / 10);
		Id ++;
	}
	Id = Id - 1;
	
	return Id;
}

//******************
//   final output
int FinalRevise()
{
	unsigned char OutBuff[1000000];
	unsigned int OutBuffId,i,PreChrId,PrePos;
	unsigned int MaxOutBuffSize = 800000;
	
	fod = fopen(OutPath,"w");
	if(fod == NULL)
	{
		printf("File creation failed for %s.\n",OutPath);
		exit(1);
	}
	OutBuffId = 0;
	OutBuffId = BuffChrFill(OutBuff,OutBuffId,*(Flag[Id1] + 0));
	OutBuff[OutBuffId] = '\t';
	OutBuffId ++;
	OutBuffId = BuffPosFill(OutBuff,OutBuffId,*(Pos + *(Flag[Id1] + 0)) - 1);
	OutBuffId ++;
	PreChrId = *(Flag[Id1] + 0);
	PrePos = *(Pos + *(Flag[Id1] + 0));
	for(i = 1;i < AccumId;i ++)
	{
		if(ChrCompar(PreChrId,*(Flag[Id1] + i)) == 1 && (*(Pos + *(Flag[Id1] + i)) == PrePos || *(Pos + *(Flag[Id1] + i)) == PrePos + 1))
		{
			if(*(Pos + *(Flag[Id1] + i)) == PrePos + 1)
			{
				PrePos ++;
			}
		}
		else
		{
			OutBuff[OutBuffId] = '\t';
			OutBuffId ++;
			OutBuffId = BuffPosFill(OutBuff,OutBuffId,PrePos);
			OutBuffId ++;
			OutBuff[OutBuffId] = '\n';
			OutBuffId ++;
			
			OutBuffId = BuffChrFill(OutBuff,OutBuffId,*(Flag[Id1] + i));
			OutBuff[OutBuffId] = '\t';
			OutBuffId ++;
			OutBuffId = BuffPosFill(OutBuff,OutBuffId,*(Pos + *(Flag[Id1] + i)) - 1);
			OutBuffId ++;
			PreChrId = *(Flag[Id1] + i);
			PrePos = *(Pos + *(Flag[Id1] + i));
		}
		
		if(OutBuffId > MaxOutBuffSize)
		{
			fwrite(OutBuff,1,OutBuffId,fod);
			OutBuffId = 0;
		}
	}
	OutBuff[OutBuffId] = '\t';
	OutBuffId ++;
	OutBuffId = BuffPosFill(OutBuff,OutBuffId,PrePos);
	OutBuffId ++;
	OutBuff[OutBuffId] = '\n';
	OutBuffId ++;
	fwrite(OutBuff,1,OutBuffId,fod);
	fclose(fod);
	MemoryFree1();
	
	return 1;
}


// ___________________________________
//
//            Main Part
// ___________________________________
int main(int argc, char *argv[])
{
	time(&start);
	
	// arguments initiation;
	ArgumentsInit(argc,argv);

	// Collect the reads info from sam;
	TimeLog("Info collecting");
	InfoCollect(InPath);
	
	
	// Order by query name;
	TimeLog("Sorting");
	Rank();
	
	
	// revise the flag and output the dup marked file;
	TimeLog("Final revising");
	FinalRevise();
	
	
	// time and rate logging;
	TimeLog("The end");
}