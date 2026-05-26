Ingress
========

Current Input Model
-------------------

The workflow accepts input through ``--bam``. The value can be:

* a single BAM, CRAM, or uBAM;
* a directory of BAM/CRAM/uBAM files for one or more compatible sample
  folders;
* a MinKNOW-style experiment directory, optionally paired with a sample
  selector when only one folder should be selected.

``lib/_ingress.nf`` wraps ``lib/ingress.nf`` and applies human-variation
specific behavior:

* generic XAM ingress;
* stable identity projection;
* reference-header checks;
* realignment when the input is unaligned or does not match the requested
  reference;
* CRAM/BAM compatibility handling for downstream tools.

Shared Control Direction
------------------------

New shared runtime control code uses watched runtime events rather than static
sample sheets as its primary interface. Inherited sample sheets are bootstrap
input only: they are converted into ``sample_registered``, ``pod5_seen``,
``bam_seen``, and optional ``channel_closed`` events by
``gnostikon-workflow-control``.

This workflow has not yet been refactored to consume those events directly.
Until that happens, maintainers must keep the current launch-time ``--bam``
contract working while avoiding new sample-sheet primary ingress paths.

Identity Handling
-----------------

The current workflow frequently uses ``meta.alias`` as a sample-facing label
for outputs. It is not durable identity. The alias can come from:

* ``--sample_name``;
* a file stem;
* a directory basename;
* a barcode directory;
* a sample-sheet row in generic ingress code.

Maintainers must not confuse this alias with durable biological identity. It is
a label used by the current workflow and by output filenames.

The shared controller model treats ``sample_id`` as authoritative sample
identity for read artefacts. ``project``, ``flowcell``, and ``run_id`` are
optional runtime context. Dynamic POD5 and BAM arrivals must carry
``sample_id`` when they are projected into this workflow. The transitional
Nextflow metadata now carries these fields when supplied through parameters,
while ``meta.alias`` remains a display/output label.

Task execution must preserve the distinction between these values. VCF sample
names, caller ``--sample-id`` arguments, rejection-state JSON, and combined
metrics metadata use ``sample_id``. File names and current publication paths
continue to use ``meta.alias`` until the output contract is deliberately
revised.

Multi-Sample Boundary
---------------------

The human-variation wrapper no longer rejects a launch only because multiple
ingressed records are present. Each ingressed record must still be projected
onto stable identity before it reaches analysis branches. A scalar
``--sample_id`` is suitable only for a single ingressed record. Multi-record
launches must provide identity from the controller/bootstrap layer, or use the
transitional mapping form:

.. code-block:: bash

   --sample_id alias_a=smp_a,alias_b=smp_b

The mapping key is matched against the current ingress alias or barcode. The
mapped value becomes ``meta.sample_id``. ``meta.alias`` remains the output label
for current compatibility.

Low-coverage rejection is now per sample. A rejected sample writes
``rejected_low_coverage`` state and is removed from downstream BAM analysis
without causing unrelated samples to fail at the rejection boundary.

Maintenance Risks
-----------------

* ``--sample_name`` remains a selector; omit it when all compatible folders in
  an experiment directory should be ingressed.
* Experiment directory handling can still involve inherited sample-sheet
  bootstrap logic.
* Directory-depth validation can reject layouts before downstream validation.
* Missing sample-sheet rows and conflicting barcode/alias folders are handled
  during channel construction.
* Read statistics also feed later model detection and metrics generation.

Any ingress change should include tests for single file, multiple sample
folders, barcode directory, CRAM, uBAM, reference mismatch behavior, duplicate
artefacts, and per-sample rejection.
