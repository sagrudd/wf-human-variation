Dependencies
============

Runtime Dependency Policy
-------------------------

``humvar3`` has no maintained local Python package manifest for workflow
runtime dependencies. Python helpers run inside the pinned runtime containers
declared in ``base.config``. The only local requirements file is
``docs/requirements.txt``, which is scoped to Sphinx documentation builds.

Report-only Python dependencies are not part of the maintained workflow
surface. Do not add dependencies such as ``ezcharts``, ``dominate``, ``bokeh``,
or browser/report layout libraries unless a future non-report task documents a
specific retained runtime purpose.

Retained Python Dependencies
----------------------------

The retained Python helpers currently use:

* ``pandas`` and ``numpy`` for machine-readable metrics, coverage summaries,
  downsampling decisions, and STR content extraction;
* ``pysam`` for BAM/CRAM/reference validation and STR content extraction;
* ``natsort`` for BED sanitisation.

These dependencies support validation or machine-readable artefacts. They must
not be treated as report dependencies merely because the old report generators
also used tabular metrics.

Container References
--------------------

Runtime containers are pinned by immutable OCI digest in ``base.config``.
The inherited containers may still contain packages that are no longer used by
``humvar3`` after report and browser removal. This repository does not contain
the container build recipes needed to safely rebuild those images in place.

When container contents are changed, update the relevant digest in
``base.config`` and record the source tag to digest mapping through the shared
manifest provenance path. Do not fall back to SHA-like tags or mutable image
tags to make dependency cleanup appear complete.

Maintenance Checks
------------------

Dependency changes must verify:

1. no retained workflow command imports ``ezcharts``, ``dominate``, ``bokeh``,
   or report/browser layout modules;
2. ``workflow-glue`` no longer exposes report, IGV, or JBrowse commands;
3. retained metrics and validation commands still import;
4. Sphinx documentation builds with warnings as errors;
5. any container digest changes are recorded in the workflow and manifest
   provenance contract.
