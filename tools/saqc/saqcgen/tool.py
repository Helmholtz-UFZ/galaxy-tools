"""Generation of the Galaxy tool wrapper (``saqc.xml``).

The tool exposes the complete SaQC method collection as one repeat block: for
every method the user selects a module, a method and the method's parameters,
and the tool turns that selection into a SaQC configuration file (see
``json_to_saqc_config.py``).
"""

from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import Any, Dict, List

from galaxyxml.tool import Tool
from galaxyxml.tool.parameters import (
    Conditional,
    ConfigfileDefaultInputs,
    Configfiles,
    DataParam,
    DiscoverDatasets,
    HiddenParam,
    Inputs,
    OutputCollection,
    OutputData,
    OutputFilter,
    Outputs,
    Repeat,
    TextParam,
    When,
)
from lxml import etree

from . import docs, params
from .introspect import COLUMN_SUFFIX, Introspection

__all__ = ["generate_tool"]

logger = logging.getLogger(__name__)

#: names of the inputs this module defines itself.  A method parameter may use
#: the same name (Galaxy keeps the inputs of nested conditionals apart from the
#: inputs of the tool), but the two are hard to tell apart in a bug report, so
#: the generator reports it.
TOOL_INPUT_NAMES = frozenset(
    {
        "data",
        "method_cond",
        "method_select",
        "methods_repeat",
        "module_cond",
        "module_select",
        "no_modules_found",
        "param_conf",
        "run_test_mode",
    }
)

#: the shell command of the tool
COMMAND = """
#set $first_data_file = $data[0]
  '$__tool_directory__'/json_to_saqc_config.py '$param_conf' '$first_data_file' > config.csv
#if str($run_test_mode) == "false":
  &&
  #for $i, $d in enumerate($data)
    ln -s '$d' '${i}.csv' &&
  #end for
  saqc --config config.csv
  #for $i, $d in enumerate($data)
    --data '${i}.csv'
  #end for
  --outfile output.csv
#end if
"""

#: the characters that underline the module and method titles in the help
MODULE_RULE = "="
METHOD_RULE = "-"

MODULE_SELECT = "Select SaQC module"
METHOD_SELECT = "Method"


@dataclass
class _Module:
    """One SaQC module and the input/help it contributes to the tool."""

    name: str
    obj: Any
    methods: List[Any]
    introspection: Introspection

    @property
    def short_description(self) -> str:
        return docs.short_description(self.obj.__doc__) or self.name

    @property
    def help(self) -> str:
        return docs.clean_help_text(self.obj.__doc__)


def generate_tool(introspection: Introspection) -> str:
    """Render the tool XML as a string."""
    tool = Tool(
        "SaQC",
        "saqc",
        version="@TOOL_VERSION@+galaxy@VERSION_SUFFIX@",
        description="quality control pipelines for environmental sensor data",
        executable="saqc",
        macros=["macros.xml", "test_macros.xml"],
        command_override=[COMMAND],
        profile="22.01",
        version_command="python -c 'import saqc; print(saqc.__version__)'",
    )
    tool.help = (
        "This tool provides access to SaQC functions for quality control of "
        "time series data. Select a module and method, then configure its "
        "parameters.\n"
    )

    tool.configfiles = Configfiles()
    tool.configfiles.append(ConfigfileDefaultInputs(name="param_conf"))

    inputs = tool.inputs = Inputs()
    inputs.append(
        DataParam(
            argument="--data", format="csv", multiple=True, label="Input table(s)"
        )
    )
    inputs.append(HiddenParam(name="run_test_mode", value="false"))

    method_repeat = Repeat(
        name="methods_repeat", title="Methods (add multiple QC steps)"
    )
    inputs.append(method_repeat)

    modules = _modules(introspection)
    if modules:
        method_repeat.append(_module_selection(modules))
        for module in modules:
            tool.help += (
                f"\n{module.name}\n{MODULE_RULE * len(module.name)}\n\n"
                f"{module.help}\n\n{_methods_help(module)}\n"
            )
    else:
        method_repeat.append(
            TextParam(name="no_modules_found", type="text", value="No SaQC modules found.")
        )

    tool.help = docs.strip_rst_roles(tool.help)
    tool.help = tool.help.replace("SaQC", "SaQC [#saqcurl]_", 1) + "\n@SAQCLINKS@"

    _warn_about_input_names(introspection, modules)
    _add_outputs(tool)
    _allow_special_characters(tool)
    return tool.export()


def _allow_special_characters(tool: Tool) -> None:
    """Turn Galaxy's command line sanitization off for this tool.

    Galaxy replaces the characters it cannot put on a command line with
    ``__dq__``, ``__ob__``, ``__cn__`` and friends (and anything it does not
    know with ``X``) in *every* value of the tool state -- including the values
    written into the ``<configfiles>`` JSON, which is the only place where the
    parameters of this tool end up.  Without this, a parameter value such as
    ``[\"filter\"]`` reaches the configuration file as
    ``__ob____dq__filter__dq____cb__`` and SaQC gets a string where it needs a
    list.

    Nothing of the sort can reach the command line of this tool: it only
    interpolates the dataset paths and the name of the parameter file.
    """
    tool.append(etree.Element("options", sanitize="false"))


