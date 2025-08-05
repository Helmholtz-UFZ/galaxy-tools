import sys
import re
from pathlib import Path
from typing import List, Dict, Any, Optional

from galaxyxml.tool import Tool
from galaxyxml.tool.parameters import (
    BooleanParam,
    Conditional,
    DataParam,
    DiscoverDatasets,
    FloatParam,
    Inputs,
    IntegerParam,
    OutputCollection,
    Outputs,
    Repeat,
    SelectParam,
    TextParam,
    When,
)

# --- KONFIGURATION ---
OGS_REPO_PATH = Path("/home/stehling/gitProjects/ogs")
UTILS_SUBDIR = "Applications/Utils"

# Flexibler Regex, um verschiedene TCLAP-Konstruktoren zu erfassen
TCLAP_PATTERN = re.compile(
    r"TCLAP::"
    r"(?P<arg_type>\w+Arg)\s*"
    r"(?:<(?P<cpp_type>.*?)>)?\s*"
    r"(?P<var_name>\w+)\s*\("
    r"\s*['\"](?P<short_flag>.*?)['\"],"
    r"\s*['\"](?P<long_flag>.*?)['\"],"
    r"\s*['\"](?P<help_text>.*?)['\"]"
    r"(?P<remaining_args>.*?)\);"
    ,
    re.DOTALL
)

def eprint(*args, **kwargs):
    """Schreibt auf stderr, damit die XML-Ausgabe sauber bleibt."""
    print(*args, file=sys.stderr, **kwargs)

def discover_and_parse_tools() -> List[Dict[str, Any]]:
    """Durchsucht das OGS-Repo, findet Tools und parst deren Parameter."""
    base_path = OGS_REPO_PATH / UTILS_SUBDIR
    if not base_path.is_dir():
        eprint(f"FEHLER: Das Unterverzeichnis '{base_path}' existiert nicht.")
        return []
    source_files = list(base_path.glob("**/*.cpp"))
    all_tools_data = []

    eprint(f"Durchsuche {len(source_files)} potentielle .cpp-Dateien...")

    for file_path in source_files:
        try:
            content = file_path.read_text(encoding='utf-8')
        except Exception:
            continue

        matches = list(TCLAP_PATTERN.finditer(content))
        if not matches:
            continue

        tool_name = file_path.stem
        
        tool_params = []
        output_params = []
        for match in matches:
            param_data = match.groupdict()
            for key, value in param_data.items():
                param_data[key] = ' '.join(value.replace('"', '').replace('\\n', ' ').split()) if value else ''

            param_data['required'] = 'true' in param_data['remaining_args']

            is_output = 'out' in param_data['long_flag'].lower() or 'out' in param_data['var_name'].lower()
            is_input = 'in' in param_data['long_flag'].lower() or 'in' in param_data['var_name'].lower()
            
            if is_output:
                param_data['param_io_type'] = 'output'
                output_params.append(param_data)
            else:
                param_data['param_io_type'] = 'input' if is_input else 'parameter'
                tool_params.append(param_data)
        
        all_tools_data.append({
            "name": tool_name,
            "parameters": tool_params,
            "outputs": output_params
        })
        
    eprint(f"-> {len(all_tools_data)} Tools mit TCLAP-Definitionen gefunden und verarbeitet.")
    return sorted(all_tools_data, key=lambda x: x['name'])


def map_tclap_to_galaxy_param(param_info: Dict[str, Any], tool_name: str) -> Optional[object]:
    """Wandelt ein geparstes TCLAP-Dictionary in ein galaxyxml-Parameterobjekt um."""
    arg_type = param_info['arg_type']
    cpp_type = param_info.get('cpp_type', '')
    long_flag = param_info['long_flag']
    help_text = param_info['help_text']
    is_required = param_info['required']

    label = help_text.split('.')[0]
    if len(label) > 70:
        label = label[:67] + '...'
    if not label:
        label = long_flag
    
    param_name_xml = f"{tool_name}_{long_flag}"
    attrs = {"name": param_name_xml, "label": label, "help": help_text, "optional": not is_required}

    if param_info['param_io_type'] == 'input':
        return DataParam(format="auto", **attrs)
    
    if arg_type == "SwitchArg":
        return BooleanParam(truevalue=f"--{long_flag}", falsevalue="", checked=False, **attrs)

    if not is_required:
        attrs['value'] = ""

    if "int" in cpp_type:
        return IntegerParam(**attrs)
    
    if "float" in cpp_type or "double" in cpp_type:
        return FloatParam(**attrs)
    
    return TextParam(**attrs)


