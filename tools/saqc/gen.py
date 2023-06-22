import inspect
import re
import sys
from copy import deepcopy
from typing import get_args, get_origin, Any, Callable, Dict, ForwardRef, Literal, Optional, Sequence, Tuple, Union
from types import UnionType


from galaxyxml.tool import Tool
from galaxyxml.tool.parameters import (
    BooleanParam,
    Conditional,
    Configfiles,
    ConfigfileDefaultInputs,
    DataParam,
    DiscoverDatasets,
    IntegerParam,
    FloatParam,
    HiddenParam,
    Inputs,
    OutputCollection,
    OutputData,
    Outputs,
    Repeat,
    SelectParam,
    TextParam,
    ValidatorParam,
    When
)
import matplotlib as mpl
import numpy as np
import pandas as pd
import saqc
from saqc.core import DictOfSeries
from saqc.funcs.curvefit import FILL_METHODS
from saqc.funcs.drift import LinkageString 
from saqc.funcs.generic import GenericFunction
from saqc.funcs.interpolation import INTERPOLATION_METHODS
from saqc.lib.types import CurveFitter
from typing_inspect import is_callable_type, is_union_type

def _get_doc(doc_str: Optional[str]) -> str:
    if not doc_str:
        return ""
    doc_str = str(doc_str)
    doc_str = [x for x in doc_str.split("\n") if x != '']
    doc_str = doc_str[0]
    doc_str = doc_str.strip(" .,")
    return doc_str


def parse_docstring(method: Callable) -> Dict[str, str]:
    """
    parse sections from rst formatted doc string

    returns a mapping from section titles to section contents
    1st section title may be ''
    """

    docstring = method.__doc__
    if not docstring:
        return "", ""

    sections = {}

    # Regular expressions for sections and paragraphs
    section_pattern = r'^([^\S\n]*)(?P<title>\S.*?)(\n\1([=-])+\n)'

    # Extract sections and paragraphs
    section_matches = re.finditer(section_pattern, docstring, re.MULTILINE)

    for i, match in enumerate(section_matches):
        if i == 0 and match.start() > 0:
            sections[''] = docstring[:match.start()]
        else:
            sections[title] = docstring[end: match.start()]

        title = match.group('title')
        start = match.start()
        end = match.end()

    return sections

def parse_parameter_docs(sections: Dict[str, str]) -> Dict[str, str]:
    parameter_doc = {}
    parameters = sections.get("Parameters", "")
    parameter_pattern = r'^([\S\n]+)( : .*)?$'
    for line in parameters.splitlines():
        match = re.match(parameter_pattern, line)
        if match:
            parameter = match.group(1)
            parameter_doc[parameter] = []
        else:
            parameter_doc[parameter].append(line)
    for pd in parameter_doc:
        parameter_doc[pd] = "\n".join(parameter_doc[pd])
    return parameter_doc

def get_label_help(param_name, parameter_docs):

    parameter_doc = parameter_docs.get(param_name)
    if not parameter_doc:
        return param_name, ""
    label_split = parameter_doc.split("\n", maxsplit=1)
    label = label_split[0]
    help = ""
    if "." in label:
        label = label.split(".", maxsplit=1)[0]
        try:
            help = label.split(".", maxsplit=1)[1]
        except IndexError:
            pass
    if len(label_split) > 1:
        help += "\n" + label_split[1]
    return label.strip(), help.strip()


def get_modules() -> Tuple[str, 'module']:
    return inspect.getmembers(saqc.funcs, inspect.ismodule)


def get_methods(module):
    methods_with_saqc = []

    classes = inspect.getmembers(module, inspect.isclass)
    for name, cls in classes:
        if inspect.ismodule(cls):
            continue  # Skip modules in case there are any

        methods = inspect.getmembers(cls, inspect.isfunction)
        for method_name, method in methods:
            parameters = inspect.signature(method).parameters
            if 'self' in parameters:
                self_param = parameters['self']
                if self_param.annotation == "'SaQC'":
                    methods_with_saqc.append(method)
    return methods_with_saqc


