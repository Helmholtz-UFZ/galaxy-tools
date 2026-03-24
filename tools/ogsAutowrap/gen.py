import argparse
import re
import sys
import json

import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
import shlex
from typing import Any, Dict, List, Optional, Tuple 

from galaxyxml.tool import Tool
from galaxyxml.tool.parameters import (
    BooleanParam,
    DataParam,
    DiscoverDatasets,
    Expand,
    FloatParam,
    Inputs,
    IntegerParam,
    OutputCollection,
    OutputData,
    Outputs,
    SelectParam,
    Tests,
    TextParam,
)

# --- CONFIGURATION (ONLINE) ---
GITLAB_BASE_URL = "https://gitlab.opengeosys.org/ogs/ogs/-"
RAW_URL_ROOT = f"{GITLAB_BASE_URL}/raw/master"
API_URL_ROOT = "https://gitlab.opengeosys.org/api/v4/projects/ogs%2Fogs/repository/tree"
UTILS_PATH = "Applications/Utils"
OUTPUT_DIR = Path(".")
REPO_B_RAW = "https://gitlab.opengeosys.org/kristofkessler/ogs/-/raw/ebd40a71bacd951b90b64e2e42fb8d11528bde39"
REPO_B_API = "https://gitlab.opengeosys.org/api/v4/projects/kristofkessler%2Fogs/repository/tree"
REPO_B_DATA_PATH = "Tests/Data"

# Tools with broken executable commands
EXCLUDED_TOOLS = [
    "netcdfconverter", "binarytopvtu", "ogsfileconverter", 
    "raster2pointcloud", "verticalslicefromlayers", 
    "convertshptogli", "mesh2shape"
]

TCLAP_PATTERN_STD = re.compile(
    r"TCLAP::(?P<arg_type>(?:Value|Switch|Multi)Arg)\s*"
    r"(?:<(?P<cpp_type>.*?)>)?\s*(?P<tclap_var_name>\w+)\s*"
    r"[\({]\s*(?P<all_args>.*?)\s*[\)}];",
    re.DOTALL
)

TCLAP_PATTERN_UNLABELED = re.compile(
    r"TCLAP::(?P<arg_type>Unlabeled(?:Value|Multi)Arg)\s*"
    r"(?:<(?P<cpp_type>.*?)>)?\s*(?P<tclap_var_name>\w+)\s*"
    r"[\({]\s*(?P<all_args>.*?)\s*[\)}];",
    re.DOTALL
)
FILE_EXTENSION_PATTERN = re.compile(r"\((.*?)\)")
MIN_MAX_PATTERN = re.compile(r"\((min|max)\s*=\s*([^)]+)\)")


import json

def fetch_url_content(url: str) -> str:
    """Lädt den Textinhalt einer URL herunter."""
    try:
        with urllib.request.urlopen(url, timeout=10) as response:
            return response.read().decode('utf-8', errors='ignore')
    except:
        return ""

def get_gitlab_files(path: str) -> List[str]:
    """Listet ALLE .cpp Dateien im Online-Ordner auf (mit Paging für Vollständigkeit)."""
    files = []
    page = 1
    while True:
        api_url = f"{API_URL_ROOT}?path={path}&recursive=true&per_page=100&page={page}"
        try:
            with urllib.request.urlopen(api_url) as response:
                data = json.loads(response.read().decode())
                if not data:
                    break
                for item in data:
                    if item['type'] == 'blob' and item['path'].endswith('.cpp'):
                        files.append(item['path'])
                page += 1
        except Exception as e:
            eprint(f"Fehler bei API-Abfrage Seite {page}: {e}")
            break
    return files


def get_repo_b_file_index() -> Dict[str, str]:
    index = {}
    try:
        url = f"{REPO_B_API}?path={REPO_B_DATA_PATH}&ref=ebd40a71bacd951b90b64e2e42fb8d11528bde39&per_page=100"
        with urllib.request.urlopen(url) as resp:
            items = json.loads(resp.read().decode())
            folders = [i['path'] for i in items if i['type'] == 'tree']
    except: return {}

    eprint(f"Scanning {len(folders)} subfolders in Repo B...")
    for folder in folders:
        page = 1
        while True:
            url = f"{REPO_B_API}?path={folder}&recursive=true&per_page=100&page={page}&ref=ebd40a71bacd951b90b64e2e42fb8d11528bde39"
            try:
                with urllib.request.urlopen(url) as resp:
                    data = json.loads(resp.read().decode())
                    if not data: break
                    for item in data:
                        if item['type'] == 'blob':
                            index[item['path'].split('/')[-1]] = item['path']
                    page += 1
            except: break
    eprint(f"-> Index built: {len(index)} files found in Repo B.")
    return index


def get_ogs_ftype(extensions: List[str]) -> str:
    """Mapping for Galaxy file types (including custom OGS types)"""
    if not extensions: 
        return 'vtkxml'
    
    ext = extensions[0].lower().lstrip('.')

    if ext == 'sg': return 'gocad.sg'
    if ext == 'fem': return 'feflow.fem'
    if ext == 'asc': return 'raster.asc'
    
    if ext in ['vtu', 'vtk', 'pvtu', 'pvd']: 
        return 'vtkxml'
    
    if ext in ['prj', 'xml', 'gml', 'ts', 'gli']: 
        return 'xml'
    
    if ext == 'nc': return 'netcdf'

    if ext in ['plt', 'tin', 'mesh', 'bin', 'smesh']:
        return 'txt'

    return ext


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def sanitize_name(name: str) -> str:
    return re.sub(r'[^a-zA-Z0-9_]+', '_', name)


