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
| `typespec.py` | one `TypeSpec` per accepted parameter type; drives widget, label and test value |
| `params.py` | Galaxy input widgets (text, select, boolean, column, repeat, type-selection conditionals) |
| `samples.py` | example value for a `TypeSpec` (used by the generated tests) |
| `docs.py` | docstring cleanup so the help text is valid reStructuredText |
| `tool.py` | assembles the tool XML (module/method repeat, root inputs) |
| `testmacros.py` | generates the planemo tests and their assertions |

Galaxy keeps the inputs of a tool and of its conditionals in one namespace, which
is why a SaQC parameter that would shadow a tool input is renamed (`setFlags`
`data` → `data_value`) and a column selection is suffixed (`_column`); both are
stripped again by `json_to_saqc_config.py`.

## Validators of the text inputs

Every text parameter carries at least one `regex` validator; where a parameter
is required an additional `empty_field` check rejects an empty form.  Galaxy
applies a validator with `re.match`, i.e. *a pattern has to anchor its own end*,
and it applies it to every element of a `multiple` text parameter separately —
which is why `empty_field` (that compares the value to `''`) is useless for
lists and a per-element pattern is used instead.

The patterns for time spans (`params._VALIDATORS`) are deliberately *shape*
checks and not a re-implementation of the pandas grammar: pandas owns its alias
vocabulary and changes it between releases (pandas 3 dropped `1M`, `1H`, `1T` …
and added multi-unit offsets such as `1h30min`), so a fixed vocabulary would
block valid input sooner or later.  They are anchored and case insensitive and
let SaQC report the precise pandas error.  Note that `FreqStr` is validated by
SaQC with `pd.Timedelta` and not with `to_offset`, so it uses the timedelta
pattern, unlike `OffsetStr`.
