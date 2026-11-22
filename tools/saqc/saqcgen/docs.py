"""Helpers to turn SaQC's ReStructuredText docstrings into Galaxy help texts.

Every public SaQC method is documented with a docstring that contains (at least)
a short summary and a ``Parameters`` section.  Galaxy wants a short ``label``
per parameter plus an optional ``help`` text, so this module implements:

* ``split_sections``      -- split a docstring into its RST sections
* ``parameter_docs``      -- the per-parameter descriptions of a method
* ``label_and_help``      -- cut a description into label + help text
* ``option_help``         -- short descriptions for ``Literal`` option values
"""

from __future__ import annotations

import re
from collections import OrderedDict
from typing import Dict, List, Mapping, Optional, Sequence, Tuple

__all__ = [
    "header_is_deprecated",
    "label_and_help",
    "option_help",
    "parameter_docs",
    "short_description",
    "see_also_list",
    "split_sections",
    "strip_rst_roles",
]

#: RST roles that SaQC uses in its docstrings and that Galaxy's RST parser does
#: not understand inside the generated help text.
_RST_ROLES = (
    ":math:",
    ":py:attr:",
    ":py:class:`Any`,",
    ":py:class:",
    ":py:func:",
    ":py:meth:",
)

#: a figure directive of the SaQC documentation, which points to the images
#: that are shipped inside the ``static/images`` directory of the tool
_FIGURE = re.compile(
    r"^\.\. figure::\s*(?:/resources/images/)?(?P<name>\S+)\s*$", re.MULTILINE
)

#: any role prefix in front of a backticked text, e.g. ``:ref:``
_RST_ROLE = re.compile(r":[a-zA-Z][\w.:\-]*:(?=`)")

#: a title followed by an underlined title (``Title`` / ``-----``)
_SECTION_TITLE = re.compile(
    r"^(?P<indent>[^\S\n]*)(?P<title>\S.*?)\n(?P=indent)[=-]+\n", re.MULTILINE
)

#: first line of a numpydoc parameter entry: ``name`` or ``name : type``
_PARAMETER_ENTRY = re.compile(r"^(?P<name>[a-zA-Z_][a-zA-Z0-9_]*)\s*(?::.*)?$")

#: an option description as used inside a parameter description, e.g.
#: ``* ``"standard"``: mean as expectation``
_OPTION_ENTRY = re.compile(r"[-*] [\"'`]+{option}[\"'`]+\s*:\s*([^.(]*)")


def strip_rst_roles(text: Optional[str]) -> str:
    """Remove RST roles that Galaxy cannot render."""
    if not text:
        return ""
    for role in _RST_ROLES:
        text = text.replace(role, "")
    text = _RST_ROLE.sub("", text)
    return text.replace("~saqc.SaQC.", "").replace("saqc.SaQC.", "")


def _fix_doctest(docstring: str) -> str:
    """Turn the ``doctest`` directives of SaQC into plain examples.

    The docstrings use ``.. doctest::`` to mark example code blocks, a
    directive that neither docutils (as used by ``planemo lint``) nor Galaxy
    know about.  The block itself is kept, it is just introduced by a generic
    literal block.
    """
    text = re.sub(r"\.\. doctest:: \w+.*", "Example::", docstring)
    return re.sub(r"\.\. doctest::$", "Example::", text, flags=re.MULTILINE)


def _fix_figures(docstring: str) -> str:
    """Point the ``figure`` directives at the images shipped with the tool."""
    return _FIGURE.sub(lambda match: f".. figure:: {match.group('name')}", docstring)


def _drop_plot_blocks(docstring: str) -> str:
    """Remove the ``plot`` directives of the SaQC documentation.

    They are interpreted by a sphinx extension that renders matplotlib code
    into a figure; the docutils based help renderer of Galaxy does not know the
    directive and the code is an example of the plotting, not of the method.
    """
    lines: List[str] = []
    inside = False
    for line in docstring.splitlines():
        if not inside and line.startswith(".. plot::"):
            inside = True
            continue
        if inside:
            if not line.strip() or line[:1].isspace():
                continue
            inside = False
        lines.append(line)
    return "\n".join(lines)


