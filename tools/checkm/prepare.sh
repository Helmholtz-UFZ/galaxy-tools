#!/bin/bash

function get_parent_parsers () {
	pname=$1
	parents=$(grep "add_parser('$pname[^_]" checkm -A 3 | grep parents | sed "s/\s\+parents=\[\([a-z_, ]\+\)\].*/\1/; s/,//g;")
	if [[ -z "$parents" ]]; then
		parents=$(grep "\s$pname = " checkm -A 3 | grep parents | sed "s/\s\+parents=\[\([a-z_, ]\+\)\].*/\1/; s/,//g;")
		
	fi
	echo -n "$parents "
	for p in $parents
	do
		get_parent_parsers "$p"
	done
}


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

echo "<macros>" > plot_macros.xml
grep "<tool" checkm.xml | cut -d"\"" -f 2 | while IFS= read -r fname
do
	echo "$fname"

	# skip the test command
	if [ "$fname" == "checkm_test" ]; then
		continue
	fi

	if [ $(echo "$fname" | grep "checkm") ]; then 	# real commands go to separate tools

		# create tool dir and macro link
		if [ -d "$fname" ]; then
			rm -rf "${fname:?}"/*
		else
			mkdir "$fname"/
		fi

		for i in macros.xml plot_macros.xml test-data datatypes_conf.xml 
		do
			ln -sf ../$i "$fname"/$i
		done

		# prepare the empty tool specific macro files 
		# and link them in the tool dir (under a common name which can be auto generated)
		touch "macros_$fname.xml"
		ln -sf "../macros_$fname.xml" "$fname/tool-macros.xml"

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
			# fix --threads and --pplacer_threads to GALAXY_SLOTS
			sed 's/#if $threads.*$threadsENDOFLINEMARKER#end ifENDOFLINEMARKER/--threads \\${GALAXY_SLOTS:-1}/g' |
			sed 's/#if $pplacer_threads.*$pplacer_threadsENDOFLINEMARKER#end ifENDOFLINEMARKER/--pplacer_threads \\${GALAXY_SLOTS:-1}/g' |
			# remove extension
 			sed 's/#if $extension.*$extension[0-9]*ENDOFLINEMARKER#end if//g' |
			# replace bin_folder argument
			sed 's/#if $\(bin_folder[0-9]*\)[^#]*$bin_folder[0-9]*ENDOFLINEMARKER#end ifENDOFLINEMARKER/\1/' |
			# replace seq_file, and tree_folder argument 
			sed "s/#if \$\(seq_file\|tree_folder\|marker_file\|analyze_folder\)[^#]*ENDOFLINEMARKER#end ifENDOFLINEMARKER/'\$\1'/g" |
			# replace out_folder by extra_files_path of output data set
			sed "s/#if \$out_folder[^#]*\$out_folderENDOFLINEMARKER#end if/'\$output.extra_files_path'/" |
			sed 's/#if $out_format[^#]*$out_formatENDOFLINEMARKER#end if/--out_format $out_format/' |
			# remove --file / --extension from command
			sed "s/#if \$\(file\|extension\)[^#]*ENDOFLINEMARKER#end if//" |
			# replace --output_file from command
			sed "s/#if \$output_file[^#]*\$output_fileENDOFLINEMARKER#end if/'\$output_file'/" |
                        # replace multi bam input by proper param
			sed 's@ *<repeat min="1" name="repeat" title="repeat_title">ENDOFLINEMARKER *<param area="false" label="BAM files to parse" name="bam_files" type="text"/>ENDOFLINEMARKER *</repeat>@<param name="bam_files" type="data" label="BAM files to parse" multiple="true" format="bam"/>@' |
			sed 's/#set repeat_var = '"'"'\" \"'"'"'.join(\[ str($var.bam_files) for $var in $repeat \])ENDOFLINEMARKER/#for $k, $f in enumerate($bam_file)\n    #if $f\n        \"${f}\"\n    #end if\n#end for/' |
			# rename redirect of stdout 
			sed "s/> \$default/> '\$output'\n/" |
			# reinsert newlines
			sed 's/\(ENDOFLINEMARKER\)\+/\n/g' | 
			# set min and max of floats that have the word percentage in the label
			sed 's/\(percentage.*type="float"\)/\1 min="0.0" max="1.0"/' |
			# fix bin_folder and seq_file params
			sed 's#<param area="false" label="folder containing bins (fasta format)" name="bin_folder\([0-9]*\)" type="text"/>#<param name="bin_folder\1" type="data" label="bins" multiple="true" format="fasta"/>#' |

			# make seq_file, marker_file and analyze_folder a file input (for those tools that have it as output this is fixed later)
			sed 's#<param area="false" label="sequences used to generate bins (fasta format)" name="" type="text"/>#<param name="seq_file" type="data" label="sequences used to generate bins" format="fasta"/>#' |
			sed 's#<param area="false" label="\([^"]\+\)" name="marker_file" type="text"/>#<param name="marker_file" type="data" format="checkm_marker_file" label="\1" />#' | 
			sed 's#<param area="false" label="\([^"]\+\)" name="analyze_folder" type="text"/>#<param name="analyze_folder" type="data" format="checkm_analyze_folder" label="\1" />#' | 
			# make exclude_markers a proper input
			sed 's#<param area="false" argument="--\(exclude_markers\|coverage_file\)" label="\([^"]\+\)" name="\([^"]\+\)" optional="true" type="text"/>#<param argument="--\1" type="data" format="tabular" optional="true" label="\2" />#' | 
			# remove out_folder param
			grep -v 'name="out_folder' |
			# replace stdout output
			sed "s#<data format=\"txt\" hidden=\"false\" name=\"default\"/>##" |

			# remove all extension parameters the tool makes them .fna anyway 
			grep -v 'argument="--extension' | 
			# make tabular output default 
			sed 's/\$tab_table/--tab_table/' |
		        sed 's/<param argument="--tab_table".*//' |
			# remove threads parameter 
			grep -v 'argument="--threads"' | 
			grep -v 'argument="--pplacer_threads"' | 
			# add tests (macro)
			sed 's#</outputs>#</outputs>\n  <tests>\n  <expand macro="tests"/>\n  </tests>#' | 
			# remove any empty lines
			grep -v '^\s*$' |
			# remove --quiet argument
			grep -v '\-\-quiet' | grep -v '\$quiet' > "$fname/$fname.xml"

		### START tool specific replacements
		# tools with analyze_folder output get <data> 
		if [ "$fname" == "checkm_analyze" ]; then
			sed -i -e "s/<outputs>/<outputs>\n    <data name=\"output\" format=\"checkm_analyze_folder\" hidden=\"false\" label=\"\${tool.name} on \${on_string}\"\/>/" "$fname/$fname.xml"
		# tools with tree_folder output get <data> 
		elif [ "$fname" == "checkm_lineage_wf" ]; then
			sed -i -e "s/<outputs>/<outputs>\n    <data name=\"output\" format=\"checkm_qa_folder\" hidden=\"false\" label=\"\${tool.name} on \${on_string}\"\/>/" "$fname/$fname.xml"
		# tools with tree_folder output get <data> 
		elif [ "$fname" == "checkm_tree" ]; then
			sed -i -e "s/<outputs>/<outputs>\n    <data name=\"output\" format=\"checkm_tree_folder\" hidden=\"false\" label=\"\${tool.name} on \${on_string}\"\/>/" "$fname/$fname.xml"
		# fix out_format (make it a select)
		elif [ "$fname" == "checkm_tree_qa" ]; then
			sed -i -e 's#<param argument="--out_format.*#<param argument="--out_format" label="desired output" type="select">\n      <option value="1" selected="true">brief summary of genome tree placement</option>\n      <option value="2">detailed summary of genome tree placement including lineage-specific statistics</option>\n      <option value="3">genome tree in Newick format decorated with IMG genome ids</option>\n      <option value="4">genome tree in Newick format decorated with taxonomy strings</option>\n      <option value="5">multiple sequence alignment of reference genomes and bins</option>\n    </param>#' "$fname/$fname.xml"
			sed -i -e 's#<outputs>#<outputs>\n    <data format="tabular" name="output">\n        <change_format>\n            <when input="out_format" value="3" format="newick" />\n            <when input="out_format" value="4" format="newick" />\n            <when input="out_format" value="5" format="fasta" />\n        </change_format>\n    </data>#' "$fname/$fname.xml"
		elif [ "$fname" == "checkm_qa" ]; then
			# adapt default output
			sed -i -e 's#<param argument="--out_format.*#<param argument="--out_format" label="desired output" type="select">\n      <option value="1" selected="true">summary of bin completeness and contamination</option>\n      <option value="2">extended summary of bin statistics (includes GC, genome size, ...)</option>\n      <option value="3">summary of bin quality for increasingly basal lineage-specific marker sets</option>\n      <option value="4">list of marker genes and their counts</option>\n      <option value="5">list of bin id, marker gene id, gene id</option>\n      <option value="6">list of marker genes present multiple times in a bin</option>\n      <option value="7">list of marker genes present multiple times on the same scaffold</option>\n      <option value="8">list indicating position of each marker gene within a bin</option>\n      <option value="9">FASTA file of marker genes identified in each bin</option>\n    </param>#' "$fname/$fname.xml"
			# add output
			sed -i -e 's#<outputs>#<outputs>\n    <data format="checkm_qa_folder" name="output"/>#' "$fname/$fname.xml"
			sed -i -e "s#\[checkm qa#[checkm qa\\ncp -r '\$analyze_folder.extra_files_path' '\$output.extra_files_path'\&\&#" "$fname/$fname.xml"
			# analyze folder is input and output -> create a copy of the input
			sed -i -e "s#python checkm qa#cp -r '\$analyze_folder.extra_files_path' '\$output.extra_files_path' \&\&\\npython checkm qa#" "$fname/$fname.xml"
			sed -i -e "s#^'\$analyze_folder'\$#'\$output.extra_files_path'#" "$fname/$fname.xml"
		# make taxon list a tsv file
		elif [ "$fname" == "checkm_taxon_list" ]; then
			replacement="sed 's/^\s\+//; s/\s\+$//; s/\s\{2,\}/\t/g; s/^Rank/\# Rank/' | grep -v '\-\-\-' | grep -v '^$'"
			sed -i -e "s#^>#$replacement > #" "$fname/$fname.xml"
			sed -i -e 's#<outputs>#<outputs>\n    <data format="tabular" name="output"/>#' "$fname/$fname.xml"
		fi

		# remove stdout redirection from all plot tools
		if [[ "$fname" =~ ^.*plot$ ]]; then
			sed -i -e "s/> '\$output'//" "$fname/$fname.xml"
		fi
		
		# tools that have marker_file as output get a corresponding output instead of input
		# and link it to .ms
		if [ "$fname" == "checkm_lineage_set" ] || [ "$fname" == "checkm_taxon_set" ]; then
			sed -i -e 's#<param name="marker_file" type="data" format="checkm_marker_file" label="\([^"]\+\)" />##' "$fname/$fname.xml"
			sed -i -e "s#<outputs>#<outputs>\n    <data  name=\"marker_file\" format=\"checkm_marker_file\" hidden=\"false\" from_work_dir=\"marker_file\"/>#" "$fname/$fname.xml"
			sed -i -e "s/> '\$output'//" "$fname/$fname.xml"
		fi

		### END tool specific replacements
		
			
		### START option specific replacements
		# correct tree_folder input
		if [ "$(grep "tree_folder" $fname/$fname.xml)" ]; then
			sed -i -e "s#<param area=\"false\" label=\"folder specified during tree command\" name=\"tree_folder\" type=\"text\"/>#<param area=\"false\" label=\"folder specified during tree command\" name=\"tree_folder\" type=\"data\" format=\"checkm_tree_folder\"/>#" "$fname/$fname.xml"
		        sed -i -e "s/\$tree_folder/\$tree_folder.extra_files_path/" "$fname/$fname.xml"
		fi
