"""Patch MUMPS Fortran headers to use explicit INTEGER(4), REAL(4), etc.

This ensures that code_aster's /integer-size:64 flag does not change
the size of INTEGER fields in MUMPS derived types (DMUMPS_STRUC etc.).
MUMPS internally uses 4-byte integers; only the matrix indices need
special handling (via MUMPS_INT in mumps_int_def.h).

Usage: python make_integers_explicit.py <include_dir>
"""
import pathlib
import re
import sys

_replacements = [
    (r"INTEGER *,", "INTEGER(4),"),
    (r"INTEGER *::", "INTEGER(4) ::"),
    (r"INTEGER MPI", "INTEGER(4) MPI"),
    (r"REAL *,", "REAL(4),"),
    (r"REAL *::", "REAL(4) ::"),
    (r"COMPLEX *,", "COMPLEX(4),"),
    (r"COMPLEX *::", "COMPLEX(4) ::"),
    (r"LOGICAL *,", "LOGICAL(4),"),
    (r"LOGICAL *::", "LOGICAL(4) ::"),
]


def find_files(include_dir: pathlib.Path):
    include_patterns = ["*_struc.h", "*_root.h"]
    files_to_edit = []
    for pattern in include_patterns:
        files_to_edit.extend(include_dir.glob(pattern))
    mpif = include_dir / "mumps_seq" / "mpif.h"
    if mpif.exists():
        files_to_edit.append(mpif)
    return files_to_edit


def modify_file(file_path: pathlib.Path):
    print(f"Patching: {file_path}")
    content = file_path.read_text(encoding="utf-8")
    for pattern, replacement in _replacements:
        content = re.sub(pattern, replacement, content)
    file_path.write_text(content, encoding="utf-8")


def main(include_dir):
    include_dir = pathlib.Path(include_dir)
    files = find_files(include_dir)
    if not files:
        print(f"WARNING: No MUMPS header files found in {include_dir}")
        sys.exit(1)
    for f in files:
        modify_file(f)
    print(f"Patched {len(files)} files")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <include_dir>")
        sys.exit(1)
    main(sys.argv[1])
