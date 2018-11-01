import argparse
import datetime
import json
import os
import shutil
import tarfile
import zipfile
try:
    # For Python 3.0 and later
    from urllib.request import Request, urlopen
except ImportError:
    # Fall back to Python 2 imports
    from urllib2 import Request, urlopen

FILE2NAME = {
    "prot_acc2tax-June2018X1.abin.zip":"Protein accession to NCBI-taxonomy (June2018X1)",
    "nucl_acc2tax-June2018.abin.zip":"Nucleotide accession to NCBI-taxonomy (June2018)",
    "acc2interpro-June2018X.abin.zip":"Protein accession to InterPro (June2018X)",
    "acc2eggnog-Oct2016X.abin.zip":"Protein accession to eggNOG (Oct2016X)",
    "acc2seed-May2015XX.abin.zip":"Protein accession to SEED (May2015XX)",
    "acc2kegg-Dec2017X1-ue.abin.zip":"Protein accession to KEGG (Dec2017X1). Only for use with the Ultimate Edition of MEGAN.",
    "SSURef_Nr99_132_tax_silva_to_NCBI_synonyms.map.gz":"SSURef_Nr99_132_tax_silva_to_NCBI_synonyms.map.gz",
    "SSURef_NR99_128_tax_silva_to_NCBI_synonyms.map.gz":"SSURef_NR99_128_tax_silva_to_NCBI_synonyms.map.gz",
    "prot_gi2tax-Aug2016X.bin.zip":"Protein accession to NCBI-taxonomy (Aug2016X)",
    "nucl_gi2tax-Aug2016.bin.zip":"Nucleotide accession to NCBI-taxonomy (Aug2016)",
    "gi2eggnog-June2016X.bin.zip":"Protein accession to InterPro (June2016X)",
    "gi2interpro-June2016X.bin.zip":"Protein accession to eggNOG (June2016X)",
    "gi2seed-May2015X.bin.zip":"Protein accession to SEED (May2015X)",
    "gi2kegg-Aug2016X-ue.bin.zip":"Protein accession to KEGG (Aug2016X). Only for use with the Ultimate Edition of MEGAN."
}

FILE2TYPE = {
    "prot_acc2tax-June2018X1.abin.zip":"acc2tax",
    "nucl_acc2tax-June2018.abin.zip":"acc2tax",
    "acc2interpro-June2018X.abin.zip":"acc2interpro",
    "acc2eggnog-Oct2016X.abin.zip":"acc2eggnog",
    "acc2seed-May2015XX.abin.zip":"acc2seed",
    "acc2kegg-Dec2017X1-ue.abin.zip":"acc2kegg",
    "SSURef_Nr99_132_tax_silva_to_NCBI_synonyms.map.gz":"syn2taxa",
    "SSURef_NR99_128_tax_silva_to_NCBI_synonyms.map.gz":"syn2taxa",
    "prot_gi2tax-Aug2016X.bin.zip":"gi2tax",
    "nucl_gi2tax-Aug2016.bin.zip":"gi2tax",
    "gi2eggnog-June2016X.bin.zip":"gi2eggnog",
    "gi2interpro-June2016X.bin.zip":"gi2interpro",
    "gi2seed-May2015X.bin.zip":"gi2seed-",
    "gi2kegg-Aug2016X-ue.bin.zip":"gi2kegg"
}

def url_download(fname, workdir):
    """
    download http://ab.inf.uni-tuebingen.de/data/software/megan6/download/FNAME
    to workdir
    and unzip zip file (not gz)
    
    return the name of the resulting file 
           ie gz-file of extracted file in zip-file
    """
    file_path = os.path.join(workdir, fname)
    if not os.path.exists(workdir):
        os.makedirs(workdir)
    src = None
    dst = None
    try:
        req = Request("http://ab.inf.uni-tuebingen.de/data/software/megan6/download/"+fname)
        src = urlopen(req)
        with open(file_path, 'wb') as dst:
            while True:
                chunk = src.read(2**10)
                if chunk:
                    dst.write(chunk)
                else:
                    break
    finally:
        if src:
            src.close()
    if zipfile.is_zipfile(file_path):
        fh = zipfile.ZipFile(file_path, 'r')
    else:
        return fname
    fh.extractall(workdir)
    os.remove(file_path)
    unzipped = os.listdir(workdir)
    assert len(unzipped) == 1
    return unzipped[0]

def main(fname, outjson):
    workdir = os.path.join(os.getcwd(), 'megan_tools')
    path = url_download(fname, workdir)

    data_manager_entry = {}
    data_manager_entry['value'] = fname.split(".")[0]
    data_manager_entry['name'] = FILE2NAME[fname]
    data_manager_entry['type'] = FILE2TYPE[fname]
    data_manager_entry['path'] = path

    data_manager_json = dict(data_tables=dict(megan_tools=data_manager_entry))

    params = json.loads(open(outjson).read())
    target_directory = params['output_data'][0]['extra_files_path']
    os.mkdir(target_directory)
    output_path = os.path.abspath(os.path.join(os.getcwd(), 'megan_tools'))
    for filename in os.listdir(workdir):
        shutil.move(os.path.join(output_path, filename), target_directory)
    file(outjson, 'w').write(json.dumps(data_manager_json))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Create data manager json.')
    parser.add_argument('--out', action='store', help='JSON filename')
    parser.add_argument('--file', action='store', help='Download filename')
    args = parser.parse_args()

    main(args.file, args.out)
