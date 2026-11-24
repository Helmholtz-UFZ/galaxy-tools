# SaQC tools

Galaxy wrappers for [SaQC](https://git.ufz.de/rdm-software/saqc) (System for
automated Quality Control).

| File | Origin |
| --- | --- |
| `saqc.xml` | **generated** — do not edit by hand |
| `test_macros.xml` | **generated** — do not edit by hand |
| `macros.xml` | hand maintained (version tokens, help macros, container, plot tests) |
| `saqc_executor.xml` | hand maintained (runs SaQC with a configuration file) |
| `json_to_saqc_config.py` | hand maintained (Galaxy form values → SaQC argument file) |
| `test-data/` | hand maintained (inputs and the expected `out.csv`) |
| `saqcgen/` | the generator, see below |

`saqc.xml` has one input form per SaQC method (`saqc.funcs.<module>.<method>`),
`test_macros.xml` has one planemo test per method variant. Both are produced from
the docstrings and type annotations of the *installed* SaQC, so the generated
files always belong to one specific SaQC release.

## Generating

The generator needs a Python environment with SaQC installed (plus `galaxyxml`)
and **must be run with the SaQC release that `macros.xml` pins**:

```bash
cd tools/saqc
python -m saqcgen --write     # rewrite saqc.xml and test_macros.xml
```

`--write` reports a warning if the installed SaQC differs from `@TOOL_VERSION@`
in `macros.xml`; regenerate in an environment of the pinned version instead of
accepting the warning.

Other modes:

```bash
python -m saqcgen --generate-tool   > saqc.xml          # print the tool XML
python -m saqcgen --generate-tests  > test_macros.xml   # print the tests
python -m saqcgen --check                               # rc != 0 if stale
python -m saqcgen --output-dir /tmp/x --write           # write elsewhere
python -m saqcgen --help
```

`--check` compares the committed files with what the generator would write, so it
is suitable for CI. `--output-dir` is useful when comparing two environments.

## Verifying a change

```bash
cd tools/saqc
python -m saqcgen --check
planemo lint saqc.xml saqc_executor.xml
planemo test --conda_auto_install saqc.xml saqc_executor.xml
python -m flake8 saqcgen json_to_saqc_config.py
```

`planemo test` runs one Galaxy job per generated test (around 40 minutes). The
expected `test-data/out.csv` is produced by the pinned SaQC, so it has to be
regenerated whenever the pinned version changes — with *that* SaQC version, never
by editing the numbers:

```bash
cd tools/saqc/test-data
saqc -c config.txt -d data.csv maint.csv -o out.csv   # check the tool command
```

## Updating to a new SaQC release

1. Bump `@TOOL_VERSION@` (and `@VERSION_SUFFIX@` for a wrapper-only change) in
   `macros.xml`.
2. Create an environment with the new release, e.g. `mamba create -n saqc210 -c
   conda-forge -c bioconda saqc=2.10.0 galaxyxml`.
3. `python -m saqcgen --write` in that environment and read `git diff` — new,
   removed and re-typed methods show up here.
4. Update `json_to_saqc_config.py` if the SaQC call syntax changed, adjust
   `test-data/config.txt`, regenerate `test-data/out.csv` with the new release.
5. Verify as above.

`saqcgen` is written against the type system of SaQC ≥ 2.10 (`saqc.lib.types`,
`SaQCColumns`, `typing` aliases); older releases are not supported.

## Layout of `saqcgen`

| Module | Responsibility |
| --- | --- |
| `cli.py` | argument parsing, `--write`/`--check`, version warning |
| `introspect.py` | imports `saqc.funcs`, reads signatures and annotations, decides which parameters become inputs |
| `typespec.py` | one `TypeSpec` per accepted parameter type; drives widget, type label and test value |
| `params.py` | Galaxy input widgets (text, select, boolean, column, repeat, type-selection conditionals) |
| `samples.py` | example value for a `TypeSpec` (used by the generated tests) |
| `docs.py` | docstring cleanup and conversion of the parameter help to HTML |
| `tool.py` | assembles the tool XML (module/method repeat, root inputs) |
| `testmacros.py` | generates the planemo tests and their assertions |

