@echo on

set src=%cd%

cd work
copy %RECIPE_DIR%\CMakeLists.txt %src%\CMakeLists.txt

:: LP64: use 32-bit MUMPS_INT (matches Linux/conda-forge default)
copy %src%\src\mumps_int_def32_h.in %src%\include\mumps_int_def.h

:: For ifx: set up compiler paths and name-mangling flags
set "MUMPS_USE_IFX=OFF"
set "EXTRA_FC_FLAGS="
set "FC_COMPILER_ARG="
where ifx >nul 2>nul
if not errorlevel 1 (
    :: Set up Intel Fortran compiler paths from conda build prefix
    set "PATH=%BUILD_PREFIX%\Library\bin\compiler;%BUILD_PREFIX%\Library\bin;%BUILD_PREFIX%\Scripts;%PATH%"
    set "LIB=%BUILD_PREFIX%\Library\lib;%LIB%"
    set "INCLUDE=%BUILD_PREFIX%\opt\compiler\include\intel64;%BUILD_PREFIX%\Library\include;%INCLUDE%"
    set FC=ifx
    set "FC_COMPILER_ARG=-DCMAKE_Fortran_COMPILER=ifx"
    :: Force lowercase+underscore naming to match -DAdd_ convention.
    :: CMake's compiler ID detection may not recognise conda-packaged ifx.
    set "EXTRA_FC_FLAGS=/names:lowercase /assume:underscore /nologo"
    set "MUMPS_USE_IFX=ON"
    if errorlevel 1 exit 1
)
echo MUMPS build: MUMPS_USE_IFX=%MUMPS_USE_IFX% scotch_intsize=%scotch_intsize%

mkdir build
cd build

:: Configure
cmake -G "Ninja" ^
      %FC_COMPILER_ARG% ^
      -DCMAKE_PREFIX_PATH=%LIBRARY_PREFIX% ^
      -DCMAKE_INSTALL_PREFIX:PATH=%LIBRARY_PREFIX% ^
      -DCMAKE_BUILD_TYPE:STRING=Release ^
      -DCMAKE_Fortran_FLAGS="%EXTRA_FC_FLAGS%" ^
      -DMUMPS_USE_IFX=%MUMPS_USE_IFX% ^
      ..
if errorlevel 1 exit 1
cmake --build . --config Release --target install
if errorlevel 1 exit 1

:: Patch installed headers: make INTEGER/LOGICAL kinds explicit so that
:: code_aster's global /integer-size:64 does not inflate MUMPS struct fields.
:: MUMPS is LP64 (4-byte default integer); without this, the struct layout
:: in code_aster would mismatch the MUMPS DLL.
python %RECIPE_DIR%\make_integers_explicit.py %LIBRARY_PREFIX%\include
if errorlevel 1 exit 1

:: Verify simpletests
%src%\build\c_example < %src%\examples\input_simpletest_real
if errorlevel 1 exit 1
%src%\build\ssimpletest < %src%\examples\input_simpletest_real
if errorlevel 1 exit 1
%src%\build\dsimpletest < %src%\examples\input_simpletest_real
if errorlevel 1 exit 1
%src%\build\csimpletest < %src%\examples\input_simpletest_cmplx
if errorlevel 1 exit 1
%src%\build\zsimpletest < %src%\examples\input_simpletest_cmplx
if errorlevel 1 exit 1
