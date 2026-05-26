# wf-human-variation

`wf-human-variation` is a Nextflow DSL2 workflow for human Oxford Nanopore
whole-genome variant analysis. It supports small variant, structural variant,
copy-number, STR, modified-base, coverage, reporting, and export workflows.

## Branch Stewardship

The `humvar3` branch is maintained by Mnemosyne Biosciences as the
Poikilognostikon-oriented fork of `epime-labs/wf-human-variation`.

This workflow has been adapted to run inside Poikilognostikon, where execution
is coordinated by Poikilognostikon's runtime manifest, artefact-ingress,
scheduling, and provenance model. Workflow-level behavior and documentation
remain scoped to `wf-human-variation`; Poikilognostikon orchestration and
integration design are maintained in the Poikilognostikon repository.

Bounded `humvar3` work must write task provenance into the shared manifest via
`gnostikon-workflow-control`, including tool versions, container digests,
command arguments, input checksums, task status, and output artefacts.
Runtime containers are pinned with immutable OCI digests rather than SHA-like
tags; the source tag to digest resolution is part of manifest provenance.

Tool customisation on `humvar3` uses structured allowlisted option objects such
as `sniffles_options`, `modkit_options`, and `spectre_options`; legacy
free-form `*_args` shell pass-throughs are rejected.

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

This `humvar3` branch is maintained alongside
`../gnostikon-workflow-control` and `../poikilognostikon`. Runtime-controller
changes, dynamic-ingress assumptions, optional-input semantics, and migration
records should be updated in parallel across the affected repositories.
Stable controller identity is `sample_id`; `project`, `flowcell`, and `run_id`
are optional context. `--sample_name` and `meta.alias` remain display/output
labels for current workflow compatibility.
