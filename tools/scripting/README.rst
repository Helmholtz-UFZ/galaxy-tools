Note to admins: 
===============

These tools allow users to execute arbitrary python / R code in Galaxy.
A basic level of security comes by the execution in containers.

But admins should at least use a setting where:

- the user executing the Galaxy jobs can't write to any of the paths mounted by Galaxy (e.g. a real user setup) or
- only the job working dir is writable (and all inputs are copied to this dir)
- as few as possible directories should be mounted in ``rw`` mode
  - use outputs_to_working_directory
  - check any directories that are mounted by default