import sys
import re
import argparse
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import List, Dict, Any, Tuple, Optional

from galaxyxml.tool import Tool
from galaxyxml.tool.parameters import (
    BooleanParam,
    DataParam,
    FloatParam,
    Inputs,
    IntegerParam,
    Outputs,
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
OUTPUT_DIR = Path("./generated_tools")

# --- REGEX PATTERNS ---
TCLAP_PATTERN_STD = re.compile(
    r"TCLAP::(?P<arg_type>(?:Value|Switch|Multi)Arg)\s*"
    r"(?:<(?P<cpp_type>.*?)>)?\s*(?P<tclap_var_name>\w+)\s*[\({]\s*"
    r"\s*['\"](?P<short_flag>.*?)['\"],"
    r"\s*['\"](?P<long_flag>.*?)['\"],"
    r"\s*['\"](?P<help_text>.*?)['\"](?P<remaining_args>.*?)\s*[\)}];",
    re.DOTALL
)
TCLAP_PATTERN_UNLABELED = re.compile(
    r"TCLAP::(?P<arg_type>Unlabeled(?:Value|Multi)Arg)\s*"
    r"(?:<(?P<cpp_type>.*?)>)?\s*(?P<tclap_var_name>\w+)\s*[\({]\s*"
    r"\s*['\"](?P<name_as_flag>.*?)['\"],"
    r"\s*['\"](?P<help_text>.*?)['\"],"
    r"\s*['\"](?P<remaining_args>.*?)\s*[\)}];",
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
        std_matches = list(TCLAP_PATTERN_STD.finditer(content))
        unlabeled_matches = list(TCLAP_PATTERN_UNLABELED.finditer(content))

        if not (std_matches or unlabeled_matches):
            continue

        tool_name = file_path.parent.name if file_path.name == 'main.cpp' else file_path.stem
        if tool_name.lower() in ["main", "utils"]:
            continue

        if tool_name not in tools_dict:
            tools_dict[tool_name] = {"name": tool_name, "parameters": []}
        
        for match in std_matches + unlabeled_matches:
            param_data = match.groupdict()
            param_data['is_unlabeled'] = 'Unlabeled' in param_data.get('arg_type', '')
            if param_data['is_unlabeled']:
                 param_data['long_flag'] = param_data.pop('name_as_flag')
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
        "std::numeric_limits<size_t>::max()": "18446744073709551615"
    }

    for param_info in tclap_params:
        if param_info.get('tclap_var_name') == "log_level_arg":
            continue

        long_flag = param_info.get('long_flag', '')
        if not long_flag:
            continue

        help_text = param_info.get('help_text', '').strip()
        remaining_args = param_info.get('remaining_args', '')
        var_name = sanitize_name(long_flag)
        
        rem_args_parts = [p.strip() for p in remaining_args.strip().lstrip(',').rstrip(');').split(',')]
        final_tclap_arg = ""
        if rem_args_parts and rem_args_parts[-1]:
            final_tclap_arg = rem_args_parts[-1].strip("'\"").upper()
        
        if help_text.startswith("Input"):
            is_base_filename = "BASE_FILENAME_INPUT" in final_tclap_arg
            is_file_list = "INPUT_FILE_LIST" in final_tclap_arg
            is_multiple = "PATH" in final_tclap_arg or is_file_list
            
            formats = []
            format_match = FILE_EXTENSION_PATTERN.search(help_text)
            if format_match:
                ext_part = format_match.group(1)
                formats = [ext.strip().lstrip('.') for ext in ext_part.split('|')]
            
            attrs = {
                "name": var_name,
                "label": var_name.replace('_', ' '),
                "help": param_info.get('help_text', ''),
                "optional": 'true' not in remaining_args,
                "format": ",".join(formats) if formats else 'data',
                "multiple": is_multiple
            }
            
            param = DataParam(**attrs)

            if is_file_list:
                param.is_file_list = True
            if is_base_filename:
                param.is_base_filename = True
            
            galaxy_inputs.append(param)
            continue
        
        if help_text.startswith("Output"):
            # HIER IST DIE LOGIK FÜR BASE_FILENAME_OUTPUT
            is_base_filename_output = "BASE_FILENAME_OUTPUT" in final_tclap_arg
            
            file_format = 'dat'
            format_match = FILE_EXTENSION_PATTERN.search(help_text)
            if format_match:
                ext_part = format_match.group(1)
                first_ext = [ext.strip().lstrip('.') for ext in ext_part.split('|')][0]
                if first_ext: file_format = first_ext
            
            static_filename = f"output_{output_idx}.{file_format}"
            
            output_command_map[long_flag] = {
                'filename': static_filename,
                'is_base_filename': is_base_filename_output
            }
            output_idx += 1
            continue
        
        is_required_in_tclap = 'true' in remaining_args
        attrs = {"name": var_name, "label": var_name.replace('_', ' '), "help": help_text, "optional": not is_required_in_tclap}

        full_arg_text = f"{long_flag} {help_text} {remaining_args}"
        min_max_search = MIN_MAX_PATTERN.findall(full_arg_text)
        if min_max_search:
            for key, val in min_max_search:
                attrs[key] = val.strip()

        cleaned_remaining_args = MIN_MAX_PATTERN.sub('', remaining_args)
        cleaned_rem_args_parts = [p.strip() for p in cleaned_remaining_args.strip().lstrip(',').rstrip(');').split(',')]
        
        last_arg = cleaned_rem_args_parts[-1].strip() if cleaned_rem_args_parts else ""
        if last_arg.startswith('&'):
            code_before_param = param_info['full_source_code'][:param_info['match_start_pos']]
            constraint_var_name = last_arg.lstrip('&')
            options = resolve_values_constraint(constraint_var_name, code_before_param)
            
            if options:
                attrs.pop('optional', None)
                galaxy_inputs.append(SelectParam(options=dict([(o, o) for o in options]), **attrs))
                continue
        
        if param_info['arg_type'] == 'ValueArg':
            default_val_candidate = ""
            found_variable = False

            for part in cleaned_rem_args_parts:
                if part.startswith('&'):
                    default_val_candidate = part
                    found_variable = True
                    break

            if not found_variable and len(cleaned_rem_args_parts) >= 2:
                default_val_candidate = cleaned_rem_args_parts[1].strip().strip("'\"")

            if default_val_candidate:
                resolved_value = ""
                if default_val_candidate.startswith('&'):
                    code_before_param = param_info['full_source_code'][:param_info['match_start_pos']]
                    var_to_resolve = default_val_candidate.lstrip('&')
                    value_from_code = resolve_variable_value(var_to_resolve, code_before_param)
                    if value_from_code:
                        resolved_value = value_from_code
                else:
                    resolved_value = default_val_candidate

                if resolved_value in replacements:
                    resolved_value = replacements[resolved_value]
                
                if resolved_value:
                    attrs['value'] = resolved_value
                    attrs['optional'] = False
        
        if param_info['arg_type'] == "SwitchArg":
            attrs.pop('optional', None)
            attrs.update(truevalue=f"--{long_flag}", falsevalue="", checked=False)
            galaxy_inputs.append(BooleanParam(**attrs))
            continue

        cpp_type = param_info.get('cpp_type', '')
        param_class = TextParam
        if "int" in cpp_type or "size_t" in cpp_type:
            param_class = IntegerParam
            if 'unsigned' in cpp_type or 'size_t' in cpp_type:
                if 'min' not in attrs:
                    attrs['min'] = "0"
        elif "float" in cpp_type or "double" in cpp_type:
            param_class = FloatParam
        
        galaxy_inputs.append(param_class(**attrs))

    return galaxy_inputs, output_command_map


def generate_tools():
    if not OGS_REPO_PATH.is_dir():
        eprint(f"ERROR: The OGS repository directory '{OGS_REPO_PATH}' was not found.")
        return

    OUTPUT_DIR.mkdir(exist_ok=True)
    parsed_tools = discover_tools()
    if not parsed_tools:
        eprint("No tools with TCLAP definitions found. Aborting.")
        return

    generated_count = 0
    for tool_data in parsed_tools:
        tool_name = tool_data['name']
        eprint(f"Generating wrapper for: {tool_name}...")
        try:
            galaxy_inputs, output_command_map = process_parameters(tool_data['parameters'])
            
            command_lines = [tool_name]
            for param in galaxy_inputs:
                is_galaxy_optional = getattr(param, 'optional', False) and not hasattr(param, 'value')
                param_var = f'${param.name}'
                original_long_flag = next((p['long_flag'] for p in tool_data['parameters'] if sanitize_name(p['long_flag']) == param.name), "")
                is_unlabeled = any(p.get('is_unlabeled', False) for p in tool_data['parameters'] if sanitize_name(p['long_flag']) == param.name)

                if isinstance(param, BooleanParam):
                    command_lines.append(f"    {param_var}")
                elif is_unlabeled:
                    command_lines.append(f"    '{param_var}'")
                elif getattr(param, 'is_file_list', False):
                    list_filename = f"{param.name}_list.txt"
                    command_lines.append(f"    #for $f in {param_var}:")
                    command_lines.append(f'        #echo str($f) >> "{list_filename}"')
                    command_lines.append(f"    #end for")
                    command_lines.append(f"    --{original_long_flag} '{list_filename}'")
                elif getattr(param, 'is_base_filename', False):
                    command_lines.append(f"    --{original_long_flag} '${{{param_var}.rsplit('.', 1)[0]}}'")
                elif getattr(param, 'multiple', False):
                    command_lines.append(f"    #for $f in {param_var}:")
                    command_lines.append(f"        --{original_long_flag} '$f'")
                    command_lines.append(f"    #end for")
                elif is_galaxy_optional:
                    command_lines.append(f"    #if str({param_var}):")
                    command_lines.append(f"        --{original_long_flag} '{param_var}'")
                    command_lines.append(f"    #end if")
                else:
                    command_lines.append(f"    --{original_long_flag} '{param_var}'")

            # HIER IST DIE LOGIK FÜR BASE_FILENAME_OUTPUT
            for flag, output_info in output_command_map.items():
                filename = output_info['filename']
                
                if output_info.get('is_base_filename'):
                    # Wenn die Markierung gesetzt ist, entferne die Endung.
                    filename_without_ext = filename.rsplit('.', 1)[0]
                    command_lines.append(f"    --{flag} {filename_without_ext}")
                else:
                    # Ansonsten füge den vollen Dateinamen hinzu, wie bisher.
                    command_lines.append(f"    --{flag} {filename}")
            
            command_str = "\n".join(command_lines)

            tool = Tool(
                name=f"OGS: {tool_name}", id=f"ogs_{tool_name.lower()}",
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
                collection = OutputCollection(name="tool_outputs", type="list", label=f"Outputs from {tool_name}")
                collection.append(DiscoverDatasets(pattern=r"output_.+\..+", format="auto", visible=True))
                outputs_tag.append(collection)

            tests_section = Tests()
            tests_section.append(Expand(macro="ogsutilssuite_tests"))
            tool.tests = tests_section
            tool.help = (f"This tool runs the **{tool_name}** utility from the OpenGeoSys suite.")

            output_file_path = OUTPUT_DIR / f"{tool_name}.xml"
            with open(output_file_path, 'w', encoding='utf-8') as f:
                f.write(tool.export())
            eprint(f"-> Successfully saved: {output_file_path}")
            generated_count += 1
        except Exception as e:
            eprint(f"!! ERROR while processing '{tool_name}': {e}")
            import traceback
            traceback.print_exc(file=sys.stderr)

    eprint(f"\nFinished. {generated_count} of {len(parsed_tools)} tool wrappers were created in the '{OUTPUT_DIR}' directory.")


def generate_tests():
    eprint("--- Generating Test Macros ---")
    parsed_tools = discover_tools()
    if not parsed_tools:
        eprint("No tools found, cannot generate tests.")
        return

    macros_root = ET.Element("macros")
    tests_macro = ET.SubElement(macros_root, "xml", {"name": "ogsutilssuite_tests"})

    for tool_data in parsed_tools:
        tool_name = tool_data['name']
        eprint(f"  Generating test for: {tool_name}")
        
        try:
            test_case = ET.SubElement(tests_macro, "test", {"expect_num_outputs": "1"})
            
            galaxy_inputs, output_map = process_parameters(tool_data['parameters'])

            for param in galaxy_inputs:
                param_name = param.name
                test_value = "" 
                
                if hasattr(param, 'value'):
                    test_value = param.value
                elif isinstance(param, DataParam):
                    test_value = f"test-data/{param_name}.dat" 
                elif isinstance(param, IntegerParam):
                    test_value = getattr(param, 'min', "1")
                elif isinstance(param, FloatParam):
                    test_value = getattr(param, 'min', "1.0")
                elif isinstance(param, BooleanParam):
                    test_value = "true"
                elif isinstance(param, SelectParam) and hasattr(param, 'options') and param.options:
                    test_value = list(param.options.keys())[0]
                else:
                    test_value = f"test_{param_name}"

                ET.SubElement(test_case, "param", {"name": param_name, "value": str(test_value)})

            if output_map:
                output_collection = ET.SubElement(test_case, "output_collection", {"name": "tool_outputs", "type": "list"})
                ET.SubElement(output_collection, "assert_contents").append(
                    ET.Element("has_size", {"n": str(len(output_map))})
                )
        except Exception as e:
            eprint(f"!! ERROR while generating test for '{tool_name}': {e}")
            import traceback
            traceback.print_exc(file=sys.stderr)

    tree = ET.ElementTree(macros_root)
    ET.indent(tree, space="    ")
    output_filename = "test_macros.xml"
    with open(output_filename, "wb") as f:
        f.write(b'<?xml version="1.0" encoding="UTF-8"?>\n')
        tree.write(f, encoding="utf-8", xml_declaration=False)
    eprint(f"\nSuccessfully created {output_filename} with {len(parsed_tools)} test cases.")

def main():
    parser = argparse.ArgumentParser(description="Galaxy XML Wrapper Generator for OGS Utilities")
    parser.add_argument(
        '--generate-tool',
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