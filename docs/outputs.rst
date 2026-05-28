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
* bounded ``variant_calling`` manifest, provenance, and QC JSON for SNP/GVCF
  task-cache outputs;
* optional ClinVar-filtered SNP VCF;
* SV VCF, index, and optional SNF;
* CNV VCF and auxiliary files;
* STR VCF and machine-readable STR summary content.

Family analysis outputs:

* ``trio_snp_vcf``, ``trio_snp_vcf_index``, ``trio_snp_gvcf``, and
  ``trio_snp_gvcf_index`` for per-role trio small-variant finalisation;
* ``family_joint_vcf`` and ``family_joint_vcf_index`` for GLnexus family
  joint-genotyping output;
* ``family_joint_gvcf`` and ``family_joint_gvcf_index`` only where a
  joint-gVCF publication path is explicitly enabled by the controller;
* ``structural_variant_snf`` as the first-class per-member prerequisite for
  family SV merging;
* ``family_sv_vcf`` and ``family_sv_vcf_index`` for merged family SV output;
* ``family_haplotagged_alignments`` and
  ``family_haplotagged_contig_manifest`` for downstream reuse by STR, SV,
  methylation, and publication projections;
* ``pedigree_snapshot`` and ``pedigree_snapshot_digest`` as PED-derived
  relationship-state artefacts owned by the controller;
* ``family_rtg_snp_summary``, ``family_rtg_sv_summary``,
  ``mendelian_summary``, and ``mendelian_metrics`` for RTG Mendelian
  assessment;
* family task manifests, state files, command JSON, provenance JSON, and
  ``qc_stats``.

Somatic outputs:

* ``somatic_snv_vcf`` and ``somatic_snv_vcf_index`` from bounded
  ``somatic_tumour_only_snv`` ClairS-TO execution, retaining the data filename
  ``<sample_id>.wf-somatic-snv.vcf.gz`` plus ``.tbi``;
* ``somatic_tumour_only_snv_command_json``,
  ``somatic_tumour_only_snv_logs``,
  ``somatic_tumour_only_snv_manifest``, ``somatic_provenance``, and
  ``qc_stats`` for manifest projection and restart audit.
* ``somatic_sv_vcf`` and ``somatic_sv_vcf_index`` from bounded
  ``somatic_tumour_only_sv`` Severus execution, retaining the data filename
  ``<sample_id>.wf-somatic-sv.vcf.gz`` plus ``.tbi``;
* ``somatic_sv_raw_directory``, ``somatic_tumour_only_sv_command_json``,
  ``somatic_tumour_only_sv_manifest``, ``somatic_provenance``, and
  ``qc_stats`` for raw Severus inspection, manifest projection, and restart
  audit.
* ``somatic_sv_vcf`` and ``somatic_sv_vcf_index`` from bounded
  ``somatic_paired_sv`` Severus execution, retaining the data filename
  ``<pair_id>.wf-somatic-sv.vcf.gz`` plus ``.tbi``;
* ``somatic_sv_raw_directory``, ``somatic_paired_sv_command_json``,
  ``somatic_paired_sv_manifest``, ``somatic_provenance``, and ``qc_stats`` for
  paired Severus raw-output inspection, pair-state manifest projection, and
  restart audit.
* ``somatic_annotated_vcf`` and ``somatic_annotated_vcf_index`` from bounded
  ``somatic_annotation`` execution over controller-declared somatic SNV or SV
  source VCFs;
* ``somatic_clinvar_vcf``, ``somatic_clinvar_vcf_index``,
  ``somatic_annotation_manifest``, ``somatic_annotation_command_json``,
  ``somatic_provenance``, and ``qc_stats`` for annotation audit and optional
  ClinVar-filtered review state.
* ``germline_helper_vcf`` and ``germline_helper_vcf_index`` from bounded
  ``somatic_germline_helper`` execution when paired somatic SNV calling needs a
  computed normal/control helper VCF;
* ``germline_helper_manifest``, ``germline_helper_command_json``,
  ``germline_helper_logs``, ``somatic_provenance``, and ``qc_stats`` for
  helper-state audit and ``normal_vcf_state`` projection.
* ``selected_heterozygous_sites``, ``somatic_phased_vcf``, and
  ``somatic_phased_vcf_index`` from bounded role-scoped
  ``somatic_phasing``;
* ``somatic_phasing_manifest``, ``somatic_phasing_command_json``,
  ``somatic_phasing_state``, ``somatic_provenance``, and ``qc_stats`` for
  phasing policy audit.
