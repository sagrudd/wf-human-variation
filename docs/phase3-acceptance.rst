Phase 3 Family Acceptance
=========================

This page defines the minimum gate for treating phase-3 family analysis as a
credible Poikilognostikon extension of ``wf-human-variation``.

Release Decision
----------------

Phase 3 is implementation-complete for local contract review only.

Release status: Phase 3 is not release-accepted for customer or production use until ARM64 image-build evidence and scientific validation evidence are supplied.

The current dirty-worktree ``wf-human-variation`` fork candidate is:

.. code-block:: text

   b1a5a78ec9c02de276f01dc8608096db93a87e91

This is not an accepted fork pin while phase-3 files remain uncommitted. The
accepted ``wf-human-variation`` fork commit is the future committed phase-3
revision that passes this gate. Poikilognostikon must pin
``workflows/wf-human-variation`` to that exact commit. A dirty submodule
worktree, uncommitted bounded entry, or missing validation evidence blocks
acceptance.

Required Family Task Families
-----------------------------

Phase 3 requires bounded entries and controller-facing contracts for:

.. list-table::
   :header-rows: 1

   * - Required task family
     - Required bounded entry surface
   * - ``family_germline_snp``
     - ``family_germline_snp``, ``family_germline_snp_denovo``,
       ``family_germline_snp_merge``
   * - ``family_joint_genotyping``
     - ``family_joint_genotyping``
   * - ``family_pedigree_phasing``
     - ``family_pedigree_phasing``
   * - ``family_haplotagging``
     - ``family_haplotagging``
   * - ``family_sv_calling``
     - ``family_sv_calling``
   * - ``family_sv_merging``
     - ``family_sv_merging``
   * - ``family_mendelian_assessment``
     - ``family_mendelian_assessment``

Every entry must consume controller-declared inputs, write declared task-cache
outputs, include family scope in provenance, and write the standard completion
marker only after required outputs exist.

Minimum Local Gate
------------------

Before advancing the Poikilognostikon submodule pin for a phase-3 candidate,
run:

.. code-block:: bash

   python -m unittest discover -s tests -v
   python -m sphinx -W -b html docs docs/_build/html
   python -m json.tool nextflow_schema.json >/tmp/wf-human-variation-nextflow-schema.json
   python -m json.tool output_definition.json >/tmp/wf-human-variation-output-definition.json

The gate must include:

* ``tests/test_bounded_entry_contract.py`` for bounded entry shape and retained
  output contracts;
* ``tests/test_phase3_family_performance_gates.py`` for absence of global
  channel barriers, inherited report commands, compatibility runners, and
  ``OPTIONAL_FILE`` leakage in family entries;
* ``tests/test_phase2_synthetic_contracts.py`` for tiny synthetic reference,
  BED, PED, and per-member GVCF fixtures;
* Poikilognostikon controller tests for PED bootstrap replay, late parent
  arrival, duplicate family-member state, deterministic family task keys, and
  family completion-marker reuse;
* ``gnostikon-workflow-control`` tests for pedigree import, family readiness,
  task-family contracts, idempotency, and bounded launch planning.

Required ARM64 And Container Evidence
-------------------------------------

Required ARM64 evidence: every Phase 3 runtime image must have ``linux/amd64`` and ``linux/arm64`` build records, immutable image digests, version probe output, executable smoke-test output, and a committed image manifest or bill of materials.

Release acceptance requires this evidence for all phase-3 family runtime
images:

.. list-table::
   :header-rows: 1

   * - Image family
     - Required evidence
   * - ``poikilognostikon-clair3-nova``
     - Clair3-Nova runtime version, model checksum, selected model mapping
       checksum, CUDA/CPU platform notes, and source commit or release.
   * - ``poikilognostikon-trio-hts``
     - ``bcftools``, ``tabix``, ``bgzip``, ``samtools``, and helper-script
       versions.
   * - ``poikilognostikon-trio-joint``
     - GLnexus version, RTG version, OpenJDK version, and checksum-recorded
       ``glnexus_conf.yml``.
   * - ``poikilognostikon-trio-phasing``
     - WhatsHap version and any bundled HTS helper versions.
   * - ``poikilognostikon-trio-sv``
     - Sniffles2 version plus native Python dependency import/version probes.

The owning image plan is ``phase-3-trio-container-plan.md`` in the
Poikilognostikon repository. The method compatibility register is
``wf-human-variation-method-compatibilities.md``.

Scientific Validation Items
---------------------------

The following items are release blockers even when local contract tests pass:

Scientific validation remains unresolved for Clair3-Nova candidate/denovo concordance, GLnexus joint-genotyping concordance, WhatsHap pedigree phasing/haplotagging correctness, Sniffles2 per-member SNF and joint SV merge concordance, and RTG Mendelian SNP/SV truth-case checks.

* Clair3-Nova candidate selection and denovo calling must be concordance-tested
  against the reviewed ``wf-trio`` behaviour and against expected truth-set
  trio calls.
* GLnexus joint genotyping must be concordance-tested against the inherited
  ``wf-trio`` GLnexus configuration and an independently reviewed reference
  family.
* WhatsHap pedigree phasing and haplotagging must be validated for sample-order
  correctness, parent/proband role handling, and phase-set consistency.
* Sniffles2 per-member SNF generation and family SV merging must be validated
  for selected-role subset mode, reference digest compatibility, and joint SV
  concordance.
* RTG Mendelian assessment must be validated against known Mendelian truth
  cases for SNP and SV inputs.

Release Blocking Regressions
----------------------------

Any of these changes blocks phase-3 acceptance:

* family tasks scheduled from filename aliases instead of ``family_id``,
  ``analysis_intent_id``, ``role``, ``sample_id``, and snapshot digests;
* hidden singleton SNP, phasing, SV, RTG, or report activation from a family
  task;
* global ``collect()``, broad or unkeyed ``combine()``, ``first()``, or
  ``groupTuple()`` readiness barriers in bounded family entries;
* inherited ``wf-trio`` or EPI2ME HTML report outputs;
* ``OPTIONAL_FILE`` sentinel leakage into family entry inputs;
* missing container digest, model checksum, config checksum, command argument,
  input checksum, output artefact, or completion-marker provenance.