def split_sections(docstring: Optional[str]) -> "OrderedDict[str, str]":
    """Split a docstring into ``{section title: section body}``.

    The text before the first section title is stored under the empty title,
    which is also present (and empty) when the docstring starts with a title.
    """
    if not docstring:
        return OrderedDict()

    docstring = _fix_doctest(_fix_figures(_drop_plot_blocks(docstring)))
    titles = list(_SECTION_TITLE.finditer(docstring))
    if not titles:
        return OrderedDict({"": docstring.strip()})

    sections: "OrderedDict[str, str]" = OrderedDict()
    preamble = docstring[: titles[0].start()].strip()
    if preamble:
        sections[""] = preamble
    elif titles[0].start() == 0:
        sections[""] = ""

    for index, match in enumerate(titles):
        body_start = match.end()
        body_end = titles[index + 1].start() if index + 1 < len(titles) else None
        sections[match.group("title").strip()] = docstring[body_start:body_end].strip()

    return OrderedDict((k, v) for k, v in sections.items() if v or k == "")


def parameter_docs(sections: Mapping[str, str]) -> Dict[str, str]:
    """Extract ``{parameter name: description}`` from a ``Parameters`` section.

    Parameter entries start in the first column, everything else is treated as
    the continuation of the previous entry.
    """
    parameters_text = sections.get("Parameters", "")
    if not parameters_text:
        return {}

    entries: Dict[str, list] = OrderedDict()
    current: Optional[str] = None
    for line in parameters_text.splitlines():
        stripped = line.strip()
        starts_entry = not line.startswith(("    ", "\t")) and bool(stripped)
        match = _PARAMETER_ENTRY.match(stripped) if starts_entry else None
        if match:
            current = match.group("name")
            entries[current] = [stripped]
        elif current is not None:
            entries[current].append(stripped)

    return {
        name: _strip_parameter_prefix(name, lines)
        for name, lines in entries.items()
    }


def _strip_parameter_prefix(name: str, lines: Sequence[str]) -> str:
    """Remove the ``name : type --`` prefix from the first documentation line."""
    if not lines:
        return ""
    first = lines[0]
    # "name : type -- description" (older SaQC docstrings)
    without_prefix = re.sub(
        rf"^\s*{re.escape(name)}\s*:\s*[^-\n]+?\s*--\s*", "", first, count=1
    )
    if without_prefix == first and ":" in first:
        # "name : type"
        without_prefix = re.sub(rf"^\s*{re.escape(name)}\s*:\s*", "", first, count=1)
    if without_prefix.startswith(name):
        # "name description"
        without_prefix = re.sub(rf"^\s*{re.escape(name)}", "", without_prefix, count=1)

    return "\n".join([without_prefix.strip()] + [line.strip() for line in lines[1:]]).strip()


def option_help(
    param_name: str, options: Sequence[str], docs: Mapping[str, str]
) -> Dict[str, str]:
    """Short descriptions for the options of a ``Literal`` parameter.

    Options are described with a list item in the parameter description that
    starts with the quoted option name followed by a colon, e.g.::

        - ``"standard"``: mean as expectation
    """
    text = docs.get(param_name, "")
    for role in (":py:attr:", ":py:class:`Any`,", ":py:class:"):
        text = text.replace(role, "")

    descriptions: Dict[str, str] = {}
    lines = text.splitlines()
    for option in options:
        pattern = re.compile(_OPTION_ENTRY.pattern.format(option=re.escape(option)))
        for line in lines:
            match = pattern.search(line)
            if match:
                descriptions[option] = f"{option}: {match.group(1).strip()}"
                break
    return descriptions