Galaxy keeps the inputs of a tool and of its conditionals apart, so a SaQC
parameter keeps its name; only a column selection is suffixed (`_column`), so
`json_to_saqc_config.py` can tell a column of the input table (which it has to
translate to a column name) from a plain value.  A parameter that is named like
an input of the tool (`setFlags(data=...)` next to the `data` dataset) is
reported by the generator, because the two are hard to tell apart in a bug
report.

## Validators of the text inputs

Every text parameter carries at least one `regex` validator; where a parameter
is required an additional `empty_field` check rejects an empty form.  Galaxy
applies a validator with `re.match`, i.e. *a pattern has to anchor its own end*.
`empty_field` compares the value to `''` and takes no options, so a parameter
that is allowed to stay empty gets a pattern with an `(^$)|(...)` alternative
instead.

Galaxy has no multi-value `text` input: `multiple="true"` is silently ignored
for `type="text"` and the value arrives as one string (measured against Galaxy
26.1).  The three parameters that SaQC declares as `list[str]`
(`calibratePipeline.problems`, `calibratePipeline.problem_labels` and
`tools.plot.history`) are therefore plain text fields that ask for a list in the
syntax of the SaQC configuration file, e.g. `["filter", "spikes"]` —
`json_to_saqc_config.py` passes a value that starts with `[` through unchanged.
`tools.plot.history` also accepts a single string (`valid`).

The patterns for time spans (`params._VALIDATORS`) are deliberately *shape*
checks and not a re-implementation of the pandas grammar: pandas owns its alias
vocabulary and changes it between releases (pandas 3 dropped `1M`, `1H`, `1T` …
and added multi-unit offsets such as `1h30min`), so a fixed vocabulary would
block valid input sooner or later.  They are anchored and case insensitive and
let SaQC report the precise pandas error.  Note that `FreqStr` is validated by
SaQC with `pd.Timedelta` and not with `to_offset`, so it uses the timedelta
pattern, unlike `OffsetStr`.

## Special characters in the parameters

The tool writes its parameters into the JSON of `<configfiles>`, so they never
reach the command line.  Galaxy does not care and replaces the characters it
cannot put on a command line in *every* value of the tool state (see
`lib/galaxy/security/object_wrapper.py`): `["filter"]` arrives as
`__ob____dq__filter__dq____cb__`, `#` as `__pd__`, a line break as `__cn__`,
and every character it does not know as `X`.  `json_to_saqc_config.py` would
have to decode all of that, and the `X` replacement cannot be undone.

`saqcgen/tool.py` therefore emits `<options sanitize="false"/>`, which turns the
encoding off for this tool.  It is safe here: the command interpolates only
dataset paths and the name of the parameter file, everything else is read from
the JSON.  A tool that interpolates free text into its command line must not do
this.

## Column pickers

A SaQC parameter that names a column (`SaQCFields`, `SaQCColumns`) becomes a
Galaxy `data_column` input with `data_ref="data"` and `use_header_names="true"`,
so Galaxy labels the choices with the header of the input table (`c3: level_raw`)
instead of the bare index.  Galaxy submits the index either way (`c3` -> `3`), so
nothing else changes.

Galaxy only reads the header of a *single* dataset (or of a dataset collection):
the tool's `data` input holds several tables (`multiple="true"`), so Galaxy falls
back to `Column: 3`.  The attribute is inert in that case -- it costs nothing and
starts working as soon as the picker refers to a single table (a Galaxy fix for
the list case would be enough, the option values stay the same).

## Plots

A `tools.plot` step saves a figure into the working directory of the job, which
the `plots` output collection then picks up (`discover_datasets` on `*.png`).
The file name is *not* asked for: `path` is what `SaQC.plot` uses to switch
between an interactive window (`path=None`, useless without a display) and
saving a figure, so it is plumbing, not an analysis parameter.

