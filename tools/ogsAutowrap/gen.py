import sys
import re
import argparse
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import List, Dict, Any, Tuple, Optional
import shlex

from galaxyxml.tool import Tool
from galaxyxml.tool.parameters import (
    BooleanParam,
    DataParam,
    FloatParam,
    Inputs,
    IntegerParam,
    Outputs,
    OutputData,
    SelectParam,
    TextParam,
    OutputCollection,
    DiscoverDatasets,
    Tests,
    Expand,
    Command,
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
        r"((?:const|constexpr|static)\s+)*[\w\:\.\<\> ]+\s+" +
        re.escape(var_name) + r"\b"
    )

    for match in declaration_start_pattern.finditer(search_space):
        end_of_declaration = match.end()
        remaining_code = search_space[end_of_declaration:].lstrip()

        if remaining_code.startswith('='):
            val_match = re.search(r"=\s*([^;]*);", remaining_code)
            if val_match:
                value = val_match.group(1).strip()
                if value.endswith(('f', 'u', 'l', 'L')): value = value[:-1]
                return value.strip('"')

        elif remaining_code.startswith('('):
            balance = 1
            start_pos = end_of_declaration + remaining_code.find('(')
            
            for i, char in enumerate(search_space[start_pos + 1:]):
                if char == '(': balance += 1
                elif char == ')': balance -= 1

                if balance == 0:
                    end_pos = start_pos + 1 + i
                    value = search_space[start_pos + 1 : end_pos].strip()
                    if value.endswith(('f', 'u', 'l', 'L')): value = value[:-1]
                    return value.strip('"')

        elif remaining_code.startswith('{'):
            val_match = re.search(r"\{\s*([^}]*)\};", remaining_code)
            if val_match:
                value = val_match.group(1).strip()
                if value.endswith(('f', 'u', 'l', 'L')): value = value[:-1]
                return value.strip('"')

    return None