def url_exists(url: str) -> bool:
    try:
        req = urllib.request.Request(url, method='HEAD')
        with urllib.request.urlopen(req, timeout=5) as response:
            return response.status == 200
    except:
        return False


def resolve_values_constraint(constraint_ptr: str, search_space: str) -> List[str]:
    var_name = constraint_ptr.lstrip('&')
    vc_pattern = re.compile(
        r"TCLAP::ValuesConstraint<.*?>\s+" + re.escape(var_name) + r"\s*[\({]\s*(\w+)\s*[\)}]", 
        re.DOTALL
    )
    vc_match = vc_pattern.search(search_space)
    if not vc_match: return []

    vector_var_name = vc_match.group(1)
    options = []

    vec_init_pattern = re.compile(
        r"std::vector<.*?>\s+" + re.escape(vector_var_name) + r"\s*(?:=)?\s*[({]?\s*\{(.*?)\}\s*[)}]?;", 
        re.DOTALL
    )
    vec_match = vec_init_pattern.search(search_space)
    if vec_match:
        content = vec_match.group(1)
        string_options = re.findall(r'"(.*?)"', content)
        if string_options:
            options.extend(string_options)
        else:
            numeric_options = [item.strip() for item in content.split(',') if item.strip()]
            options.extend(numeric_options)

    push_pattern = re.compile(
        re.escape(vector_var_name) + r"\.(?:emplace_back|push_back)\s*\(\s*([^)]+)\s*\)\s*;",
        re.MULTILINE
    )
    push_matches = push_pattern.findall(search_space)
    if push_matches:
        for val in push_matches:
            clean_val = val.strip().strip('"')
            options.append(clean_val)

    seen = set()
    return [x for x in options if not (x in seen or seen.add(x))]


def discover_tools() -> List[Dict[str, Any]]:
    source_files = get_gitlab_files(UTILS_PATH)
    tools_dict: Dict[str, Dict[str, Any]] = {}
    eprint(f"Searching {len(source_files)} remote .cpp files...")

    for file_path in source_files:
        path_obj = Path(file_path)
        
        raw_url = f"{RAW_URL_ROOT}/{file_path}"
        content = fetch_url_content(raw_url)
        
        all_matches = list(TCLAP_PATTERN_STD.finditer(content)) + \
            list(TCLAP_PATTERN_UNLABELED.finditer(content))

        if not all_matches:
            continue

        if path_obj.name == 'main.cpp':
            tool_name = path_obj.parent.name
        else:
            tool_name = path_obj.stem
        
        if tool_name.lower() in ["main", "utils"]:
            continue

        if tool_name not in tools_dict:
            tools_dict[tool_name] = {"name": tool_name, "parameters": []}

        for match in all_matches:
            param_data = match.groupdict()
            param_data['is_unlabeled'] = 'Unlabeled' in param_data.get('arg_type', '')
            param_data['full_source_code'] = content
            param_data['match_start_pos'] = match.start()
            tools_dict[tool_name]["parameters"].append(param_data)

    all_tools_data = list(tools_dict.values())
    eprint(f"-> Found {len(all_tools_data)} tools online.")
    return sorted(all_tools_data, key=lambda x: x['name'])


