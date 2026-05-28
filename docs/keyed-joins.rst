Keyed Joins
===========

Bounded ``humvar3`` entries must not use global ``collect()`` or broad unkeyed
``combine()`` operations to decide task readiness. Joins must be scoped to the
smallest correct boundary:

* per sample: ``sample_id``;
* per sample/reference: ``sample_id`` plus ``reference_id``;
* per task: the deterministic ``task_key``.

The helper functions in ``lib/keyed_joins.nf`` provide the Nextflow-side keying
convention for new bounded entries. The Python controller owns equivalent
controller-side keys in ``gnostikon_workflow_control.join_keys``.

Per-sample state must remain partial and concurrent. A join for one sample in
``variant_calling`` must not wait for another sample that is still
``basecalling`` or ``mapping``.

Allowed Uses
------------

``collect()`` remains acceptable only inside a bounded task when all values are
already scoped to that task key, for example collecting contig shards for one
sample/reference result. It must not be used to wait for all samples, all
flowcells, or all requested analysis families.

``combine()`` must specify a key or operate on a singleton value channel.
Unkeyed Cartesian joins are not acceptable for sample, reference, or task
state.

Compatibility Debt
------------------

The imported ``main.nf`` compatibility graph still contains whole-run joins for
legacy publication, annotation, and packaging. Do not copy those patterns into
bounded entries. The launch ingress, downsampling-readiness, coverage
pass/fail, and low-coverage rejection paths have been converted to
sample-scoped state. Retire the remaining barriers as the relevant family is
moved behind
controller-led execution:

* ``sample_aggregation`` owns per-sample/per-reference aggregate refresh;
* ``variant_calling`` owns SNP/SV/phasing/annotation joins;
* ``methylation``, ``cnv``, and ``str`` own their family-specific joins;
* ``reporting`` owns publication/package reductions from manifest-indexed
  outputs.

Task 22 Barrier Inventory
-------------------------

The remaining broad channel operations are compatibility-only debt. They are
not allowed in new bounded entries and must be retired by moving the owning
family to controller-led task execution:

.. list-table::
   :header-rows: 1

   * - File
     - Remaining barrier shape
     - Owner
   * - ``main.nf``
     - haplocheck reference collection, SNP/SV refinement collections,
       SNP annotation joins, and final compatibility publication flattening
     - ``variant_calling`` or ``reporting``
   * - ``workflows/wf-human-snp.nf``
     - chunk/candidate/GVCF collections and per-sample final VCF grouping
     - ``variant_calling``
   * - ``workflows/wf-human-str.nf``
     - STR contig/result merges and TSV/VCF collections
     - ``str`` compatibility path
   * - ``workflows/methyl.nf``
     - reference singleton collection and legacy per-sample bedMethyl grouping
     - ``methylation`` compatibility path
   * - ``workflows/wf-human-cnv.nf``
     - legacy mosdepth collection used by compatibility CNV
     - ``cnv`` compatibility path
   * - ``workflows/partners.nf``
     - partner export grouping
     - ``reporting``

The named bounded entries for ``mapping``, ``sample_aggregation``,
``variant_calling``, ``cnv``, ``str``, and ``methylation`` avoid these broad
joins for readiness. They consume controller-declared input artefacts and use
the task key, sample id, and reference id as their scheduling boundary.

Phase 3 Family Barrier Gate
---------------------------

The phase-3 family bounded entries have no accepted channel-barrier debt. They
must remain controller-scheduled units with explicit input paths rather than
Nextflow-side family discovery or grouping:

* ``family_germline_snp``
* ``family_germline_snp_denovo``
* ``family_germline_snp_merge``
* ``family_joint_genotyping``
* ``family_pedigree_phasing``
* ``family_haplotagging``
* ``family_sv_calling``
* ``family_sv_merging``
* ``family_mendelian_assessment``

Family-level joins belong in the controller and manifest indexes. The required
join keys are ``family_id``, ``analysis_intent_id``, ``reference_id``,
``role_snapshot_digest``, ``relationship_snapshot_digest``, and the
deterministic ``task_key``. Per-member family tasks additionally require
``role`` and ``sample_id`` so one family member can run or be reused without
waiting for unrelated samples.

Somatic joins follow the same bounded pattern with role state rather than
family relationships. The controller joins ``analysis_intent_id``,
``reference_id``, ``role_snapshot_digest``, ``role``, and ``sample_id`` to
existing ``mapping``/``sample_aggregation`` outputs. Somatic tasks consume
role-keyed ``aggregate_xam``, ``aggregate_xam_index``, ``mosdepth_summary``,
and ``coverage_state`` rather than collecting tumour/normal BAMs through a new
Nextflow graph.

These entries must not introduce global ``collect()``, broad ``combine()``,
``first()``, or ``groupTuple()`` readiness barriers. They must not consume the
legacy ``OPTIONAL_FILE`` sentinel or inherited absent-file placeholder. They
must not run old ``wf-trio`` or EPI2ME HTML report commands; Mendelian and QC
outputs remain machine-readable manifest artefacts, not HTML report products.

Review Checklist
----------------

For every new bounded entry:

1. Identify its join key before writing channel code.
2. Use keyed ``join``/``combine(..., by: ...)`` or pre-keyed tuples.
3. Keep ``collect()`` inside a task-key scope.
4. Record any intentional singleton value channel.
5. Reject changes that add all-sample or all-reference barriers.
