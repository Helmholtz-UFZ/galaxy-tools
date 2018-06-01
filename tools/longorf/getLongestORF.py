#!/usr/bin/env python
#input: a amino acid fasta file of all open reading frames (ORF) listed by transcript (output of GalaxyTool "getorf")

#example:

#>253936-254394(+)_1 [28 - 63] 
#LTNYCQMVHNIL
#>253936-254394(+)_2 [18 - 77] 
#HKLIDKLLPNGAQYFVKSTQ
#>253936-254394(+)_3 [32 - 148] 
#QTTAKWCTIFCKKYPVAPFHTMYLNYAVTWHHRSLLVAV
#>253936-254394(+)_4 [117 - 152] 
#LGIIVPSLLLCN
#>248351-252461(+)_1 [14 - 85] 
#VLARKYPRCLSPSKKSPCQLRQRS
#>248351-252461(+)_2 [21 - 161] 
#PGNTHDASAHRKSLRVNSDKEVKCLFTKNAASEHPDHKRRRVSEHVP
#>248351-252461(+)_3 [89 - 202] 
#VPLHQECCIGAPRPQTTACVRACAMTNTPRSSMTSKTG
#>248351-252461(+)_4 [206 - 259] 
#SRTTSGRQSVLSEKLWRR
#>248351-252461(+)_5 [263 - 313] 
#CLSPLWVPCCSRHSCHG

#output1: fasta file with all longest ORFs per transcript
#output2: table with information about seqID, start, end, length, orientation, longest for all ORFs


import sys,re;

def findlongestOrf(transcriptDict,old_seqID):
	#write for previous seqID
	prevTranscript = transcriptDict[old_seqID];
	#print prevTranscript
	i_max = 0;

	#find longest orf in transcript
	for i in range(0,len(prevTranscript)):
		if(prevTranscript[i][2] > prevTranscript[i_max][2]):
			i_max = i;
	for i in range(0,len(prevTranscript)):

		prevStart = prevTranscript[i][0];
		prevEnd = prevTranscript[i][1];
		prevLength = prevTranscript[i][2];

#				output = old_seqID + "\t" + "\t".join(prevTranscript[i]);
		output = str(old_seqID) + "\t" + str(prevStart) + "\t" + str(prevEnd) + "\t" + str(prevLength);
		
		if (end - start > 0):
			output+="\tForward";
		else:
			output+="\tReverse";


		if(i == i_max):
			output += "\ty\n";
		else:
			output += "\tn\n";

		OUTPUT_ORF_SUMMARY.write(output);

	transcriptDict.pop(old_seqID, None);
	return None;

INPUT = open(sys.argv[1],"r");
OUTPUT_FASTA = open(sys.argv[2],"w");
OUTPUT_ORF_SUMMARY = open(sys.argv[3],"w");

seqID = "";
old_seqID = "";
lengthDict = {};
seqDict = {};
headerDict = {}
transcriptDict = {};

skip = False;

OUTPUT_ORF_SUMMARY.write("seqID\tstart\tend\tlength\torientation\tlongest\n");

for line in INPUT:
	line = line.strip();
#	print line;
	if(re.match(">",line)): #header
		seqID = line.split(">")[1].split("_")[0];
		start = int (re.search('\ \[(\d+)\ -', line).group(1));
		end = int (re.search('-\ (\d+)\]',line).group(1));
		length = abs(end - start);
			

		if(seqID not in transcriptDict and old_seqID != ""): #new transcript

			findlongestOrf(transcriptDict,old_seqID);
			
		if seqID not in transcriptDict:
			transcriptDict[seqID] = [];

		transcriptDict[seqID].append([start,end,length]);



		if(seqID not in lengthDict and old_seqID != ""): #new transcript

			#write FASTA
			OUTPUT_FASTA.write(headerDict[old_seqID]+"\n"+seqDict[old_seqID]+"\n");


			#delete old dict entry
			headerDict.pop(old_seqID, None);
			seqDict.pop(old_seqID, None);
			lengthDict.pop(old_seqID, None);

		if(seqID not in lengthDict or length >= lengthDict[seqID]):
			headerDict[seqID] = line;
			lengthDict[seqID] = length;
			seqDict[seqID] = "";
			skip = False;

		else:
			skip = True;
			next;


		old_seqID = seqID;
	elif(skip):
		next;
	else:
		seqDict[seqID] += line;

OUTPUT_FASTA.write(headerDict[old_seqID]+"\n"+seqDict[old_seqID]);
findlongestOrf(transcriptDict,old_seqID);

INPUT.close();
OUTPUT_FASTA.close();
OUTPUT_ORF_SUMMARY.close();
