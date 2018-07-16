#!/usr/bin/env python

#example:
#>STRG.1.1(-)_1 [10 - 69]
#GGNHHTLGGKKTFSYTHPPC
#>STRG.1.1(-)_2 [3 - 80]
#FLRGEPPHIGGKKDIFLHPPTLLKGR

#output1: fasta file with all longest ORFs per transcript
#output2: table with information about seqID, transcript, start, end, strand, length, sense, longest? for all ORFs

import sys,re;

def findlongestOrf(transcriptDict,old_seqID):
	#write for previous seqID
	prevTranscript = transcriptDict[old_seqID];
	i_max = 0;
	transcript = old_seqID.split("(")[0]

	#find longest orf in transcript
	for i in range(0,len(prevTranscript)):
		if(prevTranscript[i][2] >= prevTranscript[i_max][2]):
			i_max = i;

	for i in range(0,len(prevTranscript)):
		prevORFstart = prevTranscript[i][0];
		prevORFend = prevTranscript[i][1];
		prevORFlength = prevTranscript[i][2];
		header = prevTranscript[i][3];
		strand = re.search('\(([+-]+)\)',header).group(1);
		
		output = str(header) + "\t" + str(transcript) + "\t" + str(prevORFstart) + "\t" + str(prevORFend) + "\t" + str(prevORFlength) + "\t" + str(strand);
		if (prevORFend - prevORFstart > 0):
			output+="\tnormal";
		else:
			output+="\treverse_sense";
		if(i == i_max):
			output += "\ty\n";
		else:
			output += "\tn\n";

		OUTPUT_ORF_SUMMARY.write(output);

	transcriptDict.pop(old_seqID, None);
	return None;

#-----------------------------------------------------------------------------------------------------

INPUT = open(sys.argv[1],"r");
OUTPUT_FASTA = open(sys.argv[2],"w");
OUTPUT_ORF_SUMMARY = open(sys.argv[3],"w");

seqID = "";
old_seqID = "";
lengthDict = {};
seqDict = {};
headerDict = {};
transcriptDict = {};

skip = False;

OUTPUT_ORF_SUMMARY.write("seqID\ttranscript\torf_start\torf_end\tlength\tstrand\tsense\tlongest\n");

for line in INPUT:
	line = line.strip();
	if(re.match(">",line)): #header
		header = line
		seqID = "_".join(line.split(">")[1].split("_")[:-1])
		ORFstart = int (re.search('\ \[(\d+)\ -', line).group(1));
		ORFend = int (re.search('-\ (\d+)\]',line).group(1));
		length = abs(ORFend - ORFstart);

		if(seqID not in transcriptDict and old_seqID != ""): #new transcript
			findlongestOrf(transcriptDict,old_seqID);
			
		if seqID not in transcriptDict:
			transcriptDict[seqID] = [];

		transcriptDict[seqID].append([ORFstart,ORFend,length,header]);

		if(seqID not in lengthDict and old_seqID != ""): #new transcript
			#write FASTA
			OUTPUT_FASTA.write(headerDict[old_seqID]+"\n"+seqDict[old_seqID]+"\n");
			#delete old dict entry
			headerDict.pop(old_seqID, None);
			seqDict.pop(old_seqID, None);
			lengthDict.pop(old_seqID, None);
		#if several longest sequences exist with the same length, the dictionary saves the last occuring.
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