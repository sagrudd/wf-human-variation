Phase 2 Release Acceptance
==========================

This page defines the minimum gate for treating the ``humvar3`` fork as a
maintained Poikilognostikon execution backend rather than a patched copy of the
upstream monolithic workflow.

Release Decision
----------------

Phase 2 is acceptable when all checklist items below pass in local validation.
This does not mean the inherited compatibility graph is finished. It means the
remaining compatibility debt is finite, named, and excluded from new
Poikilognostikon runtime behaviour.

Acceptance Checklist
--------------------

.. list-table::
   :header-rows: 1

   * - Criterion
     - Evidence
   * - No workflow-generated EPI2ME analysis HTML reports
     - ``tests/test_phase2_performance_gates.py`` checks public output
       definitions and runtime files for report HTML reintroduction.
   * - No report-only Python code on the runtime path
     - ``tests/test_phase2_performance_gates.py`` blocks report-only imports
       such as ``ezcharts``, ``dominate``, ``bokeh``, and ``aplanat``.
   * - No hidden feature activation for STR, Spectre, or phased methylation in
       controller-launched bounded entries
     - ``docs/explicit-prerequisites.rst``,
       ``lib/feature_prerequisites.nf``, and bounded-entry tests require
       explicit prerequisite state. Inherited ``main.nf`` launch-time coupling
       is named compatibility debt, not accepted bounded runtime behaviour.
   * - Bounded contracts exist for mapping, aggregation/QC, SNP, SV, CNV, STR,
       and methylation
     - ``docs/bounded-task-families.rst`` and
       ``tests/test_bounded_entry_contract.py`` cover ``-entry mapping``,
       ``sample_aggregation``, ``variant_calling`` SNP/SV modes, ``cnv``,
       ``str``, and ``methylation``.
   * - Synthetic tests cover local fixture and sample identity contracts;
       controller tests cover multi-sample interleaving and restarts
     - ``tests/test_phase2_synthetic_contracts.py`` covers local fixtures.
       Poikilognostikon and ``gnostikon-workflow-control`` release-gate
       event-store restart, completion-marker reuse, force-refresh, and
       interleaved task launch behaviour.
   * - Retained outputs are documented accurately
     - ``docs/outputs.rst`` documents machine-readable artefacts, low-coverage
       state, and the absence of HTML report products.
   * - Poikilognostikon can schedule bounded work from manifest state
     - Poikilognostikon ``poikilognostikon-control schedule`` and
       ``run-task`` synthetic integration tests exercise manifest-derived
       planning and bounded dry-run launches.
   * - Performance and resumability gates are active
     - ``tests/test_phase2_performance_gates.py`` and
       ``gnostikon-workflow-control`` idempotency tests guard task-cache reuse,
       forbidden patterns, and visible join-barrier review.

Required Local Gate
-------------------

Before advancing the submodule pin for a phase-2 release candidate, run:

.. code-block:: bash

   python -m unittest discover -s tests -v
   python -m sphinx -W -b html docs docs/_build/html
   python -m json.tool nextflow_schema.json >/tmp/wf-human-variation-nextflow-schema.json
   python -m json.tool output_definition.json >/tmp/wf-human-variation-output-definition.json

Where Nextflow is installed, bounded entry smoke tests should additionally run
through the controller-generated ``nextflow.params.json`` files documented in
``docs/testing.rst``. Lack of local Nextflow must be recorded with the release
candidate validation notes.

Nextflow execution metadata files such as ``timeline.html`` and ``report.html``
are not EPI2ME analysis reports and are not part of the public workflow output
contract. They must not be confused with the removed per-analysis HTML report
products.

Finite Compatibility Debt
-------------------------

The remaining inherited debt is release-visible and must not be expanded:

.. list-table::
   :header-rows: 1

   * - Debt
     - Location
     - Retirement path
   * - Anonymous compatibility graph
     - ``main.nf``
     - Keep for inherited reference behaviour only; new runtime behaviour must
       use controller-launched bounded entries.
   * - Broad channel joins and collections
     - ``docs/keyed-joins.rst`` Task 22 inventory
     - Retire family-by-family as compatibility subworkflows are replaced by
       bounded task units.
   * - Legacy optional-file boundary helper
     - ``lib/optional_inputs.nf``
     - Keep only at explicit compatibility boundaries; controller-layer inputs
       remain typed optionals.
   * - Legacy sample-sheet/bootstrap ingress
     - ``lib/ingress.nf`` and compatibility launch paths
     - Keep as bootstrap/import compatibility only; runtime primary ingress is
       event and manifest state.
   * - Legacy launch-time feature coupling
     - ``main.nf`` compatibility parameter handling
     - Keep visible as inherited compatibility behaviour only; bounded entries
       must use explicit prerequisite state for STR, Spectre, and phased
       methylation.
   * - Compatibility SNP/SV/CNV/STR/methylation/reporting subworkflows
     - ``workflows/*.nf`` and retained local modules
     - Mine useful tool invocations and retire scheduler responsibilities into
       bounded task-family entries.
   * - Partner export and publication joins
     - ``workflows/partners.nf`` and compatibility publication paths
     - Replace with manifest-backed publication/export tasks, not HTML reports.

Release Blocking Regressions
----------------------------

Any of these changes blocks phase-2 release acceptance:

* workflow-generated EPI2ME analysis ``.html`` report outputs or EPI2ME report
  dependencies;
* report-only Python imports on the runtime path;
* hidden STR, Spectre, or phased-methylation activation;
* new global ``.collect()``, broad unkeyed ``.combine()``, ``first()``, or
  ``groupTuple()`` barriers outside the documented compatibility inventory;
* new absent-input marker consumers outside ``lib/optional_inputs.nf``;
* mutable runtime state written through ``params.wf[...]``;
* bounded entries that omit deterministic task keys, task-cache paths, required
  outputs, provenance, or completion markers.