def process_parameters(tclap_params: List[Dict[str, Any]]) -> Tuple[List[object], Dict[str, str]]:
    galaxy_inputs = []
    output_command_map = {}
    output_idx = 1

    if tclap_params and 'writeMeshToFile' in tclap_params[0].get('full_source_code', ''):
        has_tclap_output = any("output" in p.get('all_args', '').lower() or "BASE_FILENAME_OUTPUT" in p.get('all_args', '') for p in tclap_params)
        if not has_tclap_output:
            output_command_map["VIRTUAL_no_flag"] = {
                'filename': 'new_', 
                'format': 'vtkxml',
                'type': 'BASE_FILENAME'
            }

    for param_info in tclap_params:
        if param_info.get('tclap_var_name') == "log_level_arg": continue
        all_args_str = param_info.get('all_args', '')
        if not all_args_str: continue

        args = re.split(r',(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)', all_args_str)
        args = [arg.strip() for arg in args]
        is_unlabeled = param_info.get('is_unlabeled', False)

        short_flag, long_flag, help_text_raw = "", "", ""
        if not is_unlabeled:
            if len(args) > 0: short_flag = args[0].strip('"')
            if len(args) > 1: long_flag = args[1].strip('"')
            if len(args) > 2: help_text_raw = args[2]
        else:
            if len(args) > 0: long_flag = args[0].strip('"')
            if len(args) > 1: help_text_raw = args[1]
            if not long_flag: long_flag = param_info.get('tclap_var_name', f"arg_{output_idx}")

        if not long_flag: continue
        help_parts = re.findall(r'"(.*?)"', help_text_raw, re.DOTALL)
        help_text = ' '.join(part.strip() for part in help_parts).strip()
        var_name = sanitize_name(long_flag)

        # OUTPUT LOGIC
        is_output_help = help_text.lower().startswith("output") or "directory name and output base" in help_text.lower()
        
        if is_output_help or "BASE_FILENAME_OUTPUT" in all_args_str:
            format_match = FILE_EXTENSION_PATTERN.search(help_text)
            primary_ext = "vtu"
            if format_match:
                primary_ext = format_match.group(1).split('|')[0].strip().lstrip('.')
            
            file_format = get_ogs_ftype([primary_ext])
            disk_ext = "vtu" if file_format == "vtkxml" else primary_ext
            
            is_base_filename_output = "BASE_FILENAME_OUTPUT" in all_args_str or "base name" in help_text.lower()

            output_command_map[long_flag] = {
                'filename': f"output_{output_idx}.{disk_ext}",
                'format': file_format,
                'short_flag': short_flag,
                'type': 'BASE_FILENAME' if is_base_filename_output else 'FIXED_FILE'
            }
            output_idx += 1
            continue

        # INPUT & PARAMETER LOGIC
        param = None
        constraint_ptr = ""
        if len(args) >= 5:
            for potential_ptr in args[4:]:
                ptr_stripped = potential_ptr.strip()
                if ptr_stripped and not ptr_stripped.startswith('"') and not ptr_stripped[0].isdigit():
                    constraint_ptr = ptr_stripped
                    break

        if constraint_ptr:
            options_list = resolve_values_constraint(constraint_ptr, param_info.get('full_source_code', ''))
            if options_list:
                opts_dict = {opt: opt for opt in options_list}
                is_multi = "MultiArg" in param_info.get('arg_type', '')
                param = SelectParam(
                    name=var_name, 
                    label=var_name.replace('_', ' '), 
                    help=help_text, 
                    options=opts_dict,
                    optional=True,
                    multiple=is_multi
                )
                param.options_dict = opts_dict
            if options_list:
                opts_dict = {opt: opt for opt in options_list}
                param = SelectParam(
                    name=var_name, 
                    label=var_name.replace('_', ' '), 
                    help=help_text, 
                    options=opts_dict,
                    optional=False
                )
                param.options_dict = opts_dict

        elif help_text.startswith("Input") or "filenames" in var_name or "INPUT_FILE_LIST" in all_args_str:
            format_match = FILE_EXTENSION_PATTERN.search(help_text)
            all_exts = [e.strip().lstrip('.') for e in format_match.group(1).split('|')] if format_match else []
            is_pvd = "pvd" in help_text.lower() or "pvd" in all_exts
            primary_ext = "pvd" if is_pvd else (all_exts[0] if all_exts else "vtu")
            galaxy_type = get_ogs_ftype([primary_ext])
            is_file_list = "INPUT_FILE_LIST" in all_args_str
            is_collection = ("MultiArg" in param_info.get('arg_type', '') or "filenames" in var_name or is_file_list)
            is_optional = (len(args) > 3 and args[3].lower() == "false")

            param = DataParam(name=var_name, label=var_name.replace('_', ' '), help=help_text, 
                             format=galaxy_type, optional=is_optional)
            param.is_data_collection = is_collection 
            param.is_collection = is_collection
            param.ogs_ext = primary_ext
            param.is_pvd = is_pvd
            param.is_file_list = is_file_list

            if is_pvd:
                pvd_data = DataParam(name=f"{var_name}_pvd_data", label=f"{var_name} PVD Data Elements", 
                                    help="VTU Member Collection", format="vtkxml", optional=True)
                pvd_data.is_pvd_element = True
                pvd_data.is_data_collection = True 
                pvd_data.is_collection = True
                galaxy_inputs.append(pvd_data)

        elif 'Switch' in param_info.get('arg_type', ''):
            param = BooleanParam(name=var_name, label=var_name.replace('_', ' '), help=help_text, 
                                 truevalue=f"--{long_flag}", falsevalue="", checked=False)

        else:
            cpp_type = param_info.get('cpp_type', '').lower()
            if "int" in cpp_type or "size_t" in cpp_type: p_class = IntegerParam
            elif "float" in cpp_type or "double" in cpp_type: p_class = FloatParam
            else: p_class = TextParam
            param = p_class(name=var_name, label=var_name.replace('_', ' '), help=help_text, optional=True)

        if param:
            param.original_long_flag = long_flag
            param.original_short_flag = short_flag
            param.is_unlabeled = is_unlabeled
            galaxy_inputs.append(param)

    return galaxy_inputs, output_command_map

