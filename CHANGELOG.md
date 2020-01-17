Liquid Investigations Changelog
===============================

version 0.7.0
--------------------------

FEATURES:
- [configure](https://github.com/liquidinvestigations/node/blob/0553a4610c1a0c6c0dd26c5fd02390a98d32f76f/examples/liquid.ini#L156-L157) snoop worker memory limit and worker process count in addition to container count
- set 32 day retention policy for influxdb, prometheus and elasticsearch x-pack metrics
- enabled elasticsearch-based counters for task statistics (no configuration needed)

BUG FIXES:
- fixed python memory leak when dispatching existing jobs


versions 0.6.0 and older
-----------------------

Read the output of `git show v0.X.X` or the tag descriptions at https://github.com/liquidinvestigations/node/releases.
