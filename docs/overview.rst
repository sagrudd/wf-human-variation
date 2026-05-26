Overview
========

``wf-human-variation`` is a Nextflow DSL2 workflow for analysing human Oxford
Nanopore whole-genome sequencing data. It can run several analysis families
from a BAM, CRAM, or uBAM input and a reference FASTA:

* small variant calling with Clair3;
* structural variant calling with Sniffles2;
* copy-number variant calling with Spectre or QDNAseq;
* short tandem repeat genotyping with Straglr;
* modified-base aggregation with modkit;
* alignment, coverage, and report generation.

The workflow is a static single-run workflow. It builds one Nextflow graph from
launch-time parameters and then executes enabled branches. Some branches
implicitly enable supporting work. Maintainers must understand those couplings
before changing parameters, channels, or outputs.

Current Operating Model
-----------------------

Primary entry points:

* ``main.nf``: top-level workflow graph and global branch decisions.
* ``nextflow.config``: default parameters and workflow metadata.
* ``nextflow_schema.json``: parameter schema used by command-line and UI
  surfaces.
* ``output_definition.json``: declared output products.
* ``workflows/*.nf``: subworkflow composition.
* ``modules/local/*.nf``: local process implementations.
* ``lib/*.nf`` and ``lib/*.groovy``: ingress, reference handling, schema, and
  helper logic.
* ``bin/``: Python, R, and workflow glue scripts.

Important Constraints
---------------------

* The workflow is currently structured around global feature flags.
* Effective operation is single-sample, despite generic ingress machinery.
* Sample aliases are used heavily in paths and reports, but stable controller
  identity is ``sample_id``.
* Some optional inputs are represented by placeholder files.
* Some downstream work is triggered implicitly by other features.
* Large channel joins and collections create whole-run barriers.

These constraints are part of the current maintenance surface. If they are
changed, update this documentation and the relevant tests in the same change
set.
