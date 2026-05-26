Subworkflows
============

The existing files below are the upstream-derived implementation units. The
dynamic ``humvar3`` maintenance boundary is the bounded family split documented
in ``docs/bounded-task-families.rst``. In particular, SNP, SV, phasing, and
annotation roll up to ``variant_calling``; modified-base work rolls up to
``methylation``; report, export, and publication work rolls up to
``reporting``.

SNP Calling
-----------

Files:

* ``workflows/wf-human-snp.nf``
* ``modules/local/wf-human-snp.nf``
* ``lib/model.nf``

The SNP route uses Clair3 components to create SNP/indel VCFs and optional
GVCFs. It also contains phasing and haplotagging logic used by other
subworkflows.

Compatibility couplings:

* The static graph can run SNP work for STR and phased output because
  haplotagging is implemented inside the SNP route.
* Spectre CNV consumes SNP VCF output in the static graph.
* Clair3 model selection depends on basecaller metadata unless explicitly
  overridden.
* Genotyping mode with ``--vcf_fn`` changes allele-frequency behavior.

Phasing And Haplotagging
------------------------

Phasing and haplotagging are implemented inside the SNP route. The generated
haplotagged XAM and per-contig haplotagged BAMs can be consumed by SV, STR, and
modified-base analysis depending on flags.

This is a high-risk compatibility area because a downstream feature can cause a
much larger upstream path to run. New bounded entries must instead declare
``variant_calling`` output prerequisites as described in
``docs/explicit-prerequisites.rst``.

SV Calling
----------

Files:

* ``workflows/wf-human-sv.nf``
* ``modules/local/wf-human-sv.nf``
* ``modules/local/wf-human-sv-eval.nf``

The SV route uses Sniffles2, filtering, optional annotation, optional
benchmarking, and reporting.

Benchmarking requires SV calling. Missing benchmark truth resources currently
use compatibility behavior that must be documented if changed.

Genome-build restricted annotation should consume the central reference
compatibility result. Do not add SNP-, SV-, CNV-, STR-, or report-local
hg19/hg38 checks.

CNV Calling
-----------

Files:

* ``workflows/wf-human-cnv.nf``
* ``modules/local/wf-human-cnv.nf``
* ``workflows/wf-human-cnv-qdnaseq.nf``
* ``modules/local/wf-human-cnv-qdnaseq.nf``

Spectre is the default CNV mode. QDNAseq is enabled with ``--use_qdnaseq``.

Compatibility couplings:

* Spectre consumes SNP VCFs.
* QDNAseq requires BAM-compatible input and can force format conversion.
* CNV generally requires supported genome-build handling.

Bounded CNV entries must declare Spectre's SNP VCF dependency explicitly and
must not make Spectre mode silently activate SNP publication.

STR Calling
-----------

Files:

* ``workflows/wf-human-str.nf``
* ``modules/local/wf-human-str.nf``

STR genotyping uses haplotagged contig BAMs from the variant-calling
haplotagging capability and requires sample sex state. If ``--sex`` is not
provided, sex inference can be used. Bounded STR entries must declare
``haplotagged_contig_bams`` as an explicit prerequisite rather than silently
activating SNP or haplotagging work.

Modified-Base Calling
---------------------

Files:

* ``workflows/methyl.nf``

Modified-base aggregation validates BAM tags, computes probabilities, runs
modkit, and can produce phased bedMethyl output when phased processing is
requested.

Modkit command customisation must use the structured ``--modkit_options``
object. Free-form ``--modkit_args`` shell fragments are rejected.

Annotation, Reporting, And Export
---------------------------------

Annotation is embedded in several analysis routes. Reporting is split across
alignment, SNP, SV, CNV, STR, and combined metrics processes. Partner export is
handled by ``workflows/partners.nf``.

Maintain these as user-visible contracts: changing filenames, optionality, or
report content requires updates to ``output_definition.json`` and
``docs/outputs.rst``.