# TODO only for those tools that do not use the folder also as output, ie checkm_qa
# 		# correct analyze_folder input
# 		if [ "$(grep "analyze_folder" $fname/$fname.xml)" ]; then
# 			sed -i -e "s#<param area=\"false\" label=\"folder specified during tree command\" name=\"analyze_folder\" type=\"text\"/>#<param area=\"false\" label=\"folder specified during tree command\" name=\"analyze_folder\" type=\"data\" format=\"checkm_analyze_folder\"/>#" "$fname/$fname.xml"
# 		        sed -i -e "s/\$analyze_folder/\$analyze_folder.extra_files_path/" "$fname/$fname.xml"
# 		fi
		# create bin folder(s) and link inputs
		for i in 1 2 "" ; do
			if [ "`grep "^bin_folder$i$" $fname/$fname.xml`" ]; then
				sed -i -e "s/\(python checkm \)/mkdir bin_folder$i \&\& \n#for \$k, \$f in enumerate(\$bin_folder$i)\n    #if \$f\n        ln -s \"\${f}\" bin_folder$i\/\${k}.fna \&\&\n    #end if\n#end for\n\n\1/" "$fname/$fname.xml"
			fi
		done


		if [ "`egrep "\-\-ali[^g]|\-\-nt" $fname/$fname.xml`" ]; then
			# cp extra_files to out_folder (for gathering collections)
			sed -i -e "s/> '\$output'/> '\$output'\n#if str(\$ali) == \"--ali\" or str(\$nt) == \"--nt\":\n\&\&if [ -d '\$output.extra_files_path' ]; then\n cp -r '\$output.extra_files_path' out_folder;\nfi\n#end if\n/" "$fname/$fname.xml"
		fi
		
		# add collection and processing for hmmer alignment per bin option (--ali)
		# - add output collection
		# - add for loop producing links to the files 
		if [ "$(grep "\-\-ali[^g]" $fname/$fname.xml)" ]; then
			grep "\-\-ali[^g]" $fname/$fname.xml
			# checkm tree generates ".hmmer.tree.ali"
			# checkm analyze generates .hmmer\.analzye\.ali
			# needs to be distinguished
			sed -i -e "s#<outputs>#<outputs>\n    <collection name=\"hmmer_alignment_per_bin\" type=\"list\" label=\"\${tool.name} on \${on_string} (HMMER alignments per bin)\">\n      <filter>ali</filter>\n      <discover_datasets directory=\"out_folder/bins/\" pattern=\"hmmer\.(?P\&lt;designation\&gt;.+)\.txt\" ext=\"txt\" />\n    </collection>#" $fname/$fname.xml

			sed -i -e "s@]]></command>@\#\# link hmmer alignments per bin in one dir to make them discoverable\n#if str(\$ali) == \"--ali\":\n\&\& for k in \`ls out_folder/bins/\`; do\n    if [ -f out_folder/bins/\\\\\$k/hmmer.tree.txt ]; then \n        ln -s \\\\\$k/hmmer.tree.txt out_folder/bins/hmmer.tree.\\\\\$k.txt;\n    fi; \n    if [ -f out_folder/bins/\\\\\$k/hmmer.analyze.txt ]; then \n        ln -s \\\\\$k/hmmer.analyze.txt out_folder/bins/hmmer.analyze.\\\\\$k.txt;\n    fi; \ndone\n#end if]]></command>@" "$fname/$fname.xml"
		fi
		
		# add collection and processing for nucleotide sequences per bin option (--nt)
		if [ "`grep "\-\-nt" $fname/$fname.xml`" ]; then
			sed -i -e 's#<outputs>#<outputs>\n    <collection name="hmmer_nucleotide_per_bin" type="list" label="${tool.name} on ${on_string} (nucleotide gene sequences per bin)">\n      <filter>nt</filter>\n      <discover_datasets directory="out_folder/bins/" pattern="(?P\&lt;designation\&gt;.+)\.genes\.fna" ext="fasta" />\n    </collection>#' $fname/$fname.xml

			sed -i -e 's@]]></command>@\#\# link nucleotide sequences per bin in one dir to make them discoverable\n#if str($nt) == "--nt":\n\&\& for k in `ls out_folder/bins/`; do\n    if [ -f out_folder/bins/\\$k/genes.fna ]; then \n        ln -s \\$k/genes.fna out_folder/bins/\\$k.genes.fna;\n    fi; \ndone\n#end if]]></command>@' $fname/$fname.xml
		fi

		# --alignment file
		if [ "`grep "\-\-alignment_file" $fname/$fname.xml`" ]; then
			sed -i -e 's/#if $alignment_file and $alignment_file is not None:/#if $alignment_file == "true":/' $fname/$fname.xml
			sed -i -e 's/--alignment_file $alignment_file/--alignment_file $alignment_file_output/' $fname/$fname.xml
			sed -i -e 's@<param area="false" argument="--alignment_file" label="produce file showing alignment of multi-copy genes and their AAI identity" name="alignment_file" optional="true" type="text"/>@<param argument="--alignment_file" label="produce file showing alignment of multi-copy genes and their AAI identity" name="alignment_file" type="boolean" truevalue="true" falsevalue="false" checked="false" />@' $fname/$fname.xml
			sed -i -e 's#<outputs>#<outputs>\n    <data  name="alignment_file_output" format="txt" hidden="false" label="${tool.name} on ${on_string} (alignment)"><filter>alignment_file</filter></data>#' $fname/$fname.xml
		fi

		# tools that have --file: remove input and parameter
		if [ "`grep \"\-\-file\" $fname/$fname.xml`" ]; then
			sed -i -e 's# *<param area="false" argument="--file" label="print results to file" name="file" optional="true" type="text" value="stdout"/>##' $fname/$fname.xml
		fi
		# tools that have --output_file get a corresponding output instead of input
		if [ "`grep \"output_file\" $fname/$fname.xml`" ]; then
			sed -i -e 's#<param area="false" label="[^"]\+" name="output_file" type="text"/>##' $fname/$fname.xml
			sed -i -e "s#<outputs>#<outputs>\n    <data  name=\"output_file\" format=\"txt\" hidden=\"false\"/>#" $fname/$fname.xml
		fi


		### END option specific replacements

		# add macros and tokens derived from subparsers
		# _headtoken goes before the checkm command
		# _token directy after the checkm command
		# additionally macros are added to input and output	
		pname=$(echo "$fname" | sed 's/checkm_//')
		parents=$(get_parent_parsers "$pname" | sed "s/_results//g; s/_parser//g"| awk '{for(i=NF; i>0; i--){printf("%s ",$(i))}}')
		
		if [ "$parents" ]; then 
			echo "##############   parents "$parents
			for p in $parents; do
				sedexp="s#<command><!\[CDATA\[#<command><![CDATA[\@"$p"_headtoken\@\n#"
				sed -i -e "$sedexp" "$fname/$fname.xml"
				sedexp="s#^\(python checkm $pname\)#\1\n\@"$p"_token\@#"
				sed -i -e "$sedexp" "$fname/$fname.xml"
				sedexp="s#  <inputs>#  <inputs>\n    <expand macro=\""$p"_macro\"/>#"
				sed -i -e "$sedexp" "$fname/$fname.xml"
				sedexp="s#  </outputs>#    <expand macro=\""$p"_outmacro\"/>\n  </outputs>#"
				sed -i -e "$sedexp" "$fname/$fname.xml"
				echo "add $p to $fname"
			done
		fi
		# replace call
		sed -i -e 's/python checkm/checkm/' $fname/$fname.xml
	else			# subcommands go to macros
		sedcmd="/<tool id=\"$fname\"/,/<\/tool>/!d"
		tokensedcmd="/<command><!\[CDATA\[python $fname/,/<\/command>/!d"

		# get the part of the xml containg the command 
		# - do some basic preprocessing and save it temporarily 
		#   for further processing ie generation of head_token 
		echo "<token name=\"@"$fname"_token@\">" >> tmp.xml
		sed -e "$sedcmd" checkm.xml | 
			sed "$tokensedcmd" | grep -v "command>" |
			awk '{printf("%sENDOFLINEMARKER", $0)}' |
			sed 's/_[0-9]//g' |
			# replace out/plot/bin_folder
			sed "s/#if $\(out_folder[0-9]*\).*$out_folder[0-9]*ENDOFLINEMARKER#end if/'\$out_folder.extra_files_path'/" |
			sed 's/#if $\(bin_folder[0-9]*\).*$bin_folder[0-9]*ENDOFLINEMARKER#end if/\1/' |
			sed 's/#if $\(plot_folder[0-9]*\).*$plot_folder[0-9]*ENDOFLINEMARKER#end if/\1/' |
			sed 's/#if $extension.*$extensionENDOFLINEMARKER#end if//' |
			sed 's/\(ENDOFLINEMARKER\)\+/\n/g' >> tmp.xml
                echo "</token>" >> tmp.xml

		# generate head token
		echo "<token name=\"@"$fname"_headtoken@\">" >> plot_macros.xml
		if [ "`grep "^bin_folder$" tmp.xml`" ]; then
			echo -e "mkdir bin_folder &amp;&amp; \n#for \$k, \$f in enumerate(\$bin_folder)\n    #if \$f\n        ln -s \"\${f}\" bin_folder\/\${k}.fna &amp;&amp;\n    #end if\n#end for &amp;&amp;\n" >> plot_macros.xml 
		fi
		if [ "`grep "^plot_folder$" tmp.xml`" ]; then
			echo -e "mkdir plot_folder &amp;&amp; \n" >> plot_macros.xml 
		fi
		echo "</token>" >> plot_macros.xml

		# generate macro
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
			sed 's#<param area="false" label="folder specified during qa command" name="out_folder" type="text"/>#<param name="out_folder" type="data" format="checkm_qa_folder" label="output of qa command" />#' |
			sed 's#<param area="false" label="folder to hold plots" name="plot_folder" type="text"/>##' >> tmp.xml
    		echo '</xml>' >> tmp.xml
		
		# output macros make collection from plot_folder
		echo '<xml name="'$fname'_outmacro">' >> plot_macros.xml
		if [ "`grep "plot_folder" tmp.xml`" ]; then
echo -e '<collection name="plot_folder" type="list" label="${tool.name} on ${on_string} (plots)">\n    <discover_datasets pattern="__name_and_ext__" directory="plot_folder" />\n</collection>' >> plot_macros.xml
		fi
    		echo '</xml>' >> plot_macros.xml
		cat tmp.xml >> plot_macros.xml; rm tmp.xml

		sed -i -e 's@<param name="out_folder" type="data" label="output of qa command" format="text"/>@<param name="out_folder" type="data" format="checkm_qa_folder" label="output of qa command" />@' plot_macros.xml


	fi
done 

echo "</macros>" >> plot_macros.xml
