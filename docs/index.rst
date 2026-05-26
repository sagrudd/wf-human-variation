wf-human-variation Technical Documentation
==========================================

This is the canonical documentation for understanding, working with, and
maintaining ``wf-human-variation``.

The previous generated Markdown fragments in ``docs/01_*.md`` through
``docs/12_*.md`` are deprecated and have been removed. New documentation must
be maintained as Sphinx source and built by Read the Docs.

Scope
-----

These documents describe the ``wf-human-variation`` workflow only:

* workflow purpose and supported analysis families;
* current static Nextflow architecture;
* input and output contracts;
* parameter and schema maintenance;
* subworkflow coupling and operational caveats;
* testing, release, and documentation maintenance expectations.

This documentation is not a place for Poikilognostikon product documentation or
project migration planning.

Contents
--------

.. toctree::
   :maxdepth: 2

   overview
   quickstart
   architecture
   ingress
   workflow-control
   bounded-task-families
   controller-execution
   idempotency
   keyed-joins
   explicit-prerequisites
   subworkflows
   parameters
   dependencies
   outputs
   testing
   maintenance
   troubleshooting
   documentation
