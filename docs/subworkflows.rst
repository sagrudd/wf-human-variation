Subworkflows
============

SNP Calling
-----------

Files:

* ``workflows/wf-human-snp.nf``
* ``modules/local/wf-human-snp.nf``
* ``lib/model.nf``

The SNP route uses Clair3 components to create SNP/indel VCFs and optional
GVCFs. It also contains phasing and haplotagging logic used by other
subworkflows.

Important couplings:

* STR and phased output can indirectly require SNP work.
* Spectre CNV consumes SNP VCF output.
* Clair3 model selection depends on basecaller metadata unless explicitly
  overridden.
* Genotyping mode with ``--vcf_fn`` changes allele-frequency behavior.

Phasing And Haplotagging
------------------------

Phasing and haplotagging are implemented inside the SNP route. The generated
haplotagged XAM and per-contig haplotagged BAMs can be consumed by SV, STR, and
modified-base analysis depending on flags.

This is a high-risk area because a downstream feature can cause a much larger
upstream path to run. Update this page whenever those dependencies change.

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

CNV Calling
-----------

Files:

* ``workflows/wf-human-cnv.nf``
* ``modules/local/wf-human-cnv.nf``
* ``workflows/wf-human-cnv-qdnaseq.nf``
* ``modules/local/wf-human-cnv-qdnaseq.nf``

Spectre is the default CNV mode. QDNAseq is enabled with ``--use_qdnaseq``.

Important couplings:

* Spectre consumes SNP VCFs.
* QDNAseq requires BAM-compatible input and can force format conversion.
* CNV generally requires supported genome-build handling.

STR Calling
-----------

Files:

* ``workflows/wf-human-str.nf``
* ``modules/local/wf-human-str.nf``

STR genotyping uses haplotagged contig BAMs from the SNP/haplotagging route and
requires sample sex state. If ``--sex`` is not provided, sex inference can be
used.

Modified-Base Calling
---------------------

Files:

* ``workflows/methyl.nf``

Modified-base aggregation validates BAM tags, computes probabilities, runs
modkit, and can produce phased bedMethyl output when phased processing is
requested.

Annotation, Reporting, And Export
---------------------------------

Annotation is embedded in several analysis routes. Reporting is split across
alignment, SNP, SV, CNV, STR, and combined metrics processes. Partner export is
handled by ``workflows/partners.nf``.

Maintain these as user-visible contracts: changing filenames, optionality, or
report content requires updates to ``output_definition.json`` and
``docs/outputs.rst``.
