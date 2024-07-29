#!/usr/bin/env python

# script that tries to split a Galaxy tool that covers multiple subparsers
# into separate tools

import sys
import re

import lxml.etree as ET


def parse_conditional(xml_file):
    # Parse the XML file
    tree = ET.parse(xml_file)
    root = tree.getroot()
    inputs = root.find("./inputs")
    # Find all conditional elements under the tool
    conditional = inputs.find("./conditional")
    assert (
        conditional.tag == "conditional"
    ), "First child of inputs needs to be a conditional"
    conditional_name = conditional.attrib["name"]

    select = conditional.find("*")
    assert select.tag == "param", "First child of the conditional needs to be a param"
    select_name = select.attrib["name"]

    # List to store values of param-options
    option_values = []
    for param_option in select.findall("./option"):
        option_values.append(param_option.attrib["value"])

    return conditional_name, select_name, option_values


def split(xml_file, cond_name, select_name, options):

    for option in options:
        tree = ET.parse(xml_file)
        root = tree.getroot()

        # replace conditional with the children of the corresponding when block
        inputs = root.find("./inputs")
        conditional = inputs.find(f'./conditional[@name="{cond_name}"]')
        index = list(inputs).index(conditional)
        when = inputs.find(
            f'./conditional[@name="{cond_name}"]/when[@value="{option}"]'
        )

        inputs.remove(conditional)
        for child in reversed(list(when)):
            inputs.insert(index, child)

        # command
        command = root.find("./command")
        new_command = []
        if_name = None
        for line in command.text.split("\n"):

            if_match = re.match(
                f"^( *)#if (?:str\()?\${cond_name}.{select_name}(?:\))? == [\"'](.*)[\"'].*",
                line,
            )
            if if_match:
                indent = len(if_match.group(1))
                if_name = if_match.group(2)
                continue
            if if_name is None:
                new_command.append(line)
                continue
            elif_match = re.match(
                f"^( {{{indent}}})#elif (?:str\()?\${cond_name}.{select_name}(?:\))? == [\"'](.*)[\"'].*",
                line,
            )
            if elif_match:
                if_name = elif_match.group(2)
                continue
            if re.match(f"^( {{{indent}}})#end if", line):
                if_name = None
                continue

            if if_name == option:
                new_command.append(line[indent:].replace(f"${cond_name}.", "$"))

            command.text = ET.CDATA("\n".join(new_command))
        # outputs
        outputs = root.find("./outputs")
        for output in outputs.getchildren():
            filter = output.find("./filter")
            if filter is not None:
                if not eval(
                    filter.text.replace(f'{cond_name}["{select_name}"]', f'"{option}"')
                ):
                    outputs.remove(output)
                else:
                    output.remove(filter)
        # test

        tests = root.find("./tests")
        for test in tests.getchildren():
            if test.find(f'.//param[@name="{select_name}"][@value="{option}"]') is None:
                tests.remove(test)
            else:
                conditional = test.find(f'./conditional[@name="{cond_name}"]')
                if conditional is not None:
                    conditional_index = list(test).index(conditional)
                    test.remove(conditional)
                    for child in conditional:
                        test.insert(conditional_index, child)
                param = test.find(f'./param[@name="{select_name}"]')
                if param is not None:
                    test.remove(param)

        # id, name
        root.attrib["id"] = f"{root.attrib['id']}_{option.replace('-', '_')}"
        root.attrib["name"] = f"{root.attrib['name']}: {option}"

        ET.indent(tree.getroot(), space="    ")
        tree.write(f"{option}.xml")


xml_file = sys.argv[1]
cond_name, select_name, options = parse_conditional(xml_file)
split(xml_file, cond_name, select_name, options)
