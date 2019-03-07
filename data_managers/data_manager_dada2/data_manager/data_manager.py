import argparse
import json
import os
import shutil
import sys
import zipfile
try:
    # For Python 3.0 and later
    from urllib.request import Request, urlopen
except ImportError:
    # Fall back to Python 2 imports
    from urllib2 import Request, urlopen

DEFAULT_TAXLEVELS="Kingdom,Phylum,Class,Order,Family,Genus,Species"

FILE2NAME = {
    "silva132":"Silva version 132",
    "silva128":"Silva version 128",
    "rdp16":"RDP trainset 16",
    "rdp14":"RDP trainset 14",
    "gg13.84":"GreenGenes version 13.8",
}

FILE2TAXURL = {
    "silva132":"https://zenodo.org/record/1172783/files/silva_nr_v132_train_set.fa.gz?download=1",
    "silva128":"https://zenodo.org/record/824551/files/silva_nr_v128_train_set.fa.gz?download=1",
    "rdp16":"https://zenodo.org/record/801828/files/rdp_train_set_16.fa.gz?download=1",
    "rdp14":"https://zenodo.org/record/158955/files/rdp_train_set_14.fa.gz?download=1",
    "gg13.84":"https://zenodo.org/record/158955/files/gg_13_8_train_set_97.fa.gz?download=1",
}

FILE2SPECIESURL = {
    "silva132":"https://zenodo.org/record/1172783/files/silva_species_assignment_v132.fa.gz?download=1",
    "silva128":"https://zenodo.org/record/824551/files/silva_species_assignment_v128.fa.gz?download=1",
    "rdp16":"https://zenodo.org/record/801828/files/rdp_species_assignment_16.fa.gz?download=1",
    "rdp14":"https://zenodo.org/record/158955/files/rdp_species_assignment_14.fa.gz?download=1"
}

FILE2TAXLEVELS = {
}

def url_download(url, fname, workdir):
    """
    download url to workdir/fname
    
    return the path to the resulting file 
    """
    file_path = os.path.join(workdir, fname)
    if not os.path.exists(workdir):
        os.makedirs(workdir)
    src = None
    dst = None
    try:
        req = Request(url)
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
    return fname

def main(dataset, outjson):

    params = json.loads(open(outjson).read())
    target_directory = params['output_data'][0]['extra_files_path']
    os.mkdir(target_directory)
    output_path = os.path.abspath(os.path.join(os.getcwd(), 'dada2'))

    workdir = os.path.join(os.getcwd(), 'dada2') 
    path = url_download( FILE2TAXURL[dataset], dataset+".taxonomy", workdir)

    data_manager_json = {"data_tables":{}}
    data_manager_entry = {}
    data_manager_entry['value'] = dataset
    data_manager_entry['name'] = FILE2NAME[dataset]
    data_manager_entry['path'] = dataset+".taxonomy"
    data_manager_entry['taxlevels'] = FILE2TAXLEVELS.get(dataset, DEFAULT_TAXLEVELS)
    data_manager_json["data_tables"]["dada2_taxonomy"] = data_manager_entry


    if FILE2SPECIESURL.get(dataset, False ):
        path = url_download( FILE2SPECIESURL[dataset], dataset+".species", workdir)
    
        data_manager_entry = {}
        data_manager_entry['value'] = dataset
        data_manager_entry['name'] = FILE2NAME[dataset]
        data_manager_entry['path'] = dataset+".species"
        data_manager_json["data_tables"]["dada2_species"] = data_manager_entry
    
    for filename in os.listdir(workdir):
        shutil.move(os.path.join(output_path, filename), target_directory)

    sys.stderr.write("JSON %s" %json.dumps(data_manager_json))
    file(outjson, 'w').write(json.dumps(data_manager_json))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Create data manager json.')
    parser.add_argument('--out', action='store', help='JSON filename')
    parser.add_argument('--dataset', action='store', help='Download data set name')
    args = parser.parse_args()

    main(args.dataset, args.out)
