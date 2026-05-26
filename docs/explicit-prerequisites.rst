Explicit Prerequisites
======================

New bounded ``humvar3`` entries must express cross-family dependencies as
task prerequisites, not as hidden feature activation.

Compatibility Debt In ``main.nf``
---------------------------------

The imported compatibility graph still contains launch-time boolean coupling:

* ``params.str`` or ``params.phased`` sets ``run_haplotagging``;
* ``params.cnv`` with Spectre mode contributes to ``run_snp``;
* QDNAseq CNV can force BAM-compatible conversion behavior.

That behavior is retained only for the static compatibility entry point. It
must not be copied into new bounded entries or controller planning. If a task
needs an upstream product or state, it declares that dependency by family,
output kind or subset, required state, scope, and missing policy.

Bounded Contract
----------------

The explicit contract is:

* STR declares an internal ``variant_calling`` prerequisite for
  ready ``haplotagged_contig_bams``.
* Spectre CNV declares an internal ``variant_calling`` prerequisite for
  a ready ``snp_vcf``.
* QDNAseq CNV does not declare an SNP prerequisite.
* Phased or haplotagged methylation may declare an optional
  ``variant_calling`` prerequisite for a ready ``haplotagged_bam`` and degrade
  explicitly if that output is unavailable.
* Reporting declares a ``task_family_subset`` prerequisite requiring at least
  one completed upstream analysis family. Reports over partial results are
  allowed only when that partial state is visible.

The controller may plan the prerequisite task, block the requesting task until
the prerequisite output exists, degrade explicitly, skip explicitly, or fail
invalid requests according to the declared missing policy. It must not publish
or report an internal prerequisite as a user-requested family unless that family
was separately requested.

Prerequisite State
------------------

Bounded entries must model the prerequisite state directly:

* ``ready`` means the named output artefact exists, belongs to the current
  task lineage, and passed validation.
* ``completed`` means the named family has a successful completion marker for
  the current task key.
* ``completed_subset`` means at least ``minimum_count`` families in a declared
  subset have completed. This is intended for reporting and export tasks that
  can run over partial completed results.

Nextflow Helper
---------------

``lib/feature_prerequisites.nf`` mirrors the shared controller package's
prerequisite map for bounded entries:

* ``explicitTaskPrerequisites("str")`` returns the haplotagged-contig
  prerequisite.
* ``explicitTaskPrerequisites("cnv", "spectre")`` returns the SNP VCF
  prerequisite.
* ``explicitTaskPrerequisites("cnv", "qdnaseq")`` returns no SNP
  prerequisite.
* ``explicitTaskPrerequisites("reporting")`` returns a partial-reporting
  prerequisite over completed upstream family state.

Use this helper only to emit or validate visible task-planning state. Do not
use it to rebuild a global ``run_snp``-style scheduler.