def _warn_about_input_names(
    introspection: Introspection, modules: List[_Module]
) -> None:
    """Report parameter names that are easy to confuse with a tool input.

    Two names cannot be represented faithfully: one that ends like the suffix of
    a column selection (``json_to_saqc_config.py`` strips it) and one that is
    the name of an input of the tool itself (a legal tool, but the two inputs
    are hard to tell apart in a bug report).
    """
    shadowed = set()
    suffixed = set()
    for module in modules:
        for method in module.methods:
            for plan in introspection.parameters(method, module.obj):
                name = params.input_name_for(plan)
                if name.endswith(COLUMN_SUFFIX):
                    suffixed.add(f"{module.name}.{method.__name__}({plan.name}=...)")
                if name in TOOL_INPUT_NAMES:
                    shadowed.add(f"{module.name}.{method.__name__}({plan.name}=...)")
    if shadowed:
        logger.warning(
            "these SaQC parameters are named like an input of the tool: %s",
            ", ".join(sorted(shadowed)),
        )
    if suffixed:
        logger.warning(
            "these SaQC parameters end with '%s', which the configuration "
            "script reads as a column selection: %s",
            COLUMN_SUFFIX,
            ", ".join(sorted(suffixed)),
        )


def _modules(introspection: Introspection) -> List[_Module]:
    """All modules that expose at least one method that can be displayed."""
    modules: List[_Module] = []
    for module_name, module_obj in introspection.modules():
        if introspection.is_deprecated(module_obj):
            continue
        methods = [
            method
            for method in introspection.methods(module_obj)
            if introspection.skip_reason(method, module_obj) is None
        ]
        if methods:
            modules.append(_Module(module_name, module_obj, methods, introspection))
    return modules


def _module_selection(modules: List[_Module]) -> Conditional:
    options = {module.name: f"{module.name}: {module.short_description}" for module in modules}
    conditional = Conditional(name="module_cond")
    conditional.append(params.select_widget("module_select", MODULE_SELECT, options))
    for module in modules:
        when = When(value=module.name)
        when.append(_method_selection(module.introspection, module))
        conditional.append(when)
    return conditional


def _method_selection(introspection: Introspection, module: _Module) -> Conditional:
    options: Dict[str, str] = {}
    conditional = Conditional(name="method_cond")
    for method in module.methods:
        method_name = method.__name__
        options[method_name] = (
            f"{method_name}: {docs.short_description(method.__doc__) or method_name}"
        )

    conditional.append(params.select_widget("method_select", METHOD_SELECT, options))
    for method in module.methods:
        when = When(value=method.__name__)
        plans = introspection.parameters(method, module.obj)
        when.extend([params.build(plan) for plan in plans])
        conditional.append(when)
    return conditional


def _methods_help(module: _Module) -> str:
    return "".join(_method_help(module.name, method) for method in module.methods)


def _method_help(module_name: str, method) -> str:
    sections = docs.split_sections(method.__doc__)
    sections.pop("Parameters", None)
    sections.pop("Returns", None)

    body = ""
    for title, text in sections.items():
        if title.strip().lower() == "see also":
            text = docs.see_also_list(text)
        if title:
            body += f"\n{title}\n``````````\n\n{text}\n"
        else:
            body += f"\n{text}\n"
    title = f"{module_name}.{method.__name__}"
    return f"\n\n{title}\n{METHOD_RULE * len(title)}\n\n{body}\n"


def _add_outputs(tool: Tool) -> None:
    outputs = tool.outputs = Outputs()
    outputs.append(
        OutputData(
            name="output",
            format="csv",
            from_work_dir="output.csv",
            label="${tool.name} on ${on_string}: Processed Data",
        )
    )

    plots = OutputCollection(
        name="plots",
        type="list",
        label="${tool.name} on ${on_string}: Plots (if any generated)",
    )
    plots.append(
        DiscoverDatasets(pattern=r"(?P<name>.*)\.png", ext="png", visible=True)
    )
    plots.append(
        OutputFilter(
            text=(
                "any( r['module_cond']['module_select'] == 'tools' and "
                "r['module_cond']['method_cond']['method_select'] == 'plot' "
                "for r in methods_repeat)"
            )
        )
    )
    outputs.append(plots)

    optimized_configs = OutputCollection(
        name="optimized_configs",
        type="list",
        label=(
            "${tool.name} on ${on_string}: Optimized Configurations "
            "(if any calibratePipeline step generated one)"
        ),
    )
    # calibratePipeline writes its logs into the folder it is given (the wrapper
    # passes optisaqc_<n>), so the configs have to be picked up with a recursive
    # walk; match_relative_path makes the pattern see the folder as well
    optimized_configs.append(
        DiscoverDatasets(
            pattern=r"(?P<name>optisaqc_\d+)/config\.csv",
            ext="csv",
            recurse="true",
            match_relative_path="true",
            visible=True,
        )
    )
    optimized_configs.append(
        OutputFilter(
            text=(
                "any( r['module_cond']['module_select'] == 'optisaqc' and "
                "r['module_cond']['method_cond']['method_select'] == "
                "'calibratePipeline' for r in methods_repeat)"
            )
        )
    )
    outputs.append(optimized_configs)
    outputs.append(
        OutputData(
            name="config_out",
            format="txt",
            from_work_dir="config.csv",
            label="${tool.name} on ${on_string}: Generated SaQC Configuration",
        )
    )