def resolve_values_constraint(var_name: str, search_space: str) -> List[str]:
    """
    Löst einen TCLAP::ValuesConstraint in eine Liste von Optionswerten auf.
    Kann jetzt sowohl Vektoren mit Initialisierungslisten als auch solche,
    die mit emplace_back gefüllt werden, verarbeiten.
    """
    vc_pattern = re.compile(
        r"TCLAP::ValuesConstraint<\s*[\w\:]+\s*>\s+" + re.escape(var_name) +
        r"\s*[\({]\s*(\w+)\s*[\)}]", re.DOTALL
    )
    vc_match = vc_pattern.search(search_space)
    if not vc_match:
        return []

    vector_var_name = vc_match.group(1)

    vec_pattern = re.compile(
        r"std::vector<\s*[\w\:\.<> ]+\s*>\s+" + re.escape(vector_var_name) +
        r"\s*\{(.*?)\};", re.DOTALL
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
        if param_info.get('tclap_var_name') == "log_level_arg": continue
        all_args_str = param_info.get('all_args', '')
        if not all_args_str: continue
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
        if not long_flag: continue
        help_parts = re.findall(r'"(.*?)"', help_text_raw, re.DOTALL)
        help_text = ' '.join(part.strip() for part in help_parts)
        help_text = re.sub(r'(the\s+)?name\s+of\s+', '', help_text, flags=re.IGNORECASE)
        help_text = re.sub(r'\s{2,}', ' ', help_text).strip()
        var_name = sanitize_name(long_flag)
        cleaned_rem_args_parts = [p.strip() for p in remaining_args_list if p.strip()]
        final_tclap_arg = cleaned_rem_args_parts[-1].strip("'\"") if cleaned_rem_args_parts else ""
        if help_text.startswith("Output"):
            is_base_filename_output = "BASE_FILENAME_OUTPUT" in final_tclap_arg
            output_type = 'file' if final_tclap_arg == 'OUTPUT_FILE' else 'collection_member'
            file_format = 'dat'
            format_match = FILE_EXTENSION_PATTERN.search(help_text)
            if format_match:
                file_format = [ext.strip().lstrip('.') for ext in format_match.group(1).split('|')][0] or 'dat'
            output_command_map[long_flag] = {
                'filename': f"output_{output_idx}.{file_format}",
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
            is_multiple = "PATH" in final_tclap_arg or is_file_list
            formats = []
            format_match = FILE_EXTENSION_PATTERN.search(help_text)
            if format_match:
                formats = [ext.strip().lstrip('.') for ext in format_match.group(1).split('|')]
            attrs = {
                "name": var_name, "label": var_name.replace('_', ' '), "help": help_text,
                "optional": 'true' not in cleaned_rem_args_parts,
                "format": ",".join(formats) if formats else 'data', "multiple": is_multiple
            }
            param = DataParam(**attrs)
            param.tclap_marker = final_tclap_arg
        else:
            is_required_in_tclap = cleaned_rem_args_parts and cleaned_rem_args_parts[0] == 'true'
            attrs = {"name": var_name, "label": var_name.replace('_', ' '), "help": help_text, "optional": not is_required_in_tclap}
            full_arg_text = f"{long_flag} {help_text} {' '.join(remaining_args_list)}"
            min_max_search = MIN_MAX_PATTERN.findall(full_arg_text)
            if min_max_search:
                for key, val in min_max_search: attrs[key] = val.strip()
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
                        if is_req and len(cleaned_rem_args_parts) > 1: default_val_candidate = cleaned_rem_args_parts[1]
                        elif not is_req: default_val_candidate = cleaned_rem_args_parts[0]
                    if default_val_candidate is not None:
                        resolved_value = ""
                        if default_val_candidate.strip().startswith('&'):
                            var_to_resolve = default_val_candidate.strip().lstrip('&')
                            code_before = param_info['full_source_code'][:param_info['match_start_pos']]
                            value_from_code = resolve_variable_value(var_to_resolve, code_before)
                            if value_from_code: resolved_value = value_from_code
                        else: resolved_value = default_val_candidate.strip().strip("'\"")
                        if resolved_value in replacements: resolved_value = replacements[resolved_value]
                        if resolved_value: attrs['value'] = resolved_value
                    cpp_type = param_info.get('cpp_type', '')
                    param_class = TextParam
                    if "int" in cpp_type or "size_t" in cpp_type:
                        param_class = IntegerParam
                        if 'unsigned' in cpp_type or 'size_t' in cpp_type and 'min' not in attrs: attrs['min'] = "0"
                    elif "float" in cpp_type or "double" in cpp_type: param_class = FloatParam
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

            command_lines = [tool_name]
            
            for param in galaxy_inputs:
                param_var = f'${param.name}'
                original_long_flag = getattr(param, 'original_long_flag', param.name)
                is_unlabeled = getattr(param, 'is_unlabeled', False)
                tclap_marker = getattr(param, 'tclap_marker', '')

                optional_attr = getattr(param, 'optional', False)
                is_optional_in_xml = (optional_attr is True or str(optional_attr).lower() == 'true')

                needs_if_wrapper = is_optional_in_xml

                if isinstance(param, BooleanParam):
                    command_lines.append(f"    {param_var}")
                    continue
                if is_unlabeled:
                    command_lines.append(f"    '{param_var}'")
                    continue
                if tclap_marker == 'INPUT_FILE_LIST':
                    list_filename = f"{param.name}_list.txt"
                    command_lines.append(f"    #for $f in {param_var}:")
                    command_lines.append(f'        #echo str($f) >> "{list_filename}"')
                    command_lines.append(f"    #end for")
                    command_lines.append(f"    --{original_long_flag} '{list_filename}'")
                    continue
                if tclap_marker == 'INPUT_PATH':
                    command_lines.append(f"    #for $f in {param_var}:")
                    command_lines.append(f"        --{original_long_flag} '$f'")
                    command_lines.append(f"    #end for")
                    continue
                if tclap_marker == 'BASE_FILENAME_INPUT':
                    command_lines.append(f"    --{original_long_flag} '${{{param_var}.rsplit('.', 1)[0]}}'")
                    continue

                command_part = f"--{original_long_flag} '{param_var}'"

                if needs_if_wrapper:
                    command_lines.append(f"    #if str({param_var}):")
                    command_lines.append(f"        {command_part}")
                    command_lines.append(f"    #end if")
                else: 
                    command_lines.append(f"    {command_part}")

            for flag, output_info in output_command_map.items():
                filename = output_info['filename']
                if output_info.get('is_base_filename'):
                    filename_without_ext = filename.rsplit('.', 1)[0]
                    command_lines.append(f"    --{flag} {filename_without_ext}")
                else:
                    command_lines.append(f"    --{flag} {filename}")
            
            command_str = "\n".join(command_lines)

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
                single_file_outputs = [v for v in output_command_map.values() if v.get('type') == 'file']
                if len(single_file_outputs) == 1 and len(output_command_map) == 1:
                    file_info = single_file_outputs[0]
                    output_name = sanitize_name(f"output_{tool_name}")
                    output_param = OutputData(
                        name=output_name,
                        format=file_info['format'],
                        from_work_dir=file_info['filename'],
                        label=f"Output file from {tool_name}"
                    )
                    outputs_tag.append(output_param)
                else:
                    collection = OutputCollection(name="tool_outputs", type="list", label=f"Outputs from {tool_name}")
                    collection.append(DiscoverDatasets(pattern=r"output_.+\..+", format="auto", visible=True))
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
    Versucht echte Tests aus Tests.cmake zu extrahieren.
    Falls kein valider Test gefunden wird (z.B. keine Outputs), wird ein leerer Test-Rumpf erstellt.
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

        path_var_match = re.search(r"\s+set\s*\(\s*Path\s+([^\s\)]+)\s*\)", test_block_content)
        path_replacement = path_var_match.group(1) if path_var_match else ""

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

        args_match = re.search(r"\s+EXECUTABLE_ARGS\s+(.*?)(?=\s+\w+\s+|\s*\))", test_block_content, re.DOTALL)
        if not args_match:
            continue

        workdir_match = re.search(r"\s+WORKING_DIRECTORY\s+\$\{Data_SOURCE_DIR\}/([^\s\)]+)", test_block_content)
        workdir_subpath = workdir_match.group(1).strip() if workdir_match else ""

        tool_name = tools_map_lower[matched_tool_name_lower]['name']
        test_name_match = re.search(r"\s+NAME\s+([^\s\)]+)", test_block_content)
        test_name = test_name_match.group(1) if test_name_match else "UnknownTest"

        try:
            args_str = args_match.group(1).strip().replace('\n', ' ')
            tool_data = tools_map_lower[matched_tool_name_lower]
            galaxy_inputs, output_map = process_parameters(tool_data['parameters'])


            if not output_map:
                continue

            eprint(f"  Generating REAL test for: {tool_name} (from test '{test_name}')")

            flag_map = {f"--{p.original_long_flag}": p for p in galaxy_inputs if not p.is_unlabeled and p.original_long_flag}
            flag_map.update({f"-{p.original_short_flag}": p for p in galaxy_inputs if not p.is_unlabeled and p.original_short_flag})
            unlabeled_params = [p for p in galaxy_inputs if p.is_unlabeled]
            output_flags = {f"--{flag}" for flag in output_map}
            output_flags.update({f"-{info['short_flag']}" for flag, info in output_map.items() if info.get('short_flag')})

            macro_name = f"{matched_tool_name_lower}_test"
            macro_xml = ET.SubElement(macros_root, "xml", {"name": macro_name})
            test_case = ET.SubElement(macro_xml, "test")

            params_in_test = {}
            args_list = shlex.split(args_str)
            i = 0
            unlabeled_idx = 0

            while i < len(args_list):
                arg = args_list[i]
                if arg == '--': i += 1; continue
                if arg in flag_map:
                    param = flag_map[arg]
                    is_value_arg = (i + 1 < len(args_list)) and (not args_list[i+1].startswith('-'))
                    if isinstance(param, BooleanParam) or not is_value_arg:
                        params_in_test[param.name] = "true"; i += 1
                    else:
                        params_in_test[param.name] = args_list[i+1]; i += 2
                else:
                    if unlabeled_idx < len(unlabeled_params):
                        param = unlabeled_params[unlabeled_idx]
                        params_in_test[param.name] = arg; unlabeled_idx += 1
                    i += 1

            all_params_map = {p.name: p for p in galaxy_inputs}
            for name, value in params_in_test.items():
                param = all_params_map.get(name)
                if param and (f"--{param.original_long_flag}" in output_flags or (param.original_short_flag and f"-{param.original_short_flag}" in output_flags)):
                    continue

                final_value = value

                if path_replacement:
                    final_value = final_value.replace("<PATH>", path_replacement)

                if "<SOURCE_PATH>/" in final_value:
                    final_value = final_value.replace("<SOURCE_PATH>/", "")

                if '<' in final_value or '>' in final_value:
                    raise ValueError(f"Test contains unresolved XML placeholder: {final_value}")

                if isinstance(param, DataParam):
                    if final_value.startswith("${Data_BINARY_DIR}/"): final_value = f"{RAW_GITLAB_PROJECT_ROOT_URL}/{final_value.replace('${Data_BINARY_DIR}/', '', 1)}"
                    elif final_value.startswith("${Data_SOURCE_DIR}/"): final_value = f"{RAW_GITLAB_PROJECT_ROOT_URL}/{final_value.replace('${Data_SOURCE_DIR}/', '', 1)}"
                    elif final_value != "true" and workdir_subpath: final_value = f"{RAW_GITLAB_TEST_DATA_URL}/{workdir_subpath}/{final_value}"

                ET.SubElement(test_case, "param", {"name": name, "value": final_value})

            diff_data_match = re.search(r"\s+DIFF_DATA\s+(.*?)(?=\s+\w+\s+|\s*\))", test_block_content, re.DOTALL)
            diff_files = []
            if diff_data_match and workdir_subpath:
                diff_files = parse_diff_data(diff_data_match.group(1), RAW_GITLAB_TEST_DATA_URL, workdir_subpath)

            single_file_outputs = [v for v in output_map.values() if v.get('type') == 'file']
            is_single_output_file = len(single_file_outputs) == 1 and len(output_map) == 1

            if is_single_output_file:
                output_name = sanitize_name(f"output_{tool_name}")
                attrs = {"name": output_name}
                if diff_files:
                    attrs["file"] = diff_files[0]["reference"]
                    attrs["ftype"] = diff_files[0]["ftype"]
                ET.SubElement(test_case, "output", attrs)
            else:
                if not diff_files:
                    ET.SubElement(test_case, "output_collection", {
                        "name": "tool_outputs", "type": "list", "count": str(len(output_map))
                    })
                else:
                    collection = ET.SubElement(test_case, "output_collection", {"name": "tool_outputs", "type": "list"})
                    for diff_file in diff_files:
                         ET.SubElement(collection, "element", {
                            "name": diff_file["generated"],
                            "file": diff_file["reference"],
                            "ftype": diff_file["ftype"]
                         })

            processed_tools_lower.add(matched_tool_name_lower)
            test_case_count += 1

        except Exception as e:
            eprint(f"!! FEHLER beim Generieren des Tests für '{tool_name}' (Test '{test_name}'): {e}")

    eprint("\n--- Checking for missing tests and generating empty fallbacks ---")
    for tool_data in all_tools_data:
        t_name_lower = tool_data['name'].lower()

        if t_name_lower not in processed_tools_lower:
            eprint(f"  Generating EMPTY fallback test for: {tool_data['name']}")

            macro_name = f"{t_name_lower}_test"
            macro_xml = ET.SubElement(macros_root, "xml", {"name": macro_name})
            test_case = ET.SubElement(macro_xml, "test")

            test_case_count += 1

    tree = ET.ElementTree(macros_root)
    ET.indent(tree, space="    ")
    output_filename = "test_macros.xml"
    with open(output_filename, "wb") as f:
        f.write(b'<?xml version="1.0" encoding="UTF-8"?>\n')
        tree.write(f, encoding="utf-8", xml_declaration=False)
    eprint(f"\nErfolgreich '{output_filename}' mit {test_case_count} Testfällen erstellt (davon {len(processed_tools_lower)} echte und {test_case_count - len(processed_tools_lower)} leere).")

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