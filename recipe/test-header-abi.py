"""Verify the installed MUMPS Fortran headers are default-INTEGER agnostic.

MUMPS is built LP64: the compiled libraries use a 4-byte default INTEGER.
Downstream Fortran consumers (code_aster, for one) compile with a 64-bit
default INTEGER. Unless every INTEGER/REAL/LOGICAL component of the derived
types in ``*mumps_struc.h`` carries an explicit kind, those types silently
grow in the consumer and no longer match the layout compiled into the DLL.
That is a memory-corruption bug, not a link error, so nothing catches it
without a test like this one.

``make_integers_explicit.py`` rewrites the headers at build time to pin every
component to an explicit kind. This test compiles the same probe program
twice against the *installed* headers -- once with the compiler's default
INTEGER, once with a 64-bit default INTEGER -- and requires the reported
layout to be byte-for-byte identical.

Run: python test-header-abi.py
"""

import os
import pathlib
import shlex
import shutil
import subprocess
import sys

HERE = pathlib.Path(__file__).parent.resolve()
SOURCE = HERE / "test_header_abi.f90"


def prefix_paths():
    prefix = os.environ.get("PREFIX") or os.environ.get("CONDA_PREFIX") or sys.prefix
    library = pathlib.Path(prefix) / "Library"
    if not library.is_dir():           # unix layout
        library = pathlib.Path(prefix)
    return library / "include", library / "lib"


def compiler_invocation(int64):
    """Return (argv_prefix, label) for the Fortran compiler in this variant."""
    if shutil.which("ifx"):
        argv = ["ifx", "/nologo"]
        if int64:
            argv.append("/integer-size:64")
        return argv, "ifx"
    for name in ("flang", "flang-new", "gfortran"):
        exe = shutil.which(name)
        if exe:
            argv = [exe]
            if int64:
                argv.append("-fdefault-integer-8")
            return argv, name
    sys.exit("FAIL: no Fortran compiler (ifx/flang/gfortran) found on PATH")


def build_and_run(workdir, int64):
    include, libdir = prefix_paths()
    argv, label = compiler_invocation(int64)
    exe = workdir / ("probe_i8.exe" if int64 else "probe_def.exe")

    # Honour the compiler flags the conda activation scripts export, exactly
    # as run_test-seq.sh does. On Windows flang needs -fms-runtime-lib=dll
    # and -fuse-ld=lld from FFLAGS to find its runtime.
    flags = shlex.split(os.environ.get("FFLAGS", "")) +             shlex.split(os.environ.get("LDFLAGS", ""))

    if label == "ifx":
        # ifx wants /exe:<file>; a glued "/o<file>" is silently ignored.
        argv += flags + [f"/I{include}", f"/I{include / 'mumps_seq'}",
                         f"/exe:{exe}", str(SOURCE)]
    else:
        argv += flags + [f"-I{include}", f"-I{include / 'mumps_seq'}",
                         "-o", str(exe), str(SOURCE)]

    print(f"[{'int64' if int64 else 'default'}] {' '.join(argv)}", flush=True)
    build = subprocess.run(argv, cwd=workdir, capture_output=True, text=True)
    if build.returncode != 0:
        print(build.stdout)
        print(build.stderr, file=sys.stderr)
        sys.exit(f"FAIL: the installed headers did not compile with {label}"
                 f"{' under a 64-bit default INTEGER' if int64 else ''}")

    run = subprocess.run([str(exe)], cwd=workdir, capture_output=True, text=True)
    if run.returncode != 0:
        print(run.stdout)
        print(run.stderr, file=sys.stderr)
        sys.exit("FAIL: probe program did not run")

    layout = {}
    for line in run.stdout.splitlines():
        if "=" in line:
            key, _, value = line.partition("=")
            layout[key.strip()] = value.strip()
    if not layout:
        sys.exit(f"FAIL: probe produced no output\n{run.stdout}")
    return layout


def main():
    workdir = pathlib.Path(os.getcwd())
    default = build_and_run(workdir, int64=False)
    int64 = build_and_run(workdir, int64=True)

    # Guard against a vacuous pass: if the 64-bit flag were silently ignored
    # the two builds would trivially agree and prove nothing.
    if default.get("DEFAULT_INTEGER") != "4":
        sys.exit(f"FAIL: expected a 4-byte default INTEGER, got "
                 f"{default.get('DEFAULT_INTEGER')}")
    if int64.get("DEFAULT_INTEGER") != "8":
        sys.exit("FAIL: the 64-bit default INTEGER flag had no effect "
                 f"(got {int64.get('DEFAULT_INTEGER')}) -- this test would "
                 "otherwise pass vacuously")

    keys = sorted(set(default) | set(int64))
    mismatched = [
        (k, default.get(k), int64.get(k))
        for k in keys
        if k != "DEFAULT_INTEGER" and default.get(k) != int64.get(k)
    ]

    width = max(len(k) for k in keys)
    print("\n%-*s  %10s  %10s" % (width, "field", "default", "int64"))
    for k in keys:
        if k == "DEFAULT_INTEGER":
            continue
        flag = "  <-- MISMATCH" if default.get(k) != int64.get(k) else ""
        print("%-*s  %10s  %10s%s" % (width, k, default.get(k), int64.get(k), flag))

    if mismatched:
        print()
        sys.exit(
            "FAIL: the installed MUMPS headers are not default-INTEGER "
            "agnostic. %d field(s) change size when the consumer compiles "
            "with a 64-bit default INTEGER, so the derived type no longer "
            "matches the compiled library. Check that "
            "make_integers_explicit.py covered every declaration."
            % len(mismatched)
        )

    print("\nOK: header layout is identical under 4-byte and 8-byte default "
          "INTEGER (%d fields checked)" % (len(keys) - 1))


if __name__ == "__main__":
    main()
