import argparse
import re
import sys

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

# --- CONFIGURATION ---
OGS_REPO_PATH = Path("/home/stehling/gitProjects/ogs")
UTILS_SUBDIR = "Applications/Utils"
OUTPUT_DIR = Path(".")

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


def get_ogs_ftype(extensions: List[str]) -> str:
    """Mapping für Galaxy. Für Tests nutzen wir bekannte Basistypen."""
    if not extensions: return 'data'
    if isinstance(extensions, str): extensions = [extensions.split('.')[-1]]
    exts = [e.lower().lstrip('.') for e in extensions]

    if any(e in ['vtu', 'vtk', 'pvtu', 'pvd'] for e in exts): return 'vtkxml'
    if any(e in ['prj', 'xml', 'gml', 'ts', 'sg', 'fem', 'msh', 'asc'] for e in exts): return 'xml'
    
    return 'data'


def eprint(*args, **kwargs):
    """Schreibt in stderr."""
    print(*args, file=sys.stderr, **kwargs)


def sanitize_name(name: str) -> str:
    """Bereinigt einen String, um ein gültiger Galaxy-Parametername zu sein."""
    return re.sub(r'[^a-zA-Z0-9_]+', '_', name)


def resolve_variable_value(var_name: str, search_space: str) -> Optional[str]:
    """
    FINALE, KORRIGIERTE VERSION: Sucht ausschließlich nach Deklarationen
    (Typ + Name) und ignoriert spätere Zuweisungen. Löst das Klammer-Problem
    korrekt mit einem Zähl-Algorithmus.
    """
    declaration_start_pattern = re.compile(
        r"((?:const|constexpr|static)\s+)*[\w\:\.\<\> ]+\s+" + re.escape(var_name) + r"\b"
    )

    for match in declaration_start_pattern.finditer(search_space):
        end_of_declaration = match.end()
        remaining_code = search_space[end_of_declaration:].lstrip()

        if remaining_code.startswith('='):
            val_match = re.search(r"=\s*([^;]*);", remaining_code)
            if val_match:
                value = val_match.group(1).strip()
                if value.endswith(('f', 'u', 'l', 'L')):
                    value = value[:-1]
                return value.strip('"')

        elif remaining_code.startswith('('):
            balance = 1
            start_pos = end_of_declaration + remaining_code.find('(')

            for i, char in enumerate(search_space[start_pos + 1:]):
                if char == '(':
                    balance += 1
                elif char == ')':
                    balance -= 1

                if balance == 0:
                    end_pos = start_pos + 1 + i
                    value = search_space[start_pos + 1: end_pos].strip()
                    if value.endswith(('f', 'u', 'l', 'L')):
                        value = value[:-1]
                    return value.strip('"')

        elif remaining_code.startswith('{'):
            val_match = re.search(r"\{\s*([^}]*)\};", remaining_code)
            if val_match:
                value = val_match.group(1).strip()
                if value.endswith(('f', 'u', 'l', 'L')):
                    value = value[:-1]
                return value.strip('"')

    return None


def resolve_values_constraint(var_name: str, search_space: str) -> List[str]:
    """
    Löst einen TCLAP::ValuesConstraint in eine Liste von Optionswerten auf.
    Kann jetzt sowohl Vektoren mit Initialisierungslisten als auch solche,
    die mit emplace_back gefüllt werden, verarbeiten.
    """
    vc_pattern = re.compile(
        r"TCLAP::ValuesConstraint<\s*[\w\:]+\s*>\s+" + re.escape(var_name) + r"\s*[\({]\s*(\w+)\s*[\)}]", re.DOTALL
    )
    vc_match = vc_pattern.search(search_space)
    if not vc_match:
        return []

    vector_var_name = vc_match.group(1)

    vec_pattern = re.compile(
        r"std::vector<\s*[\w\:\.<> ]+\s*>\s+" + re.escape(vector_var_name) + r"\s*\{(.*?)\};", re.DOTALL
    )
    vec_match = vec_pattern.search(search_space)

    if vec_match:
        values_str = vec_match.group(1)
        options = []
        if '"' in values_str:
            options = re.findall(r'"(.*?)"', values_str)
        else:
            cleaned_str = re.split(r'//', values_str)[0].replace('\n', '')
            options = [item.strip() for item in cleaned_str.split(',') if item.strip()]
        if options:
            return options

    emplace_back_pattern = re.compile(
        re.escape(vector_var_name) + r"\.emplace_back\s*\(\s*\"(.*?)\"\s*\);"
    )

    options = emplace_back_pattern.findall(search_space)
    if options:
        return options

    return []


