Family Analysis
===============

Family analysis is a runtime intent inside ``wf-human-variation``. It is not a
separate workflow product and it must not reintroduce the old ``wf-trio``
monolith. The controller owns family state, analysis intent, relationship
snapshots, and readiness decisions. Nextflow receives one bounded family task at
a time and executes only the declared unit.

Analysis Intent
---------------

An analysis intent binds a family to a requested family-capability set for one
reference context. The stable scheduling scope is:

* ``family_id``;
* ``analysis_intent_id``;
* ``reference_id``;
* ``role_snapshot_digest``;
* ``relationship_snapshot_digest``.

The role snapshot records the active sample assignments for roles such as
``proband``, ``father``, and ``mother``. The relationship snapshot records the
PED-derived parentage graph used by phasing and Mendelian checks. If either
snapshot changes, the controller creates new task keys rather than mutating
completed task outputs.

Prerequisites
-------------

Family prerequisites are explicit manifest artefacts. Bounded tasks must not
discover family members by channel order, display alias, filename, or
``proband_bam``-style parameter naming.

.. list-table::
   :header-rows: 1

   * - Family task
     - Required upstream state
     - Dynamic behavior
   * - ``family_germline_snp``
     - Role-keyed singleton ``snp_vcf``, ``snp_vcf_index``, ``snp_gvcf``, and
       ``snp_gvcf_index`` where the selected bounded entry requires them.
     - Candidate and denovo work can be planned for ready declared roles without
       blocking unrelated samples.
   * - ``family_joint_genotyping``
     - Complete role-keyed GVCFs for the declared joint-genotyping role set,
       pedigree snapshot, GLnexus config digest, and reference.
     - Missing parents block this task unless an explicit subset policy is
       introduced for the analysis intent.
   * - ``family_pedigree_phasing``
     - ``family_joint_vcf``, ``family_joint_vcf_index``, relationship snapshot,
       reference, and role-keyed alignments plus indexes.
     - Impossible or disabled phasing is represented as state and pass-through
       output, not silent omission.
   * - ``family_haplotagging``
     - ``pedigree_filtered_vcf``, ``pedigree_filtered_vcf_index``, reference,
       and role-keyed alignments plus indexes.
     - Haplotagged alignments are normal manifest artefacts for downstream
       STR, SV, methylation, and publication projections.
   * - ``family_sv_calling``
     - One role-keyed aggregate alignment, index, mosdepth summary, target BED,
       and reference.
     - Each family member can complete SV/SNF generation independently as data
       arrives.
   * - ``family_sv_merging``
     - Selected role-keyed ``structural_variant_snf`` artefacts, matching
       reference digests, target BED, and structured Sniffles merge options.
     - Subset merging is allowed only when the analysis intent and task options
       explicitly permit it.
   * - ``family_mendelian_assessment``
     - PED snapshot, RTG SDF reference, and at least one completed family VCF
       subset: ``family_joint_vcf`` or ``family_sv_vcf``.
     - SNP-only or SV-only assessment is explicit subset state.

Outputs
-------

The retained family output contract is data-first and manifest-backed:

* joint small-variant outputs: ``family_joint_vcf``,
  ``family_joint_vcf_index``, ``family_joint_gvcf``, and
  ``family_joint_gvcf_index`` where the joint-gVCF publication path is enabled;
* per-role trio SNP/GVCF outputs: ``trio_snp_vcf``, ``trio_snp_vcf_index``,
  ``trio_snp_gvcf``, and ``trio_snp_gvcf_index``;
* family SV prerequisites and outputs: ``structural_variant_snf``,
  ``family_sv_vcf``, and ``family_sv_vcf_index``;
* haplotagging outputs: ``family_haplotagged_alignments`` and
  ``family_haplotagged_contig_manifest``;
* PED-derived relationship state: ``pedigree_snapshot`` and
  ``pedigree_snapshot_digest``;
* Mendelian outputs: ``family_rtg_snp_summary``, ``family_rtg_sv_summary``,
  ``mendelian_summary``, and ``mendelian_metrics``;
* bounded task manifests, state files, provenance, command JSON, and
  ``qc_stats``.

Inherited ``wf-trio`` reports are deprecated. Old ``wf-trio`` HTML reports,
report Python, EPI2ME viewer metadata, and report MIME semantics are not
supported output contracts for ``humvar3``. Dashboard, API, and browser views
belong above the workflow as Poikilognostikon projections over the runtime
manifest.

Dynamic Arrival Semantics
-------------------------

Family scheduling is incremental. A proband can be basecalled while a father is
mapping and a mother has not yet arrived. The controller may plan per-member
work when the member's prerequisites are ready, while joint family tasks remain
blocked until their declared role set and artefacts exist.

Late-arriving samples do not invalidate stable sample identity. They create new
runtime events and, when relevant, new family role snapshots. The controller
then schedules only the bounded tasks whose keys are changed by the new role,
relationship, reference, model, config, container, or input-artefact digest.

Compatibility Risks
-------------------

The family methods retained from ``wf-trio`` have explicit compatibility risks
recorded in the Poikilognostikon method register:

* Clair3-Nova candidate selection and denovo calling require a Mnemosyne-owned
  ``linux/arm64`` image, model checksum validation, and concordance testing.
* GLnexus requires an owned image, a checksum-recorded ``glnexus_conf.yml``,
  and validation of the joint-genotyping sample order.
* RTG requires pinned OpenJDK/RTG versions and captured ``rtg version`` plus
  ``java -version`` provenance.

Maintain these risks in
``../../../wf-human-variation-method-compatibilities.md`` whenever a family method
contract, image, model, or config changes.
