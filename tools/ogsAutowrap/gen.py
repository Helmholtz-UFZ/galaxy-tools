import sys
import re
import argparse
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import List, Dict, Any, Tuple

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
    r"(?:<(?P<cpp_type>.*?)>)?\s*\w+\s*[\({]\s*"
    r"\s*['\"](?P<short_flag>.*?)['\"],"
    r"\s*['\"](?P<long_flag>.*?)['\"],"
    r"\s*['\"](?P<help_text>.*?)['\"](?P<remaining_args>.*?)\s*[\)}];",
    re.DOTALL
)
TCLAP_PATTERN_UNLABELED = re.compile(
    r"TCLAP::(?P<arg_type>Unlabeled(?:Value|Multi)Arg)\s*"
    r"(?:<(?P<cpp_type>.*?)>)?\s*\w+\s*[\({]\s*"
    r"\s*['\"](?P<name_as_flag>.*?)['\"],"
    r"\s*['\"](?P<help_text>.*?)['\"],"
    r"\s*['\"](?P<remaining_args>.*?)\s*[\)}];",
    re.DOTALL
)
MIN_MAX_PATTERN = re.compile(r"\((min|max)\s*=\s*([^)]+)\)")
ALLOWED_VALUES_PATTERN = re.compile(r"\(allowed values:\s*([^)]+)\)")
STANDARD_PATTERN = re.compile(r"\(standard:\s*([^)]+)\)")
MULTIPLE_FORMATS_PATTERN = re.compile(r"\*\.([a-zA-Z0-9_]+)")

def eprint(*args, **kwargs):
    """Writes to stderr."""
    print(*args, file=sys.stderr, **kwargs)

def sanitize_name(name: str) -> str:
    """Sanitizes a string to be a valid Galaxy parameter name."""
    return re.sub(r'[^a-zA-Z0-9_]+', '_', name)

def discover_tools() -> List[Dict[str, Any]]:
    """Scans the OGS repo and finds tools using multiple regex patterns."""
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

        for match in std_matches:
            param_data = match.groupdict()
            param_data['is_unlabeled'] = False
            tools_dict[tool_name]["parameters"].append(param_data)

        for match in unlabeled_matches:
            param_data = match.groupdict()
            param_data['long_flag'] = param_data.pop('name_as_flag')
            param_data['is_unlabeled'] = True
            tools_dict[tool_name]["parameters"].append(param_data)
            
    all_tools_data = list(tools_dict.values())
    eprint(f"-> Found and processed {len(all_tools_data)} tools with TCLAP definitions.")
    return sorted(all_tools_data, key=lambda x: x['name'])

def process_parameters(tclap_params: List[Dict[str, Any]]) -> Tuple[List[object], Dict[str, str]]:
    """Processes TCLAP parameters into Galaxy parameter objects."""
    galaxy_inputs = []
    output_command_map = {}
    output_idx = 1

    for param_info in tclap_params:
        long_flag = param_info.get('long_flag', '')
        help_text = param_info.get('help_text', '')
        remaining_args = param_info.get('remaining_args', '')
        
        full_arg_text = f"{long_flag} {help_text} {remaining_args}"

        replacements = {
            "-1*std::numeric_limits<double>::max()": "-1.7976931348623157E+308",
            "-1 * std::numeric_limits<double>::max()": "-1.7976931348623157E+308",
            "-std::numeric_limits<double>::max()": "-1.7976931348623157E+308",
            "std::numeric_limits<double>::max()": "1.7976931348623157E+308",
            "std::numeric_limits<double>::epsilon()": "2.220446049250313e-16",
        }
        for find, replace in replacements.items():
            full_arg_text = full_arg_text.replace(find, replace)
        
        full_arg_text = ' '.join(full_arg_text.replace('"', '').replace('\\n', ' ').split())
        full_arg_text_lower = full_arg_text.lower()
        
        if not long_flag:
            continue
            
        var_name = sanitize_name(long_flag)

        is_output = 'output' in full_arg_text_lower or long_flag.lower().startswith('out')
        if is_output:
            format_match = MULTIPLE_FORMATS_PATTERN.search(full_arg_text)
            file_format = format_match.group(1) if format_match else 'dat'
            static_filename = f"output_{output_idx}.{file_format}"
            output_command_map[long_flag] = static_filename
            output_idx += 1
            continue

        is_base_file_input = 'input' in full_arg_text_lower and 'file' in full_arg_text_lower
        if is_base_file_input:
            attrs = {
                "name": var_name, 
                "label": var_name.replace('_', ' '), 
                "help": help_text, 
                "optional": 'true' not in remaining_args
            }
            format_matches = MULTIPLE_FORMATS_PATTERN.findall(full_arg_text)
            if format_matches:
                attrs['format'] = ",".join(format_matches)
            else:
                attrs['format'] = 'auto'
            attrs['multiple'] = "MultiArg" in param_info['arg_type'] or "list" in full_arg_text_lower
            galaxy_inputs.append(DataParam(**attrs))
            continue
        
        is_required_in_tclap = 'true' in remaining_args
        attrs = { "name": var_name, "label": var_name.replace('_', ' '), "help": help_text, "optional": not is_required_in_tclap }

        default_value_found = False
        standard_match = STANDARD_PATTERN.search(full_arg_text)
        if standard_match:
            attrs['value'] = standard_match.group(1).strip()
            attrs['optional'] = False
            default_value_found = True

        if not default_value_found and param_info['arg_type'] == 'ValueArg' and remaining_args:
            processed_rem_args = remaining_args
            for find, replace in replacements.items():
                processed_rem_args = processed_rem_args.replace(find, replace)
            
            rem_args_parts = [p.strip() for p in processed_rem_args.strip().lstrip(',').rstrip(');').split(',')]
            if len(rem_args_parts) >= 3:
                default_val_candidate = rem_args_parts[1].strip("'\" ")
                if default_val_candidate and not default_val_candidate.startswith('&'):
                    attrs['value'] = default_val_candidate
                    attrs['optional'] = False

        allowed_match = ALLOWED_VALUES_PATTERN.search(full_arg_text)
        if allowed_match:
            options = [opt.strip() for opt in allowed_match.group(1).split(',')]
            galaxy_inputs.append(SelectParam(options=dict([(o,o) for o in options]), **attrs))
            continue
            
        if param_info['arg_type'] == "SwitchArg":
            attrs.pop('optional', None)
            attrs.update(truevalue=f"--{long_flag}", falsevalue="", checked=False)
            galaxy_inputs.append(BooleanParam(**attrs))
            continue

        cpp_type = param_info.get('cpp_type', '')
        if "int" in cpp_type or "size_t" in cpp_type:
            param_class = IntegerParam
            if 'unsigned' in cpp_type or 'size_t' in cpp_type:
                attrs['min'] = "0"
        elif "float" in cpp_type or "double" in cpp_type:
            param_class = FloatParam
        else:
            param_class = TextParam
        
        min_max_search = MIN_MAX_PATTERN.findall(full_arg_text)
        if min_max_search:
            for key, val in min_max_search:
                attrs[key] = val.strip()
        galaxy_inputs.append(param_class(**attrs))

    return galaxy_inputs, output_command_map

def generate_tools():
    """Finds tools and generates an XML file for each."""
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

            for flag, filename in output_command_map.items():
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
    """Generates a test_macros.xml file with a test case for each tool."""
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
    """Parses command-line arguments and calls the appropriate function."""
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