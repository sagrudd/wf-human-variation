Ingress
========

Current Input Model
-------------------

The workflow accepts input through ``--bam``. The value can be:

* a single BAM, CRAM, or uBAM;
* a directory of BAM/CRAM/uBAM files for one sample;
* a MinKNOW-style experiment directory when paired with a sample selector.

``lib/_ingress.nf`` wraps ``lib/ingress.nf`` and applies human-variation
specific behavior:

* generic XAM ingress;
* single-sample enforcement;
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

The current workflow frequently uses ``meta.alias`` as the sample-facing label
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

Single-Sample Enforcement
-------------------------

The human-variation wrapper counts ingressed channel entries and errors when
more than one sample is found. This is deliberate current behavior. Do not
remove it without also redesigning downstream output naming, publication
artefacts, channel grouping, and tests.

Maintenance Risks
-----------------

* Experiment directory handling can require sample names or sample sheets.
* Directory-depth validation can reject layouts before downstream validation.
* Missing sample-sheet rows and conflicting barcode/alias folders are handled
  during channel construction.
* Read statistics also feed later model detection and metrics generation.

Any ingress change should include tests for single file, single directory,
barcode directory, CRAM, uBAM, and reference mismatch behavior.
