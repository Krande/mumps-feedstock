! Verify that the installed MUMPS Fortran headers describe the same storage
! layout regardless of the consumer's default INTEGER size.
!
! MUMPS is built LP64: the compiled libraries use 4-byte default INTEGERs.
! A downstream project such as code_aster compiles with a 64-bit default
! INTEGER (ifx /integer-size:64, flang -fdefault-integer-8). Unless every
! INTEGER/REAL/LOGICAL component in *mumps_struc.h is given an explicit kind,
! the derived type silently grows in the consumer and no longer matches the
! layout inside the DLL -- memory corruption, not a link error.
!
! Compiling this file twice (default integers, then 64-bit integers) and
! comparing the numbers below is what proves the headers are immunised.
program mumps_abi_check
  implicit none
  include 'smumps_struc.h'
  include 'dmumps_struc.h'
  include 'cmumps_struc.h'
  include 'zmumps_struc.h'
  type(smumps_struc) :: sid
  type(dmumps_struc) :: id
  type(cmumps_struc) :: cid
  type(zmumps_struc) :: zid

  write (*, '(A,I0)') 'DEFAULT_INTEGER=', storage_size(0)/8
  write (*, '(A,I0)') 'TOTAL=',  storage_size(id)/8
  write (*, '(A,I0)') 'COMM=',   storage_size(id%comm)/8
  write (*, '(A,I0)') 'SYM=',    storage_size(id%sym)/8
  write (*, '(A,I0)') 'PAR=',    storage_size(id%par)/8
  write (*, '(A,I0)') 'JOB=',    storage_size(id%job)/8
  write (*, '(A,I0)') 'N=',      storage_size(id%n)/8
  write (*, '(A,I0)') 'NZ=',     storage_size(id%nz)/8
  write (*, '(A,I0)') 'NNZ=',    storage_size(id%nnz)/8
  write (*, '(A,I0)') 'ICNTL=',  storage_size(id%icntl)/8
  write (*, '(A,I0)') 'CNTL=',   storage_size(id%cntl)/8
  write (*, '(A,I0)') 'INFO=',   storage_size(id%info)/8
  write (*, '(A,I0)') 'INFOG=',  storage_size(id%infog)/8
  write (*, '(A,I0)') 'RINFOG=', storage_size(id%rinfog)/8

  ! the other three arithmetics are patched by the same script
  write (*, '(A,I0)') 'S_TOTAL=', storage_size(sid)/8
  write (*, '(A,I0)') 'C_TOTAL=', storage_size(cid)/8
  write (*, '(A,I0)') 'Z_TOTAL=', storage_size(zid)/8
  write (*, '(A,I0)') 'S_N=',     storage_size(sid%n)/8
  write (*, '(A,I0)') 'C_N=',     storage_size(cid%n)/8
  write (*, '(A,I0)') 'Z_N=',     storage_size(zid%n)/8
end program mumps_abi_check