def get_method_params(method, module):

    sections = parse_docstring(method)
    param_docs = parse_parameter_docs(sections)

    xml_params = []
    parameters = inspect.signature(method).parameters
    for param_name, param in parameters.items():

        # TODO check if *kwargs* really not needed
        if param_name in ['self', 'kwargs', 'store_kwargs', 'ax_kwargs']:
            continue
        annotation = param.annotation
        if annotation is inspect.Parameter.empty:
            raise ValueError(f"missing type annotation for {param_name}")
        annotation = eval(annotation)
        origin = get_origin(annotation)
        args = get_args(annotation)

        default = param.default

        value=""
        if param.default is not inspect.Parameter.empty:
            value = param.default

        label, help = get_label_help(param_name, param_docs)
        kwargs = {"label": label, "help": help, "space_between_arg": "="}

        if param.default is None:
            optional = True
        else:
            optional = False

        # remove None (we just determined if the parameter is optional)
        is_union = is_union_type(annotation)
        if is_union:
            args_wo_none = [a for a in args if a is not type(None)]
            if len(args_wo_none) == 1:
                annotation = args_wo_none[0]
            else:
                annotation = Union[tuple(args_wo_none)]
            origin = get_origin(annotation)
            args = get_args(annotation)

        # print(annotation, type(annotation), origin, args)
        if param_name in ["field", "target"]:
            if annotation != str:
                parent = Repeat(name=f"{param_name}_repeat", title=f"{param_name}(s)", min=1)
                xml_params.append(parent)
            else:
                parent = xml_params 
            parent.append(TextParam(argument = param_name, value=value, optional=optional, **kwargs))
        elif origin is None:
            if annotation == bool:
                xml_params.append(BooleanParam(argument = param_name, truevalue="", checked=default, **kwargs))
            elif annotation == str:
                xml_params.append(TextParam(argument = param_name, value=value, optional=optional, **kwargs))
            elif annotation == int:
                xml_params.append(IntegerParam(argument = param_name, value=value, optional=optional, **kwargs))
            elif annotation == float:
                xml_params.append(FloatParam(argument = param_name, value=value, optional=optional, **kwargs))
            elif (
                annotation == GenericFunction
                or annotation == CurveFitter
                or annotation == Any
                or annotation == slice
                or annotation == mpl.axes.Axes
            ):
                sys.stderr.write(f"Ignoring {annotation} simple parameter {param_name} ({method.__name__})\n")
                pass
            else:
                exit(f"Unknown simple parameter type {annotation}: {param_name} {method.__name__}")
        elif annotation == str | Tuple[str, str]: # window
            txt = TextParam(argument = param_name, value=value, optional=optional, **kwargs)
            # TODO make proper timedelta text
            txt.append(ValidatorParam(type="regex", text="[\dDW:]+(,[\dDW:]+)$", message="needs to be a single timedelta or two comma separated timedeltas"))
            xml_params.append(txt)
        elif annotation == int | Tuple[int, int]: # periods
            txt = TextParam(argument = param_name, value=value, optional=optional, **kwargs)
            txt.append(ValidatorParam(type="regex", text="[\d]+(,[\d]+)$", message="needs to be a single number or two comma separated numbers"))
            xml_params.append(txt)
        elif annotation == int | str and param_name in ["limit", "window"]:
            cond = Conditional(name = f"{param_name}_cond")
            options={}
            if optional:
                options['none'] = "None"
            options.update({"number": "number", "timedelta": "timedelta"})
            cond.append(SelectParam(argument=f"{param_name}_select", label=f"{param_name} input mode", options=options))
            if optional:
                cond.append(When(value="none"))
            when = When(value="number")
            kwargs_number = deepcopy(kwargs)
            kwargs_number["help"] = "Number of values"
            when.append(IntegerParam(argument = param_name, value=value, optional=optional, **kwargs_number))
            cond.append(when)
            when = When(value="timedelta")
            kwargs_delta = deepcopy(kwargs)
            kwargs_delta["help"] = "Temporal extensions (offset string)"
            txt = TextParam(argument = param_name, value=value, optional=optional, **kwargs_delta)
            txt.append(ValidatorParam(type="regex", text="TODO$", message="TODO"))
            # TODO regex: see `pandas.rolling` for more information
            when.append(txt)
            cond.append(when)
            xml_params.append(cond)
        elif annotation == float | str and param_name in ["cutoff", "freq"]:
            cond = Conditional(name=f"{param_name}_cond")
            options={}
            if optional:
                options['none'] = "None"
            if param_name == "cutoff":
                options.update({"number": "Give as multiple of sampling rate", "offset": "specify as offset"})
                cond.append(SelectParam(name=f"{param_name}_select", label=f"{param_name} input mode", options=options))
                if optional:
                    cond.append(When(value="none"))
                when = When(value="number")
                kwargs_number = deepcopy(kwargs)
                kwargs_number["help"] = "Multiple of sampling rate"
                when.append(FloatParam(argument = param_name, value=value, optional=optional, **kwargs_number))
                cond.append(when)
            elif param_name == "freq":
                options.update({"number": "Give as period length", "offset": "specify as offset"})
                cond.append(SelectParam(name=f"{param_name}_select", label=f"{param_name} input mode", options=options))
                if optional:
                    cond.append(When(value="none"))
                when = When(value="number")
                kwargs_number = deepcopy(kwargs)
                kwargs_number["help"] = "Multiple of sampling rate"
                when.append(FloatParam(argument = param_name, value=value, optional=optional, **kwargs_number))
                cond.append(when)
            else:
                exit(f"Unknown 'float | str' parameter {param_name}")
            when = When(value="offset")
            kwargs_delta = deepcopy(kwargs)
            kwargs_delta["help"] = "offset frequency string"
            txt = TextParam(argument = param_name, value=value, optional=optional, **kwargs_delta)
            txt.append(ValidatorParam(type="regex", text="TODO$", message="TODO"))
            # TODO regex: see `pandas.rolling` for more information
            when.append(txt)
            cond.append(when)
            xml_params.append(cond)
        elif (
            annotation == Literal['auto'] | float
            or annotation == Literal['auto'] | float | Callable
        ):
            cond = Conditional(name=f"{param_name}_cond")
            options={'auto': 'automatic', 'linear': 'linear'}
            if annotation == Literal['auto'] | float | Callable:
                options['custom'] = 'custom'
            cond.append(SelectParam(name=f"{param_name}_select", label=f"{param_name} mode", options=options))
            cond.append(When(value="auto"))
            linear_when = When(value="linear")
            txt = FloatParam(argument = param_name, value=value, optional=optional, **kwargs)
            cond.append(linear_when)
            if annotation == Literal['auto'] | float | Callable:
                custom_when = When(value="custom")
                txt = TextParam(argument = param_name, value=value, optional=optional, **kwargs)
                txt.append(ValidatorParam(type="regex", text="TODO$", message="TODO"))
                custom_when.append(txt)
                cond.append(custom_when)
            xml_params.append(cond)
        elif annotation == Literal['valid', 'complete'] | list:
            cond = Conditional(name=f"{param_name}_cond")
            options={'valid': 'valid', 'complete': 'complete', 'list': 'list', 'none': 'none'}
            cond.append(SelectParam(name=f"{param_name}_select", label=f"{param_name} mode", options=options, default=default))
            for option in options:
                when = When(value=option)
                if option == 'list':
                    txt = TextParam(argument = param_name, value=value, optional=optional, **kwargs)
                    # txt.append(ValidatorParam(type="regex", text="TODO$", message="TODO"))
                else:
                    when.append(HiddenParam(name=param_name, value="valid"))
                cond.append(when)
            xml_params.append(cond)
        #     sys.stderr.write(f"TODO Ignoring {annotation} parameter {param_name} ({method.__name__})\n")
        elif is_callable_type(annotation):
            # set default to "" (otherwise potentially 'cryptic' default is shown)
            # add default to help 
            kwargs["help"] += f"function {args} (default: {value})"
            txt = TextParam(argument = param_name, value="", optional=optional, **kwargs)
            # txt.append(ValidatorParam(type="regex", text="TODO$", message="TODO"))
            xml_params.append(txt)
        elif annotation == str | pd.Timedelta:
            kwargs["help"] += " see: https://pandas.pydata.org/docs/user_guide/timedeltas.html#parsing"
            txt = TextParam(argument = param_name, value=value, optional=optional, **kwargs)
            txt.append(ValidatorParam(type="regex", text="TODO$", message="TODO"))
            xml_params.append(txt)
        elif origin is Literal:
            options = dict([(o, o) for o in args])
            xml_params.append(
                SelectParam(argument = param_name, value=value, optional=optional, options=options, **kwargs)
            )
        elif (
            annotation == Sequence[ForwardRef('SaQC')] | dict['SaQC', str | Sequence[str]]
        ):
            sys.stderr.write(f"TODO Ignoring {annotation} parameter {param_name} ({method.__name__})\n")
        elif is_union and is_callable_type(args[0]) and args[1] == Literal['linear', 'exponential']:
            cond = Conditional(name=f"{param_name}_cond")
            options={'linear': 'linear', 'exponential': 'exponential', 'custom': 'custom'}
            cond.append(SelectParam(name=f"{param_name}_select", label="Model fucntion", options=options))
            cond.append(When(value="linear"))
            cond.append(When(value="exponential"))
            custom_when = When(value="custom")
            txt = TextParam(argument = param_name, value=value, optional=optional, **kwargs)
            # txt.append(ValidatorParam(type="regex", text="TODO$", message="TODO"))
            custom_when.append(txt)
            cond.append(custom_when)
            xml_params.append(cond)
        elif annotation == pd.Series | pd.DataFrame | DictOfSeries | list | np.ndarray:
            # TODO should be a list of fields
            sys.stderr.write(f"TODO Ignoring {annotation} parameter {param_name} ({method.__name__})\n")
        else:
            exit(f"Unknown parameter type {annotation}: {param_name} {method.__name__}")
    return xml_params


