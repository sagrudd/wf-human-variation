Maintenance
===========

Development Contract
--------------------

Documentation is part of the development contract. A behavior change is not
complete until the technical documentation and tests that describe that
behavior are updated.

Required documentation updates:

* architecture changes: update ``docs/architecture.rst``;
* ingress changes: update ``docs/ingress.rst``;
* shared controller or dynamic-runtime changes: update
  ``docs/workflow-control.rst``;
* analysis branch changes: update ``docs/subworkflows.rst``;
* parameter changes: update ``docs/parameters.rst``;
* output changes: update ``docs/outputs.rst``;
* test strategy changes: update ``docs/testing.rst``;
* failure-mode changes: update ``docs/troubleshooting.rst``.

Review Focus
------------

Reviewers should check:

* whether global branch decisions changed;
* whether any feature flag silently activates another analysis family instead
  of declaring an explicit prerequisite;
* whether any channel operation introduces a new whole-run barrier;
* whether runtime state is written through manifest/event APIs rather than
  mutable ``params.wf[...]`` side effects;
* whether optional values are represented clearly;
* whether matching changes are needed in ``../gnostikon-workflow-control`` and
  ``../poikilognostikon``;
* whether sample alias use remains consistent;
* whether output filenames and schema entries match;
* whether report content still matches generated artefacts;
* whether docs and tests moved with the code.

Known Compatibility Debt
------------------------

* Static ``main.nf`` SNP activation for STR, phasing, and Spectre CNV.
* QDNAseq format compatibility.
* Placeholder optional files.
* Mutable ``params.wf[...]`` runtime side effects, especially
  ``ingress.run_ids`` in the imported compatibility graph.
* Drift between this workflow, ``gnostikon-workflow-control``, and
  Poikilognostikon migration records.
* Low-coverage behavior.
* Basecaller model detection.
* Annotation genome-build restrictions.
* Partner export placeholder handling.
* Report joins over multiple channels.

Release Hygiene
---------------

Before release:

1. Build Sphinx docs with warnings as errors.
2. Run available workflow smoke tests.
3. Confirm parameter schema and README agree with behavior.
4. Confirm output definitions match produced artefacts.
5. Record any known unverified paths.