def generate_tools():
    OUTPUT_DIR.mkdir(exist_ok=True)
    all_tools_data = discover_tools()
    if not all_tools_data:
        eprint("No tools with TCLAP definitions found. Aborting.")
        return

    generated_count = 0
    for tool_data in all_tools_data:
        tool_name = tool_data['name']
        if tool_name.lower() in EXCLUDED_TOOLS:
            eprint(f"--> Skipping excluded tool: {tool_name}")
            continue
        eprint(f"Generating wrapper for: {tool_name}...")
        try:
            galaxy_inputs, output_command_map = process_parameters(tool_data['parameters'])

            # 1. EXECUTABLE NAMING
            current_exe = tool_name
            if tool_name.upper() == "PVTU2VTU": current_exe = "pvtu2vtu"
            elif tool_name[0].isupper() and tool_name[1:].islower(): current_exe = tool_name[0].lower() + tool_name[1:]

            m_fixes = {
                "PVTU2VTU": "pvtu2vtu", 
                "FEFLOW2OGS": "feflow2ogs",
                "MergeMeshToBulkMesh": "mergeMeshToBulkMesh",
                "PartitionMesh": "partmesh"
            }

            executable_name = m_fixes.get(tool_name, current_exe)

            command_parts = []
            flag_parts = []
            unlabeled_parts = []

            # 2. SYMLINKS & ARGUMENT MAPPING
            for param in galaxy_inputs:
                is_repeat = getattr(param, 'is_repeat', False)
                is_unlabeled = getattr(param, 'is_unlabeled', False)
                
                flag = getattr(param, 'original_long_flag', param.name)

                is_pvd_element = getattr(param, 'is_pvd_element', False)

                if isinstance(param, DataParam):
                    is_file_list = getattr(param, 'is_file_list', False)
                    is_coll = getattr(param, 'is_data_collection', False)
                    
                    if getattr(param, 'is_pvd_element', False):
                        command_parts.append(f"  #for $item in ${param.name}\n    ln -sf '$item' '$item.element_identifier';\n  #end for")
                        continue
                    if is_file_list:
                        list_file = f"{param.name}_list.txt"
                        command_parts.append(f"touch {list_file};")
                        command_parts.append(f"#for $item in ${param.name}\n  ln -sf '$item' '$item.element_identifier';\n  echo '$item.element_identifier' >> {list_file};\n#end for")
                        flag_parts.append(f"    --{flag} {list_file}")
                        continue
                    if is_coll:
                        command_parts.append(f"#for $item in ${param.name}\nln -sf '$item' '$item.element_identifier';\n#end for")
                        loop_str = f"#for $item in ${param.name}\n'$item.element_identifier'\n#end for"
                        if is_unlabeled: unlabeled_parts.append(f"    --\n{loop_str}")
                        else: flag_parts.append(f"    --{flag}\n{loop_str}")
                    else:
                        command_parts.append(f"ln -sf '${param.name}' '${param.name}.element_identifier';")
                        arg_val = f"'${param.name}.element_identifier'"
                        if is_unlabeled: unlabeled_parts.append(f"    {arg_val}")
                        else: flag_parts.append(f"    --{flag} {arg_val}")
                elif isinstance(param, BooleanParam):
                    flag_parts.append(f"    ${param.name}")
                elif isinstance(param, (TextParam, IntegerParam, FloatParam, SelectParam)):
                    if is_unlabeled:
                        unlabeled_parts.append(f"    '${param.name}'")
                    else:
                        flag_parts.append(f"    --{flag} '${param.name}'")

            # 3. OUTPUT FLAGS
            for flag, info in output_command_map.items():
                if flag == "VIRTUAL_no_flag":
                    continue
                if info.get('type') == 'BASE_FILENAME':
                    if "directory" in flag.lower():
                        flag_parts.append(f"    --{flag} 'new_output'")
                    else:
                        flag_parts.append(f"    --{flag} 'new_'")
                else:
                    flag_parts.append(f"    --{flag} {info['filename']}")

            final_exec_line = [executable_name]
            final_exec_line.extend(flag_parts)
            final_exec_line.extend(unlabeled_parts)
            command_parts.extend(final_exec_line)
            if not output_command_map:
                command_parts[-1] += " > '$stdout_log'"
            command_str = "\n".join(command_parts)

            # 4. Tool object
            tool = Tool(
                name=f"OGS: {tool_name}",
                id=f"ogs_{tool_name.lower()}",
                version="@TOOL_VERSION@+galaxy@VERSION_SUFFIX@",
                description=f"Galaxy wrapper for the OGS utility '{tool_name}'.",
                executable=executable_name,
                macros=["macros.xml", "test_macros.xml"],
                profile="22.01",
                version_command=f"{executable_name} --version",
                command_override=[command_str]
            )

            inputs_tag = tool.inputs = Inputs()
            for param in galaxy_inputs:
                inputs_tag.append(param)

            if output_command_map:
                outputs_tag = tool.outputs = Outputs()
                uses_base_filename = any(info.get('type') == 'BASE_FILENAME' for info in output_command_map.values())
               
                if uses_base_filename:
                    pattern = r"(?P<designation>.*)\.vtu" if "VIRTUAL_no_flag" in output_command_map else r"(?P<designation>new_.*)"
                    first_out_info = next(info for info in output_command_map.values() if info.get('type') == 'BASE_FILENAME')
                    target_fmt = first_out_info.get('format', 'vtkxml')
                    collection = OutputCollection(name="tool_outputs", type="list", label=f"Outputs from {tool_name}")
                    collection.append(DiscoverDatasets(pattern=pattern, format=target_fmt, visible=True))
                    outputs_tag.append(collection)
                else:
                    single_file_outputs = [v for v in output_command_map.values() if v.get('type') == 'FIXED_FILE']
                    if len(single_file_outputs) == 1 and len(output_command_map) == 1:
                        flag, info = list(output_command_map.items())[0]
                        outputs_tag.append(OutputData(name=sanitize_name(f"output_{tool_name}"), format=info['format'], from_work_dir=info['filename'], label=f"Output from {tool_name}"))
                    else:
                        collection = OutputCollection(name="tool_outputs", type="list", label=f"Outputs from {tool_name}")
                        collection.append(DiscoverDatasets(pattern=r"output_.*\.(vtu|msh|asc|gml|xml)", format="data", visible=True))
                        outputs_tag.append(collection)
            else:
                outputs_tag = tool.outputs = Outputs()
                outputs_tag.append(OutputData(name="stdout_log", format="txt", label=f"Output Log from {tool_name}"))

            tests_section = Tests()
            tests_section.append(Expand(macro=f"{tool_name.lower()}_test"))
            tool.tests = tests_section
            tool.help = (f"This tool runs the **{tool_name}** utility from the OpenGeoSys suite.")

            # --- 5. XML
            raw_xml_string = tool.export()
            tool_xml_root = ET.fromstring(raw_xml_string)
            inputs_node = tool_xml_root.find("inputs")

            if inputs_node is not None:
                for param in galaxy_inputs:
                    if getattr(param, 'is_data_collection', False):
                        p_node = inputs_node.find(f"param[@name='{param.name}']")
                        if p_node is not None:
                            p_node.set("type", "data_collection")
                            p_node.set("collection_type", "list")
                            if "multiple" in p_node.attrib: 
                                del p_node.attrib["multiple"]

            output_file_path = OUTPUT_DIR / f"{tool_name}.xml"
            xml_str = ET.tostring(tool_xml_root, encoding='unicode')

            def version_cdata_rewrite(match):
                return f"<version_command><![CDATA[{match.group(1).strip()}]]></version_command>"
            xml_str = re.sub(r"<version_command>(.*?)</version_command>", version_cdata_rewrite, xml_str)

            def command_cdata_rewrite(match):
                content = match.group(1).strip().replace('&lt;', '<').replace('&gt;', '>').replace('&amp;', '&')
                return f"<command><![CDATA[\n{content}\n]]></command>"
            xml_str = re.sub(r"<command.*?>(.*?)</command>", command_cdata_rewrite, xml_str, flags=re.DOTALL)

            with open(output_file_path, 'w', encoding='utf-8') as f:
                f.write('<?xml version="1.0" encoding="UTF-8"?>\n' + xml_str)
            generated_count += 1 

        except Exception as e:
            eprint(f"!! ERROR while processing '{tool_name}': {e}")
            import traceback
            traceback.print_exc(file=sys.stderr)

    eprint(f"\nFinished. {generated_count} tool wrappers created.")