* ``somatic_haplotagged_xam``, ``somatic_haplotagged_xam_index``, and
  ``somatic_haplotagged_contig_manifest`` from bounded role-scoped
  ``somatic_haplotagging``;
* ``somatic_haplotagging_manifest``, ``somatic_haplotagging_command_json``,
  ``somatic_haplotagging_state``, ``somatic_provenance``, and ``qc_stats`` for
  haplotagging policy audit and haplotype-filter prerequisites.
* ``somatic_haplotype_filtered_vcf`` and
  ``somatic_haplotype_filtered_vcf_index`` from bounded paired ClairS
  haplotype filtering;
* ``somatic_haplotype_filter_manifest``,
  ``somatic_haplotype_filter_command_json``,
  ``somatic_haplotype_filter_state``, ``somatic_haplotype_filter_logs``,
  ``somatic_provenance``, and ``qc_stats`` for enabled, skipped, or failed
  haplotype-filter state.
* ``somatic_bedmethyl``, ``somatic_bedmethyl_index``, ``somatic_bigwig``,
  ``somatic_mod_summary``, and ``somatic_dss_input_tsv`` from bounded
  role-specific ``somatic_methylation_aggregation`` execution;
* ``somatic_methylation_aggregation_manifest``,
  ``somatic_methylation_aggregation_command_json``,
  ``somatic_methylation_aggregation_log``, ``somatic_provenance``, and
  ``qc_stats`` for role-level modkit audit and downstream paired DSS input.
* ``somatic_dml_tsv`` and ``somatic_dmr_tsv`` from bounded
  ``somatic_differential_methylation`` DSS execution for one pair and one
  modification code;
* ``somatic_differential_methylation_manifest``,
  ``somatic_differential_methylation_command_json``,
  ``somatic_differential_methylation_log``, ``somatic_r_versions``,
  ``somatic_provenance``, and ``qc_stats`` for paired DSS audit and R package
  version capture.

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
   * - Family analysis
     - Joint VCF/GVCF, SNF, haplotagged alignment, PED snapshot, Mendelian
       summary, manifest, state, provenance, and QC artefacts listed above
     - These are runtime-manifest output kinds. They replace inherited
       ``wf-trio`` HTML and report-only artefacts.
   * - Somatic tumour-only SNV
     - ClairS-TO VCF/index, command JSON, execution log, manifest, provenance,
       and QC JSON
     - These replace inherited ``wf-somatic-variation`` HTML reports, IGV
       hooks, and publication-only artefacts.
   * - Somatic paired SNV intermediates
     - ClairS candidate directories, pileup prediction fragments,
       full-alignment prediction fragments, command JSON, execution logs,
       manifests, provenance, and QC JSON
     - These are resumable bounded-task intermediates. The final paired VCF is
       produced by a later merge task rather than by rediscovering work
       directory files.
   * - Somatic paired SNV final VCF
     - ClairS merged VCF/index, command JSON, execution log, manifest,
       provenance, and QC JSON
     - This is a controller-launched merge of manifested pileup and
       full-alignment fragments. Haplotype-filtered outputs are a later
       capability, not an implicit side effect of final VCF merge.
   * - Somatic tumour-only SV
     - Severus VCF/index, raw Severus output directory, command JSON,
       manifest, provenance, and QC JSON
     - These replace inherited SV HTML reports, IGV hooks, hidden PON/TRF
       defaults, and publication-only artefacts.
   * - Somatic annotation
     - Annotated VCF/index, ClinVar-filtered VCF/index, command JSON,
       manifest, provenance, and QC JSON
     - This is a bounded SnpEff/SnpSift task over declared source VCFs, not a
       hidden caller side effect or HTML report route.
   * - Somatic methylation aggregation
     - bedMethyl/index, BigWig, modkit summary, DSS input TSV, command JSON,
       modkit log, manifest, provenance, and QC JSON
     - Role-specific modkit aggregation can run for tumour-only data without
       DSS or a normal sample. Paired DSS remains a separate task family.

Workflow-generated EPI2ME HTML reports and viewer configuration files are not
supported outputs on ``humvar3``. This includes the old ``wf-trio`` individual
SNP/SV reports, joint SNP/SV reports, RTG report pages, report Python, EPI2ME
viewer metadata, and report MIME semantics. Dashboards, browser views, and API
views belong in Poikilognostikon projections over the shared runtime manifest,
using machine-readable QC, analysis, provenance, and output artefacts from this
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
output definition. Do not add marker-file behavior without documenting the
reason and a removal path.