def label_and_help(param_name: str, docs: Mapping[str, str]) -> Tuple[str, str]:
    """Derive a short Galaxy label and a help text from a parameter description.

    The first sentence becomes the label, everything after it the help text.
    Very long single sentences are split at a comma instead, so that the label
    stays readable in the Galaxy UI.
    """
    text = docs.get(param_name, "").strip()
    if not text:
        return param_name, ""

    text = text.replace(":py:attr:", "").replace(":py:class:", "").strip()

    # Older docstrings repeat the type on the first line of the description,
    # some even prefix it with a colon (see SaQC merge requests 891 and 887).
    lines = text.splitlines()
    type_prefixes = ("`Any`", "bool", "callable", "float", "int", "`SaQCFields`", "str", "{")
    if lines and lines[0].startswith(type_prefixes):
        lines = lines[1:]
    text = re.sub(r"^[:]+\s*", "", "\n".join(lines)).strip()
    if not text:
        return param_name, ""

    text = re.sub(r"pd\.([a-zA-Z0-9_.]+)", r"pandas.\1", text, flags=re.IGNORECASE)
    text = re.sub(r"np\.([a-zA-Z0-9_.]+)", r"numpy.\1", text, flags=re.IGNORECASE)

    paragraphs = re.split(r"\n\s*\n", text, maxsplit=1)
    first_paragraph = paragraphs[0].replace("\n", " ").strip()
    remaining_paragraphs = paragraphs[1].strip() if len(paragraphs) > 1 else ""

    sentences = re.split(r"(\.\s+)", first_paragraph, maxsplit=1)
    if len(sentences) == 1 and not remaining_paragraphs and len(first_paragraph) > 80:
        parts = first_paragraph.split(",")
        if len(parts) > 2:
            return _finish_label(parts[0] + "," + parts[1]), _finish_help(",".join(parts[2:]))

    label = sentences[0].strip()
    if not label:
        return param_name, ""

    rest_of_first_paragraph = "".join(sentences[1:]).strip()
    if rest_of_first_paragraph and remaining_paragraphs:
        help_text = rest_of_first_paragraph + "\n\n" + remaining_paragraphs
    else:
        help_text = rest_of_first_paragraph or remaining_paragraphs

    return _finish_label(label), _finish_help(help_text)


def _finish_label(label: str) -> str:
    return label.strip(" .")


def _finish_help(help_text: str) -> str:
    help_text = " ".join(help_text.split("\n")).strip()
    help_text = re.sub(r"^[,.:;-]+\s*", "", help_text).strip()
    return help_text.rstrip(".")


def see_also_list(text: str) -> str:
    """Turn SaQC's ``name : description`` listing into a definition list.

    The "See also" sections of the SaQC docstrings list ``name : description``
    pairs, some of them continued on an indented line.  As is, docutils reads
    the indented continuation of a paragraph as an error, so the entries are
    turned into a definition list (term plus indented body) instead.
    """
    entries: List[List[str]] = []
    for line in text.splitlines():
        if not line.strip():
            continue
        if line[:1].isspace() and entries:
            entries[-1][1] = f"{entries[-1][1]} {line.strip()}".strip()
            continue
        term, _, description = line.partition(" : ")
        entries.append([term.strip(), description.strip()])
    return "\n\n".join(f"{term}\n    {description}" for term, description in entries)


def short_description(docstring: Optional[str]) -> str:
    """First line of a docstring, used as the tool selection entry."""
    if not docstring:
        return ""
    first_line = strip_rst_roles(docstring).splitlines()[0]
    return first_line.strip(" .,")


def header_is_deprecated(docstring: Optional[str]) -> bool:
    """True if the docstring header (the text before the first section) is
    marked with a ``.. deprecated::`` directive."""
    if not docstring:
        return False
    return ".. deprecated::" in split_sections(docstring).get("", "").lower()


def clean_help_text(docstring: Optional[str]) -> str:
    """Normalise a docstring for the Galaxy help section."""
    if not docstring:
        return ""
    return _fix_doctest(strip_rst_roles(docstring))