`json_to_saqc_config.py` therefore writes `path="plot_<n>"` for the n-th plot
step (`saqcgen/introspect.py` lists `path` in `WRAPPER_PARAMETERS`, so the input
is not rendered at all).  Every plot step gets its own file, so two steps cannot
overwrite each other -- the collection holds `plot_1`, `plot_2`, ...; rename the
datasets in the history if you want telling names.

## calibratePipeline

`optisaqc.calibratePipeline` optimizes a pipeline of problems against a
supervised field.  It has two ways of handing the result back: it registers the
optimized pipeline as a new method of the in-memory `SaQC` object under `name`
(which no later step of a Galaxy run can call), and it dumps it as a config file
below `log_path` when `log_config` is set.  Only the second one is visible after
the job, so the wrapper always takes it:

* `log_path`, `log_config` and `log_pop` are in `WRAPPER_PARAMETERS`, so they are
  not rendered, and `json_to_saqc_config.py` writes `log_config=True`,
  `log_pop=False` and `log_path="optisaqc_<n>"` for the n-th calibrating step.
  SaQC needs a *folder* to log into, so the number keeps two steps apart.
* The `optimized_configs` output collection discovers
  `optisaqc_\d+/config.csv` below the working directory (`recurse="true"` plus
  `match_relative_path="true"`, because the pattern has to see the folder).  Its
  filter only creates it when a `calibratePipeline` step is configured, so the
  other tests keep counting two outputs.

`log_pop` is deliberately off: it writes a population dump per problem into the
same folder, and nothing collects those files.

Note that SaQC 2.10 aborts this method for several problem classes with
`ValueError: cannot reshape array of size 0 into shape (1,)` (the score line of a
generation without a single feasible individual) or
`AttributeError: 'NaTType' object has no attribute 'resolution_string'` (a problem
that scales a frequency parameter); `problems=["filter"]` is the one the test in
`macros.xml` uses.  `problem_labels` takes the *labels* of earlier flagging
steps, and SaQC labels a call after the method name unless a `label` is given,
so `["flagRange"]` refers to a preceding `flagRange` step.  Both parameters are
single line text fields that take a list in the syntax of the SaQC configuration
file (see *Validators of the text inputs*).

## Help texts

Galaxy renders the `help` attribute of a parameter as **HTML** (the `default`
profile of its `v-sanitize-html` directive, `FormElement.vue`); the
`restructuredtext`/`markdown` formats are only honoured for the `help` element
of the tool itself.  (A `help_format` attribute on a `param` is read by
`ToolParameter` but is not part of `galaxy.xsd`, so it does not pass the schema
check of the ToolShed.)

The SaQC docstrings are reStructuredText, so `docs.py` converts the part that
Galaxy would otherwise show as source: inline literals (``literal`` as well as
the single-backtick spelling `literal` SaQC uses) become `<code>`, bullet lists
become `<ul>`/`<li>` and the blocks of a description are separated by `<br>`.
Labels and option texts are rendered as plain text, so they get the markup
stripped instead.

Dangling footnote references (`See [1] for details`) are dropped from a
parameter help: the footnotes themselves are defined in the `References`
section of the method, which is part of the tool help, not of the description of
a single parameter.  Array indices such as `t[k][0]` are left alone.

## Labels of the type selection

A SaQC parameter that accepts several input formats is entered as a
conditional with one option per format.  The option text is built by
`typespec.friendly_name`: a short, non technical term followed by the SaQC type
hint in parentheses, e.g. `Sampling Frequency (OffsetStr)` or
`Time Duration (pandas.Timedelta)`.  The term never exceeds three words, so the
dropdown stays readable, and the hint keeps the label findable for someone
reading the SaQC documentation (`pd.` is expanded, a constrained number such as
`(Int >= 1)` is reduced to `int`, because the bounds are enforced by the input).
