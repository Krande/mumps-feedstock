@echo on
:: Windows mumps-mpi test (Intel MPI, ifx ABI).
:: 1. Fortran consumer compiled like code_aster (/integer-size:64 /real-size:64
::    /names:lowercase /assume:underscore) solving under mpiexec -n 2.
:: 2. The bundled Fortran simpletest (default integers) and the C example.
setlocal

set "LIB=%PREFIX%\Library\lib;%LIB%"
set "INCLUDE=%PREFIX%\opt\compiler\include\intel64;%PREFIX%\Library\include;%INCLUDE%"
set "PATH=%PREFIX%\Library\bin\compiler;%PREFIX%\Library\bin;%PATH%"
set "INC=/I%PREFIX%\Library\include"
set "LIBS=dmumps.lib impi.lib"

ifx /nologo /fpp /MD /integer-size:64 /real-size:64 /names:lowercase /assume:underscore ^
    %INC% test_mpi_i8.F90 /exe:test_mpi_i8.exe /link /LIBPATH:%PREFIX%\Library\lib %LIBS%
if errorlevel 1 exit 1
mpiexec -n 2 test_mpi_i8.exe
if errorlevel 1 exit 1

cd examples
ifx /nologo /MD /names:lowercase /assume:underscore %INC% dsimpletest.F /exe:dsimpletest.exe ^
    /link /LIBPATH:%PREFIX%\Library\lib %LIBS%
if errorlevel 1 exit 1
mpiexec -n 2 dsimpletest.exe < input_simpletest_real
if errorlevel 1 exit 1

ifx /nologo /MD /names:lowercase /assume:underscore %INC% zsimpletest.F /exe:zsimpletest.exe ^
    /link /LIBPATH:%PREFIX%\Library\lib zmumps.lib impi.lib
if errorlevel 1 exit 1
mpiexec -n 2 zsimpletest.exe < input_simpletest_cmplx
if errorlevel 1 exit 1

%CC% /nologo /MD %INC% c_example.c /Fe:c_example.exe /link /LIBPATH:%PREFIX%\Library\lib %LIBS%
if errorlevel 1 exit 1
mpiexec -n 2 c_example.exe
if errorlevel 1 exit 1
