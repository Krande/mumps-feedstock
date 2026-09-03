"""Check that ``mumps-*-devel`` pulled in the ABI-matched MUMPS build.

The ``-devel`` outputs exist only to carry the Fortran ABI marker: they have no
files of their own, they just depend on (and run-export) ``mumps-seq`` /
``mumps-mpi`` restricted to a matching build string. This test asserts that the
package the solver actually installed carries the expected ABI prefix.

Usage: python test-fortran-abi.py <package-name> <expected-abi>
"""

import glob
import json
import os
import sys

pkg, abi = sys.argv[1], sys.argv[2]
prefix = os.environ.get("PREFIX") or sys.prefix

records = []
for path in glob.glob(os.path.join(prefix, "conda-meta", "*.json")):
    with open(path, encoding="utf-8") as fh:
        records.append(json.load(fh))

matches = [r for r in records if r.get("name") == pkg]
if not matches:
    sys.exit("%s was not installed alongside %s-devel" % (pkg, pkg))

build = matches[0]["build"]
print("%s build string: %s" % (pkg, build))
if not build.startswith(abi + "_"):
    sys.exit("expected a %s build of %s, got %s" % (abi, pkg, build))
