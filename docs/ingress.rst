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

Identity Handling
-----------------

The current workflow frequently uses ``meta.alias`` as the sample-facing label
for outputs. The alias can come from:

* ``--sample_name``;
* a file stem;
* a directory basename;
* a barcode directory;
* a sample-sheet row in generic ingress code.

Maintainers must not confuse this alias with durable biological identity. It is
a label used by the current workflow and by output filenames.

Single-Sample Enforcement
-------------------------

The human-variation wrapper counts ingressed channel entries and errors when
more than one sample is found. This is deliberate current behavior. Do not
remove it without also redesigning downstream output naming, report generation,
channel grouping, and tests.

Maintenance Risks
-----------------

* Experiment directory handling can require sample names or sample sheets.
* Directory-depth validation can reject layouts before downstream validation.
* Missing sample-sheet rows and conflicting barcode/alias folders are handled
  during channel construction.
* Read statistics also feed later model detection and metrics generation.

Any ingress change should include tests for single file, single directory,
barcode directory, CRAM, uBAM, and reference mismatch behavior.