def get_methods_conditional(methods, module):
    method_conditional = Conditional(name = "method_cond", label="Method")
    method_select_options = []
    for method in methods:
        method_name = method.__name__
        method_doc = _get_doc(method.__doc__)
        if not method_doc:
            method_doc = method_name
        method_select_options.append((method_name, f"{method_name}: {method_doc}"))
    method_select = SelectParam(name="method_select", label="Method", options=dict(method_select_options))
    method_conditional.append(method_select)
    for method in methods:
        method_name = method.__name__
        method_doc = _get_doc(method.__doc__)
        method_when = When(value=method_name)
        try:
            for p in get_method_params(method, module):
                method_when.append(p)
        except ValueError as e:
            # TODO mark somehow
            sys.stderr.write(f"Skipping {method_name} in {module.__name__} due to {e}\n")
        method_conditional.append(method_when)

    return method_conditional

# overwrite command
command_override = """
'$__tool_directory__'/json_to_saqc_config.py '$param_conf' > config.csv &&
ln -s '$data' input.csv &&
saqc -c config.csv -d input.csv -o output.csv
"""
#   -c, --config PATH               path to the configuration file  [required]
#   -d, --data PATH                 path to the data file  [required]
#   -o, --outfile PATH              path to the output file
#   --scheme [float|simple|dmp|positional]
#                                   the flagging scheme to use
#   --nodata FLOAT                  nodata value
#   --log-level [DEBUG|INFO|WARNING]
#                                   set output verbosity

