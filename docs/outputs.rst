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
* bigWig artefacts where enabled.

Publication And Export:

* combined metrics JSON;
* partner-specific export products.

Machine-Readable Metrics Contract
---------------------------------

``humvar3`` keeps QC and analysis state in machine-readable artefacts rather
than HTML reports. The retained metrics/status surfaces are:

.. list-table::
   :header-rows: 1

   * - Family
     - Retained artefacts
     - Notes
   * - Alignment and coverage
     - ``*.stats.json``, ``*.readstats.tsv.gz``, ``*.mosdepth.summary.txt``,
       ``*.mosdepth.global.dist.txt``, ``*.thresholds.bed.gz``,
       ``*.runids.txt``, optional ``*.bed_summary.tsv`` and
       ``*.coverage_bed_summary.tsv``
     - ``*.stats.json`` is the combined sample metrics JSON. ``*.runids.txt``
       is the per-sample run-id artefact for controller manifest projection.
   * - SNP
     - SNP VCF/GVCF products and SNP metrics folded into ``*.stats.json``
     - Intermediate ``*.snvs.json`` is a workflow metric input, not a public
       output artefact.
   * - SV
     - SV VCF/SNF products and SV metrics folded into ``*.stats.json``
     - Intermediate ``*.svs.json`` is a workflow metric input, not a public
       output artefact.
   * - CNV
     - CNV VCF
     - Spectre BED/karyotype and QDNAseq auxiliary files remain internal until
       CNV output publication is rationalised; presentation PNG/PDF files are
       not retained outputs.
   * - STR
     - STR VCF and ``*.wf_str.straglr.tsv``
     - Additional STR sequence-content CSV files are machine-readable
       intermediates until STR output publication is rationalised.
   * - Methylation
     - bedMethyl and bigWig artefacts
     - These are data tracks, not viewer configuration.
   * - Low coverage
     - ``*.rejected_low_coverage.state.json`` and failing workflow status
     - Poikilognostikon should project the ``rejected_low_coverage`` terminal
       state through manifest state; no HTML failure output is produced.

Workflow-generated EPI2ME HTML reports and viewer configuration files are not
supported outputs on ``humvar3``. Dashboards, browser views, and API views
belong in Poikilognostikon projections over the shared runtime manifest, using
machine-readable QC, analysis, provenance, and output artefacts from this
workflow.

Maintenance Checklist
---------------------

For any output filename, type, optionality, or semantics change:

1. Update producing process outputs.
2. Update ``output_definition.json``.
3. Update this page.
4. Update export documentation if affected.
5. Add or update a test that asserts the output contract.

Optional outputs must be genuinely optional in both Nextflow and the declared
output definition. Do not add placeholder-file behavior without documenting the
reason and a removal path.