def build_command_block(parsed_tools: List[Dict[str, Any]]) -> str:
    """Erstellt den finalen, komplexen Cheetah-formatierten <command>-Block."""
    command_lines = [
        '#for $i, $step in enumerate($utils_repeat):',
        '    #if $i > 0:',
        '        && \\',
        '    #end if',
        '    #set $selector = $step.tool_selector',
        '    #set $selected_tool_name = str($selector.selected_tool)',
    ]
    
    for i, tool_data in enumerate(parsed_tools):
        tool_name = tool_data["name"]
        control_flow = "#if" if i == 0 else "#elif"
        
        command_lines.append(f"    {control_flow} $selected_tool_name == '{tool_name}'")
        command_lines.append(f"        {tool_name} \\")

        for param in tool_data["parameters"]:
            param_name_xml = f"{tool_name}_{param['long_flag']}"
            param_var = f"$selector.{param_name_xml}"
            
            if param['arg_type'] == "SwitchArg":
                command_lines.append(f"        {param_var}")
            else:
                command_lines.append(f"        #if str({param_var}):")
                command_lines.append(f"            --{param['long_flag']} '{param_var}' \\")
                command_lines.append(f"        #end if")
        
        for j, out_param in enumerate(tool_data["outputs"]):
            output_filename_expr = (
                "\"step_\" + str($i + 1) + \"_\" + $selected_tool_name + "
                f"\"_output_{j + 1}.dat\""
            )
            command_lines.append(f"        --{out_param['long_flag']} {output_filename_expr}")
            
    command_lines.append("#end if")
    command_lines.append("#end for")
    return "\n".join(command_lines)

def main():
    """Hauptfunktion: Baut das Tool-Objekt zusammen und exportiert es als XML."""
    if not OGS_REPO_PATH.is_dir():
        eprint(f"FEHLER: Das OGS-Repository-Verzeichnis '{OGS_REPO_PATH}' wurde nicht gefunden.")
        return

    parsed_tools = discover_and_parse_tools()
    if not parsed_tools:
        eprint("Keine Tools mit TCLAP-Definitionen gefunden. Breche ab.")
        return

    command_str = build_command_block(parsed_tools)

    tool = Tool(
        name="OGS Utils Suite",
        id="ogsutilssuite",
        version="@TOOL_VERSION@+galaxy@VERSION_SUFFIX@",
        description="A dynamic wrapper for OGS utilities, generated from source code.",
        executable="ogs",
        macros=["macros.xml"],
        command_override=[command_str],
        profile="22.01",
        version_command="ogs --version",
    )
    
    tool.help = "This tool is a suite wrapper for the OpenGeoSys command-line utilities. " \
                "You can chain multiple utilities together. Each step will be executed in sequence."

    inputs = tool.inputs = Inputs()
    repeat = Repeat(name="utils_repeat", title="OGS Utility Steps", min=1)
    
    conditional = Conditional(name="tool_selector")
    tool_options = dict([(t['name'], t['name']) for t in parsed_tools])
    conditional.append(SelectParam(name="selected_tool", label="Select OGS Utility", options=tool_options))

    for t_data in parsed_tools:
        when_block = When(value=t_data['name'])
        
        for param_info in t_data['parameters']:
            galaxy_param = map_tclap_to_galaxy_param(param_info, t_data['name'])
            if galaxy_param:
                when_block.append(galaxy_param)
        
        conditional.append(when_block)
        
    repeat.append(conditional)
    inputs.append(repeat)

    outputs = tool.outputs = Outputs()
    output_collection = OutputCollection(
        name="all_outputs",
        type="list",
        label="All Generated Outputs"
    )
    output_collection.append(
        DiscoverDatasets(pattern=r".+", directory=".", visible=True)
    )
    outputs.append(output_collection)

    tool_xml = tool.export()

   

    # Füge die Blöcke an den richtigen Stellen ein
    final_xml = tool_xml.replace('</tool>', '\n</tool>')
    
    desc_tag = '</description>'
    if desc_tag in final_xml:
        final_xml = final_xml.replace(desc_tag, desc_tag + "\n"  + "\n" , 1)
    else:
        final_xml = re.sub(r'(<tool.*?>)', r'\1' + "\n" + "\n" , final_xml, count=1)

    print(final_xml)


if __name__ == "__main__":
    main()