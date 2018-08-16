#!/bin/bash


#reset old data
rm -rf plot*
rm -rf checkm_*

if [ ! -d test-data ]; then 
	mkdir -f test-data
	mkdir -f test-data/2015_01_16
	pushd test-data/2015_01_16
	wget https://data.ace.uq.edu.au/public/CheckM_databases/checkm_data_2015_01_16.tar.gz
	tar -xf checkm_data_2015_01_16.tar.gz
	rm checkm_data_2015_01_16.tar.gz
	popd
fi

echo '<?xml version="1.0"?>
<datatypes>
    <!--    
    <datatype_files>
	    <datatype_file name="gmql.py" />
    </datatype_files>-->
    <registration>
    </registration>
    <!--<sniffers>
        <sniffer type="galaxy.datatypes.gmql:Gdm" />
    </sniffers>-->
</datatypes>' > datatypes_conf.xml


echo "<macros>" > plot_macros.xml
cat checkm.xml | grep "<tool" | cut -d"\"" -f 2 | while IFS= read -r fname
do
	echo $fname
	if [ `echo $fname | grep "checkm"` ]; then 	# real commands go to separate tools

		# create tool dir and macro link
		if [ -d $fname ]; then
			rm -rf $fname/*
		else
			mkdir $fname/
		fi

		for i in macros.xml plot_macros.xml test-data datatypes_conf.xml 
		do
			ln -sf ../$i $fname/$i
		done

		# prepare the empty tool specific macro files 
		# and link them in the tool dir (under a common name which can be auto generated)
		touch macros_$fname.xml
		ln -sf ../macros_$fname.xml $fname/tool-macros.xml

		# add data types
		sed -i -e "s/<registration>/<registration>\n    <datatype extension=\"$fname\" type=\"galaxy.datatypes.data:Text\" subclass=\"True\" \/>/" datatypes_conf.xml

		sedcmd="/<tool id=\"$fname\"/,/<\/tool>/!d"
		# get the part of the xml + make it a single line
		sed -e "$sedcmd" checkm.xml |
			awk '{printf("%sENDOFLINEMARKER", $0)}' |
			# replace version
			sed 's/version="1.0"/version="@TOOL_VERSION@"/' |
			# replace stdio, version_command by macros and add requirements macro
			sed 's#<stdio>.*</version_command>#<macros>\n    <import>macros.xml</import>\n    <import>plot_macros.xml</import>\n    <import>tool-macros.xml</import>\n  </macros>\n  <expand macro="requirements"/>\n  <expand macro="stdio"/>\n  <expand macro="version_command"/>#g' |
                        # add citation macro
			sed 's#</help>#</help>\n  <expand macro="citations"/>#' |
			# remove numbers behind variables (positionals)
			sed 's/_[0-9]//g' |
			# fix --threads
			sed 's/#if $threads.*$threadsENDOFLINEMARKER#end ifENDOFLINEMARKER/--threads \\${GALAXY_SLOTS:-1}/g' |
			sed 's/#if $pplacer_threads.*$pplacer_threadsENDOFLINEMARKER#end ifENDOFLINEMARKER/--pplacer_threads \\${GALAXY_SLOTS:-1}/g' |
			# remove extension
			sed 's/#if $extension.*$extension[0-9]*ENDOFLINEMARKER#end if//g' |
			# replace bin_folder and seq_file argument
			sed 's/#if $\(bin_folder[0-9]*\).*$bin_folder[0-9]*ENDOFLINEMARKER#end ifENDOFLINEMARKER/\1/' |
			sed 's/#if \$seq_file.*$seq_fileENDOFLINEMARKER#end ifENDOFLINEMARKER/"\$seq_file"/' |
			sed "s/#if \$out_folder.*$out_folderENDOFLINEMARKER#end if/'\$output.extra_files_path'/" |
			sed 's/#if $out_format.*$out_formatENDOFLINEMARKER#end if/--out_format $out_format/' |
			# for tools that have --file / --output_file
			sed "s/#if $file.*$fileENDOFLINEMARKER#end if/--file '\$file'/" |
			sed "s/#if $output_file.*$output_fileENDOFLINEMARKER#end if/'\$output_file'/" |
                        # replace multi bam input by proper param
			sed 's@ *<repeat min="1" name="repeat" title="repeat_title">ENDOFLINEMARKER *<param area="false" label="BAM files to parse" name="bam_files" type="text"/>ENDOFLINEMARKER *</repeat>@<param name="bam_files" type="data" label="BAM files to parse" multiple="true" format="bam"/>@' |
			sed 's/#set repeat_var = '"'"'\" \"'"'"'.join(\[ str($var.bam_files) for $var in $repeat \])ENDOFLINEMARKER/#for $k, $f in enumerate($bam_file)\n    #if $f\n        \"${f}\"\n    #end if\n#end for/' |
			# rename redirect of stdout and cp extra_files to out_folder (for gathering collectiions)
			sed "s/> \$default/> '\$output'\n\&\&cp -r '\$output.extra_files_path' out_folder\n/" |
			# reinsert newlines
			sed 's/\(ENDOFLINEMARKER\)\+/\n/g' | 
			# set min and max of floats that have the word percentage in the label
			sed 's/\(percentage.*type="float"\)/\1 min="0.0" max="1.0"/' |
			# fix bin_folder and seq_file params
			sed 's#<param area="false" label="folder containing bins (fasta format)" name="bin_folder\([0-9]*\)" type="text"/>#<param name="bin_folder\1" type="data" label="bins" multiple="true" format="fasta"/>#' |
			sed 's#<param area="false" label="sequences used to generate bins (fasta format)" name="seq_file" type="text"/>#<param name="seq_file" type="data" label="sequences used to generate bins" format="fasta"/>#' |
			# fix out_format (make it a select)
			sed 's@<param argument="--out_format.*"@<param argument="--out_format" label="desired output" type="select">\n      <option value="1" selected="true">summary of bin completeness and contamination</option>\n      <option value="2">extended summary of bin statistics (includes GC, genome size, ...)</option>\n      <option value="3">summary of bin quality for increasingly basal lineage-specific marker sets</option>\n      <option value="4">list of marker genes and their counts</option>\n      <option value="5">list of bin id, marker gene id, gene id</option>\n      <option value="6">list of marker genes present multiple times in a bin</option>\n      <option value="7">list of marker genes present multiple times on the same scaffold</option>\n      <option value="8">list indicating position of each marker gene within a bin</option>\n      <option value="9">FASTA file of marker genes identified in each bin</option>\n  </param>"@' |
			# remove out_folder param
			grep -v 'name="out_folder' |
			# replace stdout output
			sed "s#<data format=\"txt\" hidden=\"false\" name=\"default\"/>#<data format=\"$fname\" hidden=\"false\" name=\"output\"/>#" |

			# remove all extension parameters the tool makes them .fna anyway 
			grep -v 'argument="--extension' | 
			# make tabular output default 
			sed 's/\$tab_table/--tab_table/' | 
			# remove threads parameter 
			grep -v 'argument="--threads"' | 
			grep -v 'argument="--pplacer_threads"' | 
			# add tests
			sed 's#</outputs>#</outputs>\n  <tests>\n  <expand macro="tests"/>\n  </tests>#' | 
			# remove --quiet argument
			grep -v '\-\-quiet' | grep -v '\$quiet' > $fname/$fname.xml

		### START tool specific replacements
		### END tool specific replacements
		
			
		### START option specific replacements
		# create bin folder(s) and link inputs
		for i in 1 2 "" ; do
			if [ "`grep "^bin_folder$i$" $fname/$fname.xml`" ]; then
				sed -i -e "s/\(python checkm \)/mkdir bin_folder$i \&\& \n#for \$k, \$f in enumerate(\$bin_folder$i)\n    #if \$f\n        ln -s \"\${f}\" bin_folder$i\/\${k}.fna \&\&\n    #end if\n#end for\n\n\1/" $fname/$fname.xml 
			fi
		done
		
		# add collection and processing for hmmer alignment per bin option (--ali)
		if [ "`grep "\-\-ali" $fname/$fname.xml`" ]; then
			sed -i -e 's#<outputs>#<outputs>\n    <collection name="hmmer_alignment_per_bin" type="list" label="${tool.name} on ${on_string} (HMMER alignments per bin)">\n      <filter>ali</filter>\n      <discover_datasets directory="out_folder/bins/" pattern="(?P\&lt;designation\&gt;.+)\.hmmer\.tree\.ali\.txt" ext="txt" />\n    </collection>#' $fname/$fname.xml

			sed -i -e 's@]]></command>@\#\# link hmmer alignments per bin in one dir to make them discoverable\n#if str($ali) == "--ali":\n\&\& for k in `ls out_folder/bins/`; do\n    if [ -f out_folder/bins/\\$k/hmmer.tree.ali.txt ]; then \n        ln -s \\$k/hmmer.tree.ali.txt out_folder/bins/\\$k.hmmer.tree.ali.txt;\n    fi; \ndone\n#end if]]></command>@' $fname/$fname.xml
		fi
		
		# add collection and processing for nucleotide sequences per bin option (--nt)
		if [ "`grep "\-\-nt" $fname/$fname.xml`" ]; then
			sed -i -e 's#<outputs>#<outputs>\n    <collection name="hmmer_nucleotide_per_bin" type="list" label="${tool.name} on ${on_string} ( nucleotide gene sequences per bin)">\n      <filter>nt</filter>\n      <discover_datasets directory="out_folder/bins/" pattern="(?P\&lt;designation\&gt;.+)\.genes\.fna" ext="fasta" />\n    </collection>#' $fname/$fname.xml

			sed -i -e 's@]]></command>@\#\# link nucleotide sequences per bin in one dir to make them discoverable\n#if str($nt) == "--nt":\n\&\& for k in `ls out_folder/bins/`; do\n    if [ -f out_folder/bins/\\$k/genes.fna ]; then \n        ln -s \\$k/genes.fna out_folder/bins/\\$k.genes.fna;\n    fi; \ndone\n#end if]]></command>@' $fname/$fname.xml
		fi


		if [ "`grep "\-\-alignment_file" $fname/$fname.xml`" ]; then
			sed -i -e 's/#if $alignment_file and $alignment_file is not None:/#if $alignment_file == "true":/' $fname/$fname.xml
			sed -i -e 's/--alignment_file $alignment_file/--alignment_file $alignment_file_output/' $fname/$fname.xml
			sed -i -e 's@<param area="false" argument="--alignment_file" label="produce file showing alignment of multi-copy genes and their AAI identity" name="alignment_file" optional="true" type="text"/>@<param argument="--alignment_file" label="produce file showing alignment of multi-copy genes and their AAI identity" name="alignment_file" type="boolean" truevalue="true" falsevalue="false" checked="false" />@' $fname/$fname.xml
			sed -i -e 's#<outputs>#<outputs>\n    <data  name="alignment_file_output" format="txt" hidden="false" label="${tool.name} on ${on_string} (alignment)"><filter>alignment_file=="true"</filter></data>#' $fname/$fname.xml
		fi



		# tools that have --file: remove input
		if [ "`grep \"\-\-file\" $fname/$fname.xml`" ]; then
			sed -i -e 's# *<param area="false" argument="--file" label="print results to file" name="file" optional="true" type="text" value="stdout"/>##' $fname/$fname.xml
		fi
		# tools that have --output_file get a corresponding output instead of input
		if [ "`grep \"output_file\" $fname/$fname.xml`" ]; then
			sed -i -e 's#<param area="false" label="[^"]\+" name="output_file" type="text"/>##' $fname/$fname.xml
			sed -i -e "s#<outputs>#<outputs>\n    <data  name=\"output_file\" format=\"txt\" hidden=\"false\"/>#" $fname/$fname.xml
		fi
		### END option specific replacements

		# add macros and tokens 
		pname=`echo $fname | sed 's/checkm_//'`
		parents=`grep "add_parser(.$pname[^_]" checkm -A 3 | grep parents | sed "s/parents=\[//; s/,//g; s/\]//; s/_results//g; s/_parser//g"`

		if [ "$parents" ]; then 
			tqap=`echo -e $parents | sed 's/plot_need_qa_results_parser//; s/plot_parser//; s/ //g'`
			if [ "$tqap" ]; then
				parents=`echo $parents" plot" | awk '{for(i=NF; i>0; i--){printf("%s ",$(i))}}'`
			fi
			echo $parents
			for p in $parents; do
				sedexp="s#<command><!\[CDATA\[#<command><![CDATA[\@"$p"_headtoken\@\n#"
				sed -i -e "$sedexp" $fname/$fname.xml
				sedexp="s#python checkm coding_plot#python checkm coding_plot\n\@"$p"_token\@#"
				sed -i -e "$sedexp" $fname/$fname.xml
				sedexp="s#  <inputs>#  <inputs>\n    <expand macro=\""$p"_macro\"/>#"
				sed -i -e "$sedexp" $fname/$fname.xml
				sedexp="s#  </outputs>#    <expand macro=\""$p"_outmacro\"/>\n  </outputs>#"
				sed -i -e "$sedexp" $fname/$fname.xml
				echo "add $p to $fname"
			done
		fi
		# replace call
		sed -i -e 's/python checkm/checkm/' $fname/$fname.xml
	else			# subcommands go to macros
		sedcmd="/<tool id=\"$fname\"/,/<\/tool>/!d"
		tokensedcmd="/<command><!\[CDATA\[python $fname/,/<\/command>/!d"
		# get the part of the xml + make it a single line
		echo "<token name=\"@"$fname"_token@\">" >> tmp.xml
		sed -e "$sedcmd" checkm.xml | 
			sed "$tokensedcmd" | grep -v "command>" |
			awk '{printf("%sENDOFLINEMARKER", $0)}' |
			sed 's/_[0-9]//g' |
			# replace out/plot/bin_folder
			sed 's/#if $\(out_folder[0-9]*\).*$out_folder[0-9]*ENDOFLINEMARKER#end ifENDOFLINEMARKER/\1/' |
			sed 's/#if $\(bin_folder[0-9]*\).*$bin_folder[0-9]*ENDOFLINEMARKER#end ifENDOFLINEMARKER/\1/' |
			sed 's/#if $\(plot_folder[0-9]*\).*$plot_folder[0-9]*ENDOFLINEMARKER#end ifENDOFLINEMARKER/\1/' |
			sed 's/#if $extension.*$extensionENDOFLINEMARKER#end if//' |
			sed 's/\(ENDOFLINEMARKER\)\+/\n/g' >> tmp.xml
		true
		echo "</token>" >> tmp.xml

		echo "<token name=\"@"$fname"_headtoken@\">" >> plot_macros.xml
		if [ "`grep "^bin_folder$" tmp.xml`" ]; then
			echo -e "mkdir bin_folder &amp;&amp; \n#for \$k, \$f in enumerate(\$bin_folder)\n    #if \$f\n        ln -s \"\${f}\" bin_folder\/\${k}.fna &amp;&amp;\n    #end if\n#end for &amp;&amp;\n" >> plot_macros.xml 
		fi
		if [ "`grep "out_folder" tmp.xml`" ]; then
			echo -e "mkdir out_folder &amp;&amp; \n" >> plot_macros.xml 
		fi
		if [ "`grep "^plot_folder$" tmp.xml`" ]; then
			echo -e "mkdir plot_folder &amp;&amp; \n" >> plot_macros.xml 
		fi
		echo "</token>" >> plot_macros.xml

		echo '<xml name="'$fname'_macro">' >> tmp.xml
		sedcmd="/<tool id=\"$fname\"/,/<\/tool>/!d"
		tokensedcmd="/<inputs>/,/<\/inputs>/!d"
		# get the part of the xml + make it a single line
		sed -e "$sedcmd" checkm.xml | 
			sed "$tokensedcmd" | grep -v "inputs>"|
			sed 's/_[0-9]//g' |
			grep -v 'argument="--extension' | 
			sed 's#<param area="false" label="folder containing bins to plot (fasta format)" name="bin_folder\([0-9]*\)" type="text"/>#<param name="bin_folder\1" type="data" label="bins" multiple="true" format="fasta"/>#' |
			# TODO make connection with qa work (ie use extradata of out_folder)
			sed 's#<param area="false" label="folder specified during qa command" name="out_folder" type="text"/>#<param name="out_folder" type="data" label="output of qa command" format="text"/>#' |
			sed 's#<param area="false" label="folder to hold plots" name="plot_folder" type="text"/>##' >> tmp.xml
    		echo '</xml>' >> tmp.xml
		
		# output macros make collection from plot_folder
		echo '<xml name="'$fname'_outmacro">' >> plot_macros.xml
		if [ "`grep "plot_folder" tmp.xml`" ]; then
echo -e '<collection name="plot_folder" type="list" label="${tool.name} on ${on_string} (plots)">\n    <discover_datasets pattern="__name_and_ext__" directory="plot_folder" />\n</collection>' >> plot_macros.xml
		fi
    		echo '</xml>' >> plot_macros.xml
		cat tmp.xml >> plot_macros.xml; rm tmp.xml
	fi
done 

echo "</macros>" >> plot_macros.xml