def discover_tools() -> List[Dict[str, Any]]:
    base_path = OGS_REPO_PATH / UTILS_SUBDIR
    if not base_path.is_dir():
        eprint(f"ERROR: The subdirectory '{base_path}' does not exist.")
        return []

    source_files = list(base_path.glob("**/*.cpp"))
    tools_dict: Dict[str, Dict[str, Any]] = {}
    eprint(f"Searching {len(source_files)} potential .cpp files...")

    for file_path in source_files:
        content = file_path.read_text(encoding='utf-8', errors='ignore')
        all_matches = list(TCLAP_PATTERN_STD.finditer(content)) + \
            list(TCLAP_PATTERN_UNLABELED.finditer(content))

        if not all_matches:
            continue

        tool_name = file_path.parent.name if file_path.name == 'main.cpp' else file_path.stem
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
    eprint(f"-> Found and processed {len(all_tools_data)} tools with TCLAP definitions.")
    return sorted(all_tools_data, key=lambda x: x['name'])


def process_parameters(tclap_params: List[Dict[str, Any]]) -> Tuple[List[object], Dict[str, str]]:
    galaxy_inputs = []
    output_command_map = {}
    output_idx = 1

    replacements = {
        "-1*std::numeric_limits<double>::max()": "-1.7976931348623157E+308",
        "-1 * std::numeric_limits<double>::max()": "-1.7976931348623157E+308",
        "-std::numeric_limits<double>::max()": "-1.7976931348623157E+308",
        "std::numeric_limits<double>::max()": "1.7976931348623157E+308",
        "std::numeric_limits<double>::lowest()": "-1.7976931348623157E+308",
        "std::numeric_limits<double>::min()": "2.2250738585072014e-308",
        "std::numeric_limits<double>::epsilon()": "2.220446049250313e-16",
        "std::numeric_limits<float>::max()": "3.4028235E+38",
        "std::numeric_limits<float>::lowest()": "-3.4028235E+38",
        "std::numeric_limits<float>::min()": "1.17549435E-38",
        "std::numeric_limits<int>::max()": "2147483647",
        "std::numeric_limits<int>::min()": "-2147483648",
        "std::numeric_limits<int>::lowest()": "-2147483648",
        "std::numeric_limits<unsigned int>::max()": "4294967295",
        "std::numeric_limits<std::size_t>::max()": "18446744073709551615",
        "std::numeric_limits<size_t>::max()": "18446744073709551615",
        "std::size_t(-1)": "18446744073709551615"
    }


    for param_info in tclap_params:
        if param_info.get('tclap_var_name') == "log_level_arg":
            continue
        all_args_str = param_info.get('all_args', '')
        if not all_args_str:
            continue

        args = re.split(r',(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)', all_args_str)
        args = [arg.strip() for arg in args]
        is_unlabeled = param_info.get('is_unlabeled', False)

        short_flag, long_flag, help_text_raw, remaining_args_list = "", "", "", []
        if not is_unlabeled:
            if len(args) > 0: short_flag = args[0].strip('"')
            if len(args) > 1: long_flag = args[1].strip('"')
            if len(args) > 2: help_text_raw = args[2]
            if len(args) > 3: remaining_args_list = args[3:]
        else:
            if len(args) > 0: long_flag = args[0].strip('"')
            if len(args) > 1: help_text_raw = args[1]
            if len(args) > 2: remaining_args_list = args[2:]

        # --- NEU: UNLABELED DETECTION FIX ---
        # Falls TCLAP uns sagt, es ist unlabeled, ODER falls wir schlicht 
        # kein long_flag gefunden haben, behandeln wir es als Positionsargument.
        if not long_flag or is_unlabeled:
            is_unlabeled = True
            # Falls kein long_flag da ist (UnlabeledValueArg), nutzen wir den Variablennamen 
            # aus dem C++ Code als Identifikator für Galaxy
            if not long_flag:
                long_flag = param_info.get('tclap_var_name', f"arg_{output_idx}")
        
        # Abort nur, wenn wir wirklich gar nichts zum Identifizieren haben
        if not long_flag:
            continue
        # ------------------------------------

        help_parts = re.findall(r'"(.*?)"', help_text_raw, re.DOTALL)
        help_text = ' '.join(part.strip() for part in help_parts)
        help_text = re.sub(r'(the\s+)?name\s+of\s+', '', help_text, flags=re.IGNORECASE)
        help_text = re.sub(r'\s{2,}', ' ', help_text).strip()
        var_name = sanitize_name(long_flag)

        IGNORED_PARAMS = ["write_merged_geometries"]
        if var_name in IGNORED_PARAMS:
            continue

        cleaned_rem_args_parts = [p.strip() for p in remaining_args_list if p.strip()]
        final_tclap_arg = cleaned_rem_args_parts[-1].strip("'\"") if cleaned_rem_args_parts else ""

        # --- KORRIGIERTES OUTPUT processing ---
        if help_text.startswith("Output"):
            is_base_filename_output = "BASE_FILENAME_OUTPUT" in final_tclap_arg
            output_type = 'file' if final_tclap_arg == 'OUTPUT_FILE' else 'collection_member'

            # 1. Extrahiere alle Endungen aus dem Hilfetext (z.B. .vtu, .asc)
            detected_exts = []
            format_match = FILE_EXTENSION_PATTERN.search(help_text)
            if format_match:
                detected_exts = [ext.strip().lstrip('.') for ext in format_match.group(1).split('|')]

            # 2. Galaxy-interner Datentyp
            file_format = get_ogs_ftype(detected_exts)

            # 3. PHYSIKALISCHE ENDUNG für die Festplatte (WICHTIG für OGS!)
            # Wir nehmen die erste erkannte Endung aus dem Code, sonst Fallback
            if detected_exts:
                disk_ext = detected_exts[0].lower()
            else:
                disk_ext = file_format.split('.')[-1]
            
            # Korrektur: vtkxml muss auf der Platte immer vtu sein
            if disk_ext == 'vtkxml': disk_ext = 'vtu'

            output_command_map[long_flag] = {
                'filename': f"output_{output_idx}.{disk_ext}", # Exakter Name für OGS
                'format': file_format,
                'is_base_filename': is_base_filename_output,
                'type': output_type,
                'short_flag': short_flag
            }
            output_idx += 1
            continue

        param = None
        if help_text.startswith("Input"):
            is_base_filename = "BASE_FILENAME_INPUT" in final_tclap_arg
            is_file_list = "INPUT_FILE_LIST" in final_tclap_arg
            is_multiple = "PATH" in final_tclap_arg or is_file_list or is_base_filename

            detected_exts = []
            format_match = FILE_EXTENSION_PATTERN.search(help_text)
            if format_match:
                detected_exts = [ext.strip().lstrip('.') for ext in format_match.group(1).split('|')]

            galaxy_format = get_ogs_ftype(detected_exts)

            attrs = {
                "name": var_name,
                "label": var_name.replace('_', ' '),
                "help": help_text,
                "optional": 'true' not in cleaned_rem_args_parts,
                "format": galaxy_format,
                "multiple": is_multiple
            }
            param = DataParam(**attrs)
            param.tclap_marker = final_tclap_arg

        else:
            is_required_in_tclap = cleaned_rem_args_parts and cleaned_rem_args_parts[0] == 'true'
            attrs = {"name": var_name, "label": var_name.replace('_', ' '), "help": help_text, "optional": not is_required_in_tclap}
            full_arg_text = f"{long_flag} {help_text} {' '.join(remaining_args_list)}"

            min_max_search = MIN_MAX_PATTERN.findall(full_arg_text)
            if min_max_search:
                for key, val in min_max_search:
                    attrs[key] = val.strip()

            arg_type = param_info.get('arg_type', '')
            if 'Switch' in arg_type:
                attrs.pop('optional', None)
                attrs.update(truevalue=f"--{long_flag}", falsevalue="", checked=False)
                param = BooleanParam(**attrs)
            else:
                last_arg = cleaned_rem_args_parts[-1].strip() if cleaned_rem_args_parts else ""
                if last_arg.startswith('&'):
                    code_before = param_info['full_source_code'][:param_info['match_start_pos']]
                    constraint_var_name = last_arg.lstrip('&')
                    options = resolve_values_constraint(constraint_var_name, code_before)
                    if options:
                        attrs.pop('optional', None)
                        param = SelectParam(options=dict([(o, o) for o in options]), **attrs)

                if param is None:
                    default_val_candidate = None
                    if cleaned_rem_args_parts:
                        is_req = cleaned_rem_args_parts[0] in ['true', 'false']
                        if is_req and len(cleaned_rem_args_parts) > 1:
                            default_val_candidate = cleaned_rem_args_parts[1]
                        elif not is_req:
                            default_val_candidate = cleaned_rem_args_parts[0]

                    if default_val_candidate is not None:
                        resolved_value = ""
                        if default_val_candidate.strip().startswith('&'):
                            var_to_resolve = default_val_candidate.strip().lstrip('&')
                            code_before = param_info['full_source_code'][:param_info['match_start_pos']]
                            value_from_code = resolve_variable_value(var_to_resolve, code_before)
                            if value_from_code:
                                resolved_value = value_from_code
                        else:
                            resolved_value = default_val_candidate.strip().strip("'\"")

                        if resolved_value in replacements:
                            resolved_value = replacements[resolved_value]
                        if resolved_value:
                            attrs['value'] = resolved_value

                    cpp_type = param_info.get('cpp_type', '')
                    param_class = TextParam
                    if "int" in cpp_type or "size_t" in cpp_type:
                        param_class = IntegerParam
                        if ('unsigned' in cpp_type or 'size_t' in cpp_type) and 'min' not in attrs:
                            attrs['min'] = "0"
                    elif "float" in cpp_type or "double" in cpp_type:
                        param_class = FloatParam
                    param = param_class(**attrs)

        if param:
            param.original_long_flag = long_flag
            param.original_short_flag = short_flag
            param.is_unlabeled = is_unlabeled
            galaxy_inputs.append(param)

    return galaxy_inputs, output_command_map