def parse_diff_data(diff_str: str, base_url: str, workdir: str, input_files: List[str]) -> List[Dict[str, str]]:
    diff_files = []
    seen_generated = set()
    valid_exts = ('.vtu', '.gml', '.bin', '.asc', '.pvtu', '.msh', '.smesh', '.xdmf', '.prj', '.xml', '.png', '.geo')

    clean_lines = [line.split('#')[0].strip() for line in diff_str.strip().split('\n')]
    tokens = (" ".join(clean_lines)).split()
    
    i = 0
    while i < len(tokens):
        t1 = tokens[i]
        if any(t1.lower().endswith(ext) for ext in valid_exts):
            if i + 1 < len(tokens) and any(tokens[i+1].lower().endswith(ext) for ext in valid_exts):
                t2 = tokens[i+1]

                if t2 not in input_files and t2 not in seen_generated:
                    ref_url = f"{base_url}/{workdir}/{t1}".replace('<PATH>', workdir) if workdir else f"{base_url}/{t1}"
                    diff_files.append({
                        "reference": ref_url,
                        "generated": t2,
                        "ftype": t2.split('.')[-1]
                    })
                    seen_generated.add(t2)
                i += 2
                continue
        i += 1
    return diff_files

def get_dummy_value(param, tool_name, all_params=None):
    URL_AREHS_TEST = "https://gitlab.opengeosys.org/kristofkessler/ogs/-/raw/ebd40a71bacd951b90b64e2e42fb8d11528bde39/Tests/Data/Utils/VoxelGridFromLayers/AREHS_test.vtu"
    URL_AREHS_FAULT = "https://gitlab.opengeosys.org/kristofkessler/ogs/-/raw/ebd40a71bacd951b90b64e2e42fb8d11528bde39/Tests/Data/Utils/VoxelGridFromLayers/AREHS_fault.vtu"
    URL_PVD_MAIN = "https://gitlab.opengeosys.org/ogs/ogs/-/raw/master/Tests/Data/HydroMechanics/IdealGas/flow_pressure_boundary/flow_pressure_boundary.pvd"
    URL_VTK_TEST = "https://gitlab.opengeosys.org/ogs/ogs/-/raw/master/Tests/Data/Utils/VoxelGridFromLayers/AREHS_Layer17.vtu"

    special_tool_files = {
        "ComputeNodeAreasFromSurfaceMesh": "computeNodeAreasFromSurfaceMesh_test_data",
    }
    if isinstance(param, DataParam):
        ext = getattr(param, 'ogs_ext', 'vtu').lower()
        if tool_name in special_tool_files:
            return f"{special_tool_files[tool_name]}.{ext}"
        if getattr(param, 'is_pvd', False):
            return URL_PVD_MAIN
        if (param.name == "fault" or "fault" in param.label.lower()) and ext in ['vtu', 'vtk', 'msh']:
            return URL_AREHS_FAULT
        if ext in ['vtu', 'msh']:
            return URL_AREHS_TEST
        if ext in ['vtk']:
            return URL_VTK_TEST
        return f"test.{ext}"

    if isinstance(param, SelectParam):
        opts = getattr(param, 'options_dict', {})
        return list(opts.keys())[0] if opts else "value"
    if isinstance(param, (IntegerParam, FloatParam)):
        return "1" if isinstance(param, IntegerParam) else "1.0"
    if isinstance(param, BooleanParam):
        return "true"
    return "dummy_text"


