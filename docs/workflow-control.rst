Workflow Control Integration
============================

This fork is being maintained alongside the shared
``gnostikon-workflow-control`` Python package and the Poikilognostikon
integration repository. The three codebases must move together when a change
affects runtime orchestration, optional-input semantics, sample identity, or
dynamic data arrival.

Repository Responsibilities
---------------------------

``../gnostikon-workflow-control``
    Owns controller-layer primitives: neutral sample, flowcell,
    sequencing-run, artefact, reference, task, manifest, runtime-event, and
    optional-input models.

``../wf-human-variation``
    Owns the Nextflow implementation and transitional process boundaries for
    human-variation analysis. Compatibility files or empty channels may still
    be created here when Nextflow process shapes require them.

``../poikilognostikon``
    Owns integration planning, runtime product context, submodule pinning, and
    migration records.

Controller Backfill
-------------------

The shared controller package now provides these concepts that are relevant to
this workflow:

* neutral domain vocabulary: samples, flowcells, sequencing runs, artefacts,
  references, tasks, and manifests;
* ``gnostikon.runtime_event.v1`` runtime events for dynamic arrivals and task
  state;
* watched event-directory and SQLite event-store ingress;
* sample-sheet bootstrap import, where inherited ``sample,pod5_dir`` rows are
  converted into normal runtime events;
* explicit stable sample identity for read artefacts, matching the inherited
  Epignostikon requirement that POD5 and BAM arrivals are sample-bound;
* typed optional file and channel inputs, where absence is represented as
  state rather than as a placeholder filename.

Current Workflow Boundary
-------------------------

This Nextflow workflow is still a launch-time static graph. It does not yet
consume ``gnostikon.runtime_event.v1`` directly.

Until the workflow is refactored into dynamic task families, keep controller
state and Nextflow boundary behavior separate:

* do not introduce new controller semantics by naming a file
  ``OPTIONAL_FILE``;
* do not add new sample-sheet primary ingress paths;
* use explicit empty channels when a process can naturally consume no values;
* use ``lib/optional_inputs.nf`` when a process boundary still requires a
  concrete placeholder file;
* document every remaining placeholder as transitional compatibility behavior.

Stable Identity
---------------

Stable sample identity is the tuple ``{project, flowcell, run_id, sample_id,
biosample_id}``. These fields are added to ``meta`` by
``lib/stable_identity.nf`` when supplied through parameters. They must be used
by future controller-facing task contracts instead of deriving sample identity
from ``meta.alias``, filenames, barcode folders, or sample-sheet aliases.

The current workflow still uses ``meta.alias`` heavily for filenames, reports,
and third-party export paths. Treat that as a display and compatibility label
only.

Sample Sheets
-------------

Sample sheets are not a primary runtime interface for the new shared control
model. Where they are inherited from existing tooling, they should be treated
as bootstrap input and converted into runtime events before orchestration.

This workflow still contains generic ingress code that can encounter sample
sheet concepts. Do not remove inherited sample requirements casually: read
artefacts must remain explicitly associated with a sample.

Parallel Maintenance Rule
-------------------------

For future migration work, update all affected surfaces in the same change:

* shared Python controller contracts in ``../gnostikon-workflow-control``;
* Nextflow boundary behavior and Sphinx docs in ``../wf-human-variation``;
* integration plans, manifests, and submodule pins in ``../poikilognostikon``.
