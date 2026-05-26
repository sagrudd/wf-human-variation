Outputs
========

Sources Of Truth
----------------

Output products are declared in ``output_definition.json`` and produced by
workflow processes. This page describes the output families maintainers must
keep aligned.

Core Output Families
--------------------

Alignment and QC:

* metrics JSON;
* read statistics;
* flagstat;
* coverage summaries;
* optional per-base coverage;
* optional haplocheck output.

Variant outputs:

* SNP VCF and index;
* optional SNP GVCF and index;
* optional ClinVar-filtered SNP VCF;
* SV VCF, index, and optional SNF;
* CNV VCF and auxiliary files;
* STR VCF and machine-readable STR summary content.

Modified-base outputs:

* bedMethyl;
* phased bedMethyl when applicable;
* bigWig tracks where enabled.

Publication, Export, And Presentation:

* combined metrics JSON;
* optional IGV/JBrowse configuration;
* partner-specific export products.

Workflow-generated EPI2ME HTML reports are not supported outputs on
``humvar3``. Dashboards and API views belong in Poikilognostikon projections
over the shared runtime manifest, using machine-readable QC, analysis,
provenance, and output artefacts from this workflow.

Maintenance Checklist
---------------------

For any output filename, type, optionality, or semantics change:

1. Update producing process outputs.
2. Update ``output_definition.json``.
3. Update this page.
4. Update export or presentation documentation if affected.
5. Add or update a test that asserts the output contract.

Optional outputs must be genuinely optional in both Nextflow and the declared
output definition. Do not add placeholder-file behavior without documenting the
reason and a removal path.