def generate_tools():
    if not OGS_REPO_PATH.is_dir():
        eprint(f"ERROR: The OGS repository directory '{OGS_REPO_PATH}' was not found.")
        return

    OUTPUT_DIR.mkdir(exist_ok=True)
    all_tools_data = discover_tools()
    if not all_tools_data:
        eprint("No tools with TCLAP definitions found. Aborting.")
        return

    generated_count = 0
    for tool_data in all_tools_data:
        tool_name = tool_data['name']
        eprint(f"Generating wrapper for: {tool_name}...")
        try:
            galaxy_inputs, output_command_map = process_parameters(tool_data['parameters'])
            eprint(f"-> Found {len(output_command_map)} output definitions for this tool.")

            # --- ROBUSTER COMMAND BLOCK ---
            command_parts = []
            
            # 1. Symlinks (Jeder Link ein eigener Bash-Befehl in einer Zeile)
            for param in galaxy_inputs:
                if isinstance(param, DataParam):
                    p_var = f'${param.name}'
                    target = f"${{{p_var}.element_identifier}}"
                    # Wir nutzen hier keine Cheetah-IFs, sondern Bash-Logik (Semicolon am Ende!)
                    link_cmd = f"if [ \"{p_var}\" != \"None\" ] && [ ! -e '{target}' ]; then ln -s '{p_var}' '{target}'; fi;"
                    command_parts.append(link_cmd)

            executable_name = tool_name
            if tool_name.upper() == "PVTU2VTU":
                executable_name = "pvtu2vtu"
            elif tool_name[0].isupper() and tool_name[1:].islower():
                # Macht aus 'ReviseMesh' -> 'reviseMesh' (typisch OGS)
                executable_name = tool_name[0].lower() + tool_name[1:]
            
            # Falls du merkst, dass noch mehr Tools falsch geschrieben sind, 
            # kannst du hier eine Mapping-Liste einfügen:
            manual_fixes = {
                "PVTU2VTU": "pvtu2vtu",
                "Mesh2Raster": "Mesh2Raster", # Manche bleiben MixedCase
                "GMSH2OGS": "GMSH2OGS"
            }
            executable_name = manual_fixes.get(tool_name, executable_name)

            command_parts.append(executable_name)

            # 3. Argumente (Cheetah-Direktiven in EIGENEN Zeilen)
            for param in galaxy_inputs:
                p_var = f'${param.name}'
                flag = getattr(param, 'original_long_flag', param.name)
                is_unlabeled = getattr(param, 'is_unlabeled', False)
                is_opt = str(getattr(param, 'optional', False)).lower() == 'true'
                
                if isinstance(param, DataParam):
                    # WICHTIG: Kein extra $ vor der Variablen hier
                    arg_val = f"--{flag} '${param.name}.element_identifier'" if not is_unlabeled else f"'${param.name}.element_identifier'"
                elif isinstance(param, BooleanParam):
                    arg_val = f"{p_var}"
                else:
                    arg_val = f"--{flag} '{p_var}'" if not is_unlabeled else f"'{p_var}'"
                
                if is_opt:
                    # Umbruch VOR und NACH dem Argument für Cheetah-Sicherheit
                    command_parts.append(f"#if str({p_var}).strip() != 'None' and str({p_var}).strip() != '':")
                    command_parts.append(f"    {arg_val}")
                    command_parts.append("#end if")
                else:
                    command_parts.append(f"    {arg_val}")

            # 4. Outputs
            for flag, info in output_command_map.items():
                command_parts.append(f"    --{flag} {info['filename']}")

            command_str = "\n".join(command_parts)


            tool = Tool(
                name=f"OGS: {tool_name}",
                id=f"ogs_{tool_name.lower()}",
                version="@TOOL_VERSION@+galaxy@VERSION_SUFFIX@",
                description=f"Galaxy wrapper for the OGS utility '{tool_name}'.",
                executable=tool_name,
                macros=["macros.xml", "test_macros.xml"],
                profile="22.01",
                version_command=f"{tool_name} --version",
                command_override=[command_str]
            )

            inputs_tag = tool.inputs = Inputs()
            for param in galaxy_inputs:
                inputs_tag.append(param)

            if output_command_map:
                outputs_tag = tool.outputs = Outputs()
                sorted_outputs = sorted(output_command_map.items(), key=lambda item: item[0])
                single_file_outputs = [v for v in output_command_map.values() if v.get('type') == 'file']

                if len(single_file_outputs) == 1 and len(output_command_map) == 1:
                    flag, file_info = sorted_outputs[0]
                    output_label = f"Output file from {tool_name}"
                    output_name = sanitize_name(f"output_{tool_name}")
                    
                    # FIX: Wir nutzen hier wieder den expliziten Typ (file_info['format'])
                    output_param = OutputData(
                        name=output_name,
                        format=file_info['format'], 
                        from_work_dir=file_info['filename'],
                        label=output_label
                    )
                    outputs_tag.append(output_param)
                else:
                    collection = OutputCollection(name="tool_outputs", type="list", label=f"Outputs from {tool_name}")
                    # Bei Collections nutzen wir format="data" als Basis, 
                    # Galaxy wird die Typen innerhalb der Collection selbst sniffen
                    collection.append(DiscoverDatasets(pattern=r"output_.*\.(vtu|msh|asc|gml|xml|txt|png)", format="data", visible=True))
                    outputs_tag.append(collection)

            tests_section = Tests()
            macro_name = f"{tool_name.lower()}_test"
            tests_section.append(Expand(macro=macro_name))
            tool.tests = tests_section

            tool.help = (f"This tool runs the **{tool_name}** utility from the OpenGeoSys suite.")

            xml_string = tool.export()

            output_file_path = OUTPUT_DIR / f"{tool_name}.xml"
            with open(output_file_path, 'w', encoding='utf-8') as f:
                f.write(xml_string)
            eprint(f"-> Successfully saved: {output_file_path}")
            generated_count += 1
        except Exception as e:
            eprint(f"!! ERROR while processing '{tool_name}': {e}")
            import traceback
            traceback.print_exc(file=sys.stderr)

    eprint(f"\nFinished. {generated_count} of {len(all_tools_data)} tool wrappers were created in the '{OUTPUT_DIR}' directory.")