def generate_tests():
    eprint("--- Generating Final Unified Test Macros ---")
    tests_cmake_url = f"{RAW_URL_ROOT}/{UTILS_PATH}/Tests.cmake"
    RAW_GITLAB_TEST_DATA_URL = "https://gitlab.opengeosys.org/ogs/ogs/-/raw/master/Tests/Data"
    RAW_GITLAB_PROJECT_ROOT_URL = "https://gitlab.opengeosys.org/ogs/ogs/-/raw/master"
    repo_b_index = get_repo_b_file_index()

    all_tools_data = discover_tools()
    tools_map_lower = {
        tool['name'].lower(): tool 
        for tool in all_tools_data 
        if tool['name'].lower() not in EXCLUDED_TOOLS
    }
    tool_tests_accumulator = {tool_name: [] for tool_name in tools_map_lower.keys()}
    
    cmake_content = fetch_url_content(tests_cmake_url)
    if not cmake_content:
        eprint("ERROR: Could not fetch Tests.cmake from GitLab.")
        return
    addtest_pattern = re.compile(r"AddTest\s*\((.*?)\s*\)(?!\s*PROPERTIES)", re.DOTALL)

    STOP_KEYWORDS = ["TESTER", "RUNTIME", "PROPERTIES", "DEPENDS", "REQUIREMENTS", "DIFF_DATA", "WRAPPER", "WRAPPER_ARGS"]

    for match in addtest_pattern.finditer(cmake_content):
        test_block = match.group(1)
        
        exec_match = re.search(r"EXECUTABLE\s+([^\s\)]+)", test_block)
        matched_tool = None
        if exec_match and exec_match.group(1).lower() in tools_map_lower:
            matched_tool = exec_match.group(1).lower()
        else:
            for t in tools_map_lower.keys():
                if re.search(r'(?:[\s/_-]|^)' + re.escape(t) + r'(?:[\s/_-]|$)', test_block.lower()):
                    matched_tool = t
                    break
        
        if not matched_tool or matched_tool.lower() in EXCLUDED_TOOLS:
            continue

        tool_data = tools_map_lower[matched_tool]
        g_inputs_temp, _ = process_parameters(tool_data['parameters'])
        has_complex_input = any(getattr(p, 'is_pvd', False) or getattr(p, 'is_file_list', False) for p in g_inputs_temp)
        
        if has_complex_input:
            eprint(f"   -> Marking {matched_tool} for Dummy-Test (Complex PVD/List Input).")
            continue

        if tool_tests_accumulator[matched_tool]:
            continue
        galaxy_inputs, output_map = process_parameters(tool_data['parameters'])
        all_inputs_map = {p.name: p for p in galaxy_inputs}

        flag_map = {}
        unlabeled_p = next((p for p in galaxy_inputs if getattr(p, 'is_unlabeled', False)), None)
        for p in galaxy_inputs:
            if hasattr(p, 'original_long_flag') and p.original_long_flag:
                flag_map[f"--{p.original_long_flag}"] = p
            if hasattr(p, 'original_short_flag') and p.original_short_flag:
                flag_map[f"-{p.original_short_flag}"] = p

        path_match = re.search(r"PATH\s+([^\s\)]+)", test_block)
        p_rep = path_match.group(1).strip() if path_match else ""
        wd_match = re.search(r"WORKING_DIRECTORY\s+\$\{Data_SOURCE_DIR\}/([^\s\)]+)", test_block)
        wd_sub = wd_match.group(1).replace("<PATH>", p_rep).strip() if wd_match else ""

        # ARGUMENT PARSING
        params_in_test = {}
        input_files_in_this_test = []
        args_match = re.search(r"EXECUTABLE_ARGS\s+(.*)", test_block, re.DOTALL)
        if args_match:
            raw_args = args_match.group(1).split(')')[0].strip().replace('\n', ' ')
            norm_args = raw_args.replace(" -- ", " --SEP-- ")
            try: args_list = shlex.split(norm_args)
            except: args_list = norm_args.split()

            i = 0
            while i < len(args_list):
                arg = args_list[i]
                if arg.upper() in STOP_KEYWORDS:
                    break

                if arg in flag_map:
                    p = flag_map[arg]
                    i += 1
                    if isinstance(p, BooleanParam):
                        params_in_test[p.name] = "true"
                    else:
                        collected_vals = []
                        while i < len(args_list) and not args_list[i].startswith('-') and args_list[i].upper() not in STOP_KEYWORDS:
                            val = args_list[i].replace("<PATH>", p_rep).replace("${Data_BINARY_DIR}/", "").split('/')[-1]
                            if val: collected_vals.append(val)
                            i += 1
                        if collected_vals:
                            params_in_test[p.name] = ",".join(collected_vals)
                        continue

                elif unlabeled_p and not arg.startswith('-'):
                    current_unlabeled = []
                    if unlabeled_p.name in params_in_test:
                        current_unlabeled = params_in_test[unlabeled_p.name].split(',')

                    while i < len(args_list) and not args_list[i].startswith('-') and args_list[i].upper() not in STOP_KEYWORDS:
                        val = args_list[i].replace("<PATH>", p_rep).split('/')[-1]
                        if any(val.lower().endswith(ext) for ext in ['.pvd', '.vtu', '.msh', '.gml', '.asc', '.nc', '.xyz']):
                            current_unlabeled.append(val)
                        i += 1
                    if current_unlabeled:
                        params_in_test[unlabeled_p.name] = ",".join(current_unlabeled)
                    continue
                
                i += 1

        # XML generation
        test_case = ET.Element("test")
        test_is_valid = True
        test_params_xml = []

        for p_name, p_val in params_in_test.items():
            p_obj = all_inputs_map.get(p_name)
            if not p_obj: continue
            
            val_clean = str(p_val).replace("<PATH>", p_rep).replace("${Data_BINARY_DIR}/", "").replace("${Data_SOURCE_DIR}/", "").lstrip("/")
            
            # PVD
            if getattr(p_obj, 'is_pvd', False):
                pvd_members = [v for v in re.findall(r"([^\s/]+\.vt[ui])", test_block) if not v.endswith(".pvd")]
                if pvd_members:
                    p_pvd_name = f"{p_name}_pvd_data"
                    coll_param = ET.Element("param", {"name": p_pvd_name})
                    coll_wrapper = ET.SubElement(coll_param, "collection", {"type": "list"})
                    
                    for v in sorted(set(pvd_members)):
                        url = f"{RAW_GITLAB_TEST_DATA_URL}/{wd_sub}/{v}" if wd_sub else f"{RAW_GITLAB_PROJECT_ROOT_URL}/{v}"
                        ET.SubElement(coll_wrapper, "element", {
                            "name": v,
                            "value": v,
                            "location": url,
                            "ftype": "vtkxml"
                        })
                    test_params_xml.append(coll_param)

            # Collections / INPUT_FILE_LIST
            if getattr(p_obj, 'is_data_collection', False):
                files_to_process = val_clean.split(',')
                coll_param = ET.Element("param", {"name": p_name})
                coll_wrapper = ET.SubElement(coll_param, "collection", {"type": "list"})
    
                for f_path in files_to_process:
                    f_name = f_path.split('/')[-1]
                    url = f"{RAW_GITLAB_TEST_DATA_URL}/{wd_sub}/{f_name}" if wd_sub else f"{RAW_GITLAB_PROJECT_ROOT_URL}/{f_name}"
        
                    if not url_exists(url):
                        search_name = f_name if "." in f_name else f"{f_name}.vtu"
                        if search_name in repo_b_index:
                            url = f"{REPO_B_RAW}/{repo_b_index[search_name]}"
                            f_name = search_name
                        else:
                            test_is_valid = False
                            break

                    ET.SubElement(coll_wrapper, "element", {
                        "name": f_name,
                        "value": f_name,
                        "location": url,
                        "ftype": p_obj.format.split(',')[0]
                    })
                
                if test_is_valid:
                    test_params_xml.append(coll_param)

            # 3. single parameter
            else:
                attrs = {"name": p_name}
                if isinstance(p_obj, DataParam):
                    f_name = val_clean.split('/')[-1]
                    url = f"{RAW_GITLAB_TEST_DATA_URL}/{wd_sub}/{f_name}" if wd_sub else f"{RAW_GITLAB_PROJECT_ROOT_URL}/{f_name}"
                    if not url_exists(url):
                        search_name = f_name if "." in f_name else f"{f_name}.vtu"
                        if search_name in repo_b_index:
                            url = f"{REPO_B_RAW}/{repo_b_index[search_name]}"
                            f_name = search_name
                        else:
                            test_is_valid = False
                            break
                    attrs.update({"value": f_name, "location": url, "ftype": p_obj.format.split(',')[0]})
                else:
                    is_base_filename_param = any(sanitize_name(flag) == p_name and info.get('type') == 'BASE_FILENAME' for flag, info in output_map.items())
                    attrs["value"] = "new_" if is_base_filename_param else val_clean.split('/')[-1]
                
                test_params_xml.append(ET.Element("param", attrs))
            
            if not test_is_valid: break

        if not test_is_valid:
            continue

        for elem in test_params_xml:
            val = elem.get("value")
            if val and val.startswith("${") and val.endswith("}"):
                p_name = elem.get("name")
                p_obj = all_inputs_map.get(p_name)
                if p_obj:
                    new_val = get_dummy_value(p_obj, matched_tool, all_params=galaxy_inputs)
                    elem.set("value", str(new_val))

        for xml_elem in test_params_xml:
            test_case.append(xml_elem)

        # --- OUTPUT LOGIK ---
        dm = re.search(r"DIFF_DATA\s+(.*?)(?=\s*\)|$)", test_block, re.DOTALL)
        output_added = False

        if dm:
            diff_files = parse_diff_data(dm.group(1).strip(), RAW_GITLAB_TEST_DATA_URL, wd_sub, input_files_in_this_test)
            if diff_files:
                diff_files.sort(key=lambda x: x["generated"]) 
                if len(output_map) > 1 or any(info.get('type') == 'BASE_FILENAME' for info in output_map.values()):
                    coll = ET.SubElement(test_case, "output_collection", {"name": "tool_outputs", "type": "list"})
                    for df in diff_files:
                        e = ET.SubElement(coll, "element", {"name": df["generated"]})
                        ET.SubElement(ET.SubElement(e, "assert_contents"), "has_size", {"min": "100"})
                    output_added = True
                elif len(diff_files) == 1:
                    out_name = sanitize_name(f"output_{matched_tool}")
                    out_elem = ET.SubElement(test_case, "output", {"name": out_name})
                    ET.SubElement(ET.SubElement(out_elem, "assert_contents"), "has_size", {"min": "100"})
                    output_added = True

        # Fallback
        if not output_added and output_map:
            if len(output_map) > 1 or any(info.get('type') == 'BASE_FILENAME' for info in output_map.values()):
                ET.SubElement(test_case, "output_collection", {"name": "tool_outputs", "type": "list"})
            else:
                out_name = sanitize_name(f"output_{matched_tool}")
                out_elem = ET.SubElement(test_case, "output", {"name": out_name})
                ET.SubElement(ET.SubElement(out_elem, "assert_contents"), "has_size", {"min": "1"})

        tool_tests_accumulator[matched_tool].append(test_case)

    # Build Macros
    macros_root = ET.Element("macros")
    for t_name, cases in tool_tests_accumulator.items():
        macro_xml = ET.SubElement(macros_root, "xml", {"name": f"{t_name}_test"})
        
        if not cases:
            fallback_test = ET.SubElement(macro_xml, "test")
            tool_data = tools_map_lower[t_name]
            g_inputs, g_outputs = process_parameters(tool_data['parameters'])
            
            for p in g_inputs:
                is_data_coll = getattr(p, 'is_data_collection', False)
                
                if is_data_coll:
                    if getattr(p, 'is_pvd_element', False):
                        urls = [
                            "https://gitlab.opengeosys.org/ogs/ogs/-/raw/master/Tests/Data/HydroMechanics/IdealGas/flow_pressure_boundary/flow_pressure_boundary_ts_0_t_0.000000.vtu",
                            "https://gitlab.opengeosys.org/ogs/ogs/-/raw/master/Tests/Data/HydroMechanics/IdealGas/flow_pressure_boundary/flow_pressure_boundary_ts_100_t_4000.000000.vtu"
                        ]
                    elif getattr(p, 'is_file_list', False) or p.name == "raster_list":
                        urls = [
                            "https://gitlab.opengeosys.org/ogs/ogs/-/raw/master/Tests/Data/Utils/VoxelGridFromLayers/AREHS_Layer0.vtu",
                            "https://gitlab.opengeosys.org/ogs/ogs/-/raw/master/Tests/Data/Utils/VoxelGridFromLayers/AREHS_Layer15.vtu"
                        ]
                    else:
                        urls = [get_dummy_value(p, t_name, all_params=g_inputs)]

                    coll_node = ET.SubElement(fallback_test, "param", {"name": p.name})
                    coll_wrapper = ET.SubElement(coll_node, "collection", {"type": "list"})
                    for url in urls:
                        filename = url.split('/')[-1]
                        ET.SubElement(coll_wrapper, "element", {
                            "name": filename,
                            "value": filename,
                            "location": url,
                            "ftype": "vtkxml"
                        })
                    continue

                # Standard parameter
                is_mandatory = (getattr(p, 'optional', True) is False)
                if is_mandatory or isinstance(p, DataParam) or isinstance(p, SelectParam):
                    val_str = get_dummy_value(p, t_name, all_params=g_inputs)
                    is_ext = str(val_str).startswith("http")
                    clean_val = val_str.split('/')[-1] if is_ext else val_str
                    attrs = {"name": p.name, "value": clean_val}
                    if isinstance(p, DataParam):
                        attrs["ftype"] = p.format.split(',')[0]
                        if is_ext: attrs["location"] = val_str
                    ET.SubElement(fallback_test, "param", attrs)
            
            # Outputs
            if g_outputs:
                if len(g_outputs) > 1 or any(info.get('type') == 'BASE_FILENAME' for info in g_outputs.values()):
                    ET.SubElement(fallback_test, "output_collection", {"name": "tool_outputs", "type": "list"})
                else:
                    out_n = sanitize_name(f"output_{t_name}")
                    out_tag = ET.SubElement(fallback_test, "output", {"name": out_n})
                    ET.SubElement(ET.SubElement(out_tag, "assert_contents"), "has_size", {"min": "1"})

            else:
                out_tag = ET.SubElement(fallback_test, "output", {"name": "stdout_log"})
                ac = ET.SubElement(out_tag, "assert_contents")
                ET.SubElement(ac, "has_size", {"min": "1"})
        else:
            for case in cases:
                macro_xml.append(case)

    tree = ET.ElementTree(macros_root)
    ET.indent(tree, space="    ")
    with open("test_macros.xml", "wb") as f:
        f.write(b'<?xml version="1.0" encoding="UTF-8"?>\n')
        tree.write(f, encoding="utf-8", xml_declaration=False)


def main():
    parser = argparse.ArgumentParser(description="Galaxy XML Wrapper Generator for OGS Utilities")
    parser.add_argument(
        '--generate-tools',
        action='store_true',
        help='Generate individual tool XML wrappers (default action).'
    )
    parser.add_argument(
        '--generate-tests',
        action='store_true',
        help='Generate a single test_macros.xml file for all tools.'
    )

    args = parser.parse_args()

    if args.generate_tests:
        generate_tests()
    else:
        generate_tools()


if __name__ == "__main__":
    main()