# wf-human-variation

`wf-human-variation` is a Nextflow DSL2 workflow for human Oxford Nanopore
whole-genome variant analysis. It supports small variant, structural variant,
copy-number, STR, modified-base, coverage, reporting, and export workflows.

## Documentation

The canonical technical documentation is now the Sphinx documentation in
[`docs/`](docs/index.rst). The previous generated Markdown fragments under
`docs/01_*.md` through `docs/12_*.md` have been deprecated and removed.

Build locally with:

```sh
python -m sphinx -W -b html docs docs/_build/html
```

Read the Docs is configured by `.readthedocs.yaml`.

## Maintainer Contract

Documentation is part of the development contract for this fork. Changes to
workflow behavior, parameters, outputs, tests, or operational assumptions must
update the Sphinx documentation in the same change set.

This repository's documentation is scoped to `wf-human-variation` only.