def parse_diff_data(diff_str: str, base_url: str, workdir: str) -> List[Dict[str, str]]:
    """Extrahiert Referenz- und Output-Dateien aus einem DIFF_DATA Block."""
    diff_files = []
    file_pattern = re.compile(r"[\w\-\./<>\$]+\.(?:vtu|gml|bin|asc|pvtu|msh|smesh|geo|xdmf|grd|xyz|ts|inp|json)")

    for line in diff_str.strip().split('\n'):
        line = line.strip()
        found_files = file_pattern.findall(line)
        if not found_files:
            continue

        if len(found_files) == 1:
            ref_url = f"{base_url}/{workdir}/{found_files[0]}"
            diff_files.append({"reference": ref_url, "generated": found_files[0], "ftype": found_files[0].split('.')[-1]})

        elif len(found_files) >= 2:
            ref_url = f"{base_url}/{workdir}/{found_files[0]}"
            diff_files.append({"reference": ref_url, "generated": found_files[1], "ftype": found_files[1].split('.')[-1]})

    return diff_files


def generate_tests():
    """
    Generiert individuelle, benannte Test-Makros für jedes Tool.
    Verwendet das 'location'-Attribut für Remote-Dateien.
    """
    eprint("--- Generating Test Macros from Tests.cmake with GitLab URLs ---")

    CMAKE_TESTS_FILE = Path("/home/stehling/gitProjects/ogs/Applications/Utils/Tests.cmake")
    RAW_GITLAB_TEST_DATA_URL = "https://gitlab.opengeosys.org/ogs/ogs/-/raw/master/Tests/Data"
    RAW_GITLAB_PROJECT_ROOT_URL = "https://gitlab.opengeosys.org/ogs/ogs/-/raw/master"

    if not CMAKE_TESTS_FILE.is_file():
        eprint(f"FEHLER: Die Testdefinitionsdatei '{CMAKE_TESTS_FILE}' wurde nicht gefunden.")
        return

    all_tools_data = discover_tools()
    if not all_tools_data:
        eprint("Keine Tools gefunden, Tests können nicht generiert werden.")
        return

    tools_map_lower = {tool['name'].lower(): tool for tool in all_tools_data}
    wrapper_tool_names_lower = list(tools_map_lower.keys())

    macros_root = ET.Element("macros")

    cmake_content = CMAKE_TESTS_FILE.read_text(encoding='utf-8', errors='ignore')
    addtest_pattern = re.compile(r"AddTest\s*\((.*?)\)", re.DOTALL)

    processed_tools_lower = set()
    test_case_count = 0

    for match in addtest_pattern.finditer(cmake_content):
        test_block_content = "\n" + match.group(1).strip() + "\n"
        test_block_content_lower = test_block_content.lower()

        # 1. Pfad-Variablen SOFORT extrahieren
        path_var_match = re.search(r"\s+PATH\s+([^\s\)]+)", test_block_content)
        path_replacement = path_var_match.group(1).strip() if path_var_match else ""

        workdir_match = re.search(r"\s+WORKING_DIRECTORY\s+\$\{Data_SOURCE_DIR\}/([^\s\)]+)", test_block_content)
        workdir_subpath = workdir_match.group(1).strip() if workdir_match else ""
        
        if path_replacement:
            workdir_subpath = workdir_subpath.replace("<PATH>", path_replacement)
        workdir_subpath = workdir_subpath.replace("<SOURCE_PATH>", "").replace("<BUILD_PATH>", "").replace("<", "").replace(">", "")

        found_matches = [
            t for t in wrapper_tool_names_lower
            if re.search(r'(?:[\s/_-]|^)' + re.escape(t) + r'(?:[\s/_-]|$)', test_block_content_lower)
        ]

        matched_tool_name_lower = None
        if len(found_matches) == 1:
            matched_tool_name_lower = found_matches[0]
        elif len(found_matches) > 1:
            exec_match = re.search(r"\s+EXECUTABLE\s+([^\s\)]+)", test_block_content)
            if exec_match:
                executable_name_lower = exec_match.group(1).lower()
                if executable_name_lower in found_matches:
                    matched_tool_name_lower = executable_name_lower

        if not matched_tool_name_lower or matched_tool_name_lower in processed_tools_lower:
            continue

        if any(key in matched_tool_name_lower for key in ["gocad", "tetgen", "netgen"]):
            eprint(f"  Creating dummy test for complex tool: {matched_tool_name_lower}")
            macro_xml = ET.SubElement(macros_root, "xml", {"name": f"{matched_tool_name_lower}_test"})
            ET.SubElement(macro_xml, "test")
            processed_tools_lower.add(matched_tool_name_lower)
            test_case_count += 1
            continue

        args_match = re.search(r"EXECUTABLE_ARGS\s+(.*)", test_block_content)
        if args_match:
            args_str_check = args_match.group(1).lower()
            if ".pvd" in args_str_check:
                eprint(f"  Creating dummy test for PVD tool: {matched_tool_name_lower}")
                macro_xml = ET.SubElement(macros_root, "xml", {"name": f"{matched_tool_name_lower}_test"})
                ET.SubElement(macro_xml, "test")
                processed_tools_lower.add(matched_tool_name_lower)
                test_case_count += 1
                continue
        if not args_match:
            continue

        tool_name = tools_map_lower[matched_tool_name_lower]['name']
        
        try:
            args_str = args_match.group(1).strip().replace('\n', ' ')
            tool_data = tools_map_lower[matched_tool_name_lower]
            galaxy_inputs, output_map = process_parameters(tool_data['parameters'])
            if not output_map: continue

            eprint(f"  Generating REAL test for: {tool_name}")

            flag_map = {}
            unlabeled_params = []
            for p in galaxy_inputs:
                if p.is_unlabeled:
                    unlabeled_params.append(p)
                    continue
                if hasattr(p, 'original_long_flag') and p.original_long_flag:
                    flag_map[f"--{p.original_long_flag}"] = p
                if hasattr(p, 'original_short_flag') and p.original_short_flag:
                    flag_map[f"-{p.original_short_flag}"] = p

            output_flags = {f"--{flag}" for flag in output_map}
            output_flags.update({f"-{info['short_flag']}" for flag, info in output_map.items() if info.get('short_flag')})
            
            macro_xml = ET.SubElement(macros_root, "xml", {"name": f"{matched_tool_name_lower}_test"})
            test_case = ET.SubElement(macro_xml, "test")

            params_in_test = {}
            args_list = shlex.split(args_str)
            i, unlabeled_idx = 0, 0
            while i < len(args_list):
                arg = args_list[i]
                if arg in flag_map:
                    param = flag_map[arg]
                    has_next_val = (i + 1 < len(args_list)) and not args_list[i + 1].startswith('-')
                    
                    if has_next_val and not isinstance(param, BooleanParam):
                        params_in_test[param.name] = args_list[i + 1]
                        i += 2
                    else:
                        params_in_test[param.name] = "true"
                        i += 1
                else:
                    if unlabeled_idx < len(unlabeled_params):
                        params_in_test[unlabeled_params[unlabeled_idx].name] = arg
                        unlabeled_idx += 1
                    i += 1

            all_params_map = {p.name: p for p in galaxy_inputs}
            
            # --- INPUT PROCESSING ---
            for name, value in params_in_test.items():
                param = all_params_map.get(name)
                if not param: continue
                
                fv = str(value)
                if path_replacement: fv = fv.replace("<PATH>", path_replacement)
                fv = fv.replace("<SOURCE_PATH>", "").replace("<BUILD_PATH>", "").replace("<", "").replace(">", "").lstrip("/")

                param_attrs = {"name": name}
                if isinstance(param, DataParam):
                    url = ""
                    if fv.startswith("${Data_BINARY_DIR}/"):
                        url = f"{RAW_GITLAB_PROJECT_ROOT_URL}/{fv.replace('${Data_BINARY_DIR}/', '', 1).replace('<PATH>', path_replacement)}"
                    elif fv.startswith("${Data_SOURCE_DIR}/"):
                        url = f"{RAW_GITLAB_PROJECT_ROOT_URL}/{fv.replace('${Data_SOURCE_DIR}/', '', 1).replace('<PATH>', path_replacement)}"
                    elif fv != "true" and workdir_subpath:
                        url = f"{RAW_GITLAB_TEST_DATA_URL}/{workdir_subpath}/{fv}"
                    
                    if url:
                        url = url.replace("<PATH>", path_replacement).replace("<", "").replace(">", "")
                        param_attrs.update({"value": url.split('/')[-1], "location": url, "ftype": get_ogs_ftype(url.split('/')[-1])})
                    else:
                        param_attrs["value"] = fv
                else:
                    param_attrs["value"] = fv
                ET.SubElement(test_case, "param", param_attrs)

            # --- KORRIGIERTE OUTPUT PRÜFUNG MIT TOLERANZ ---
            diff_data_match = re.search(r"\s+DIFF_DATA\s+(.*?)(?=\s+\w+\s+|\s*\))", test_block_content, re.DOTALL)
            diff_files = parse_diff_data(diff_data_match.group(1), RAW_GITLAB_TEST_DATA_URL, workdir_subpath) if diff_data_match and workdir_subpath else []

            if len(output_map) == 1:
                # Fall 1: Einzelner Output
                out_elem = ET.SubElement(test_case, "output", {"name": sanitize_name(f"output_{tool_name}")})
                if diff_files:
                    ref = diff_files[0]["reference"].replace("<PATH>", path_replacement).replace("<", "").replace(">", "")
                    gen = diff_files[0]["generated"].replace("<PATH>", path_replacement).replace("<", "").replace(">", "").lstrip("/")
                    
                    # ECHTER TYP statt auto
                    ftype = get_ogs_ftype(diff_files[0]["ftype"])
                    out_elem.set("file", gen)
                    out_elem.set("location", ref)
                    out_elem.set("ftype", ftype)
                    
                    if any(ext in gen.lower() for ext in [".vtu", ".vtk", ".gml", ".xml", ".prj"]):
                        out_elem.set("compare", "sim_size")
                        out_elem.set("delta", "500")
                else:
                    ET.SubElement(ET.SubElement(out_elem, "assert_contents"), "has_size", {"min": "100"})
            else:
                # Fall 2: Mehrere Dateien (Collection)
                coll = ET.SubElement(test_case, "output_collection", {"name": "tool_outputs", "type": "list"})
                if diff_files:
                    for df in diff_files:
                        ref = df["reference"].replace("<PATH>", path_replacement).replace("<", "").replace(">", "")
                        gen = df["generated"].replace("<PATH>", path_replacement).replace("<", "").replace(">", "").lstrip("/")
                        ftype = get_ogs_ftype(df["ftype"])
                        
                        elem = ET.SubElement(coll, "element", {
                            "name": gen, 
                            "file": gen, 
                            "location": ref, 
                            "ftype": ftype
                        })
                        
                        if any(ext in gen.lower() for ext in [".vtu", ".vtk", ".gml", ".xml", ".prj"]):
                            elem.set("compare", "sim_size")
                            elem.set("delta", "500")
                else:
                    coll.set("count", str(len(output_map)))

            processed_tools_lower.add(matched_tool_name_lower)
            test_case_count += 1

        except Exception as e:
            eprint(f"!! FEHLER bei '{tool_name}': {e}")
            # Optional: Zeige hier den Fehler an, falls ein Test-Parsing fehlschlägt

    # --- FALLBACKS FÜR FEHLENDE TESTS ---
    for tool_data in all_tools_data:
        t_name_lower = tool_data['name'].lower()
        if t_name_lower not in processed_tools_lower:
            macro_xml = ET.SubElement(macros_root, "xml", {"name": f"{t_name_lower}_test"})
            ET.SubElement(macro_xml, "test")
            test_case_count += 1

    tree = ET.ElementTree(macros_root)
    ET.indent(tree, space="    ")
    output_filename = "test_macros.xml"
    with open(output_filename, "wb") as f:
        f.write(b'<?xml version="1.0" encoding="UTF-8"?>\n')
        tree.write(f, encoding="utf-8", xml_declaration=False)
    eprint(f"\nErfolgreich '{output_filename}' mit {test_case_count} Testfällen erstellt.")


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