tool = Tool('SaQC', 'saqc', version="@TOOL_VERSION@+galaxy@VERSION_SUFFIX@", description="quality control pipelines for environmental sensor data", executable="saqc", macros=["macros.xml"], command_override=command_override, profile="22.01", version_command="python -c 'import saqc; print(saqc.__version__)'")
tool.help = "TODO"

tool.configfiles = Configfiles()
tool.configfiles.append(ConfigfileDefaultInputs(name="param_conf"))
inputs = tool.inputs = Inputs()
inputs.append(DataParam(argument="--data", format="csv", label="Input table"))

outputs = tool.outputs = Outputs()

outputs.append(OutputData(name="output", format="csv", from_work_dir="output.csv"))
plot_outputs = OutputCollection(name="plots", type="list", label="${tool.name} on ${on_string}: Plots")
plot_outputs.append(DiscoverDatasets(pattern="(?P<name>.*)\.png", ext="png"))
# plot_outputs.append(OutputFilter(text="TODO"))
outputs.append(plot_outputs)

modules = get_modules()

module_repeat = Repeat(name="methods_repeat", title="Methods")
inputs.append(module_repeat)
module_conditional = Conditional(name = "module_cond", label="Module")
module_select_options = []
for module_name, module in modules:
    module_doc = _get_doc(module.__doc__)
    if not module_doc:
        module_doc = module_name
    module_select_options.append((module_name, f"{module_name}: {module_doc}"))
module_select = SelectParam(name="module_select", label="saqc module", options=dict(module_select_options))
module_conditional.append(module_select)
for module_name, module in modules:
    module_when = When(value=module_name)
    methods = get_methods(module)
    methods_conditional = get_methods_conditional(methods, module)
    module_when.append(methods_conditional)
    module_conditional.append(module_when)
module_repeat.append(module_conditional)

print(tool.export())

# for module_name, module in get_modules():
#     saqc_methods = get_methods_with_saqc_argument(module)
#     for method in saqc_methods:
#         print(method.__name__)
#         parameters = inspect.signature(method).parameters
#         for param in parameters:
#             print("\t", param, parameters[param].annotation)
