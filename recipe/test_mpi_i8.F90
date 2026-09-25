! MPI MUMPS called from Fortran the way code_aster calls it on Windows:
! compiled with ifx /integer-size:64 /real-size:64 /names:lowercase
! /assume:underscore, i.e. a 64-bit default INTEGER in the caller while MUMPS
! and MPI are LP64. Every MPI/MUMPS argument therefore carries an explicit
! kind, and the installed *mumps_struc.h must keep the library layout.
!
! Solves the 5x5 system of examples/input_simpletest_real (solution 1..5)
! twice: centralized input on the host, then distributed assembled input
! (ICNTL(18)=3) split over the ranks.
!
! mpif.h constants are INTEGER PARAMETERs, i.e. 8-byte under
! /integer-size:64: convert them to integer(4) before passing them to MPI.
! Do NOT use the COMMON-block "constants" (MPI_IN_PLACE, MPI_BOTTOM,
! MPI_STATUS_IGNORE) from such a caller: /integer-size:64 changes the layout of
! COMMON /MPIPRIV1/, so their addresses no longer match the library's.
program test_mpi_i8
  implicit none
  include 'mpif.h'
  include 'dmumps_struc.h'
  type(dmumps_struc) :: id
  integer(4) :: ierr, rank, nprocs, i, k, nloc, comm, dp, opmax
  integer(4), parameter :: n = 5, nz = 12
  integer(4) :: irn(nz), jcn(nz)
  real(8) :: a(nz), rhs(n), err(1), errmax(1)
  integer(8) :: isize
  data irn /1, 2, 4, 5, 2, 1, 5, 3, 2, 3, 1, 3/
  data jcn /2, 3, 3, 5, 1, 1, 2, 4, 5, 2, 3, 3/
  data a /3d0, -3d0, 2d0, 1d0, 3d0, 2d0, 4d0, 2d0, 6d0, -1d0, 4d0, 1d0/
  data rhs /20d0, 24d0, 9d0, 6d0, 13d0/

  isize = 0
  if (storage_size(isize) /= 64 .or. storage_size(0) /= 64) then
    print *, 'FAIL: test must be compiled with a 64-bit default INTEGER'
    stop 2
  end if

  comm = int(MPI_COMM_WORLD, 4)
  dp = int(MPI_DOUBLE_PRECISION, 4)
  opmax = int(MPI_MAX, 4)
  call mpi_init(ierr)
  call mpi_comm_rank(comm, rank, ierr)
  call mpi_comm_size(comm, nprocs, ierr)

  do k = 1, 2
    id%comm = comm
    id%par = 1
    id%sym = 0
    id%job = -1
    call dmumps(id)
    id%icntl(1:4) = [6, 0, 6, 1]
    if (rank == 0) then
      id%n = n
      allocate (id%rhs(n))
      id%rhs = rhs
    end if
    if (k == 1) then
      ! centralized assembled matrix on the host
      if (rank == 0) then
        id%nnz = nz
        allocate (id%irn(nz), id%jcn(nz), id%a(nz))
        id%irn = irn
        id%jcn = jcn
        id%a = a
      end if
    else
      ! distributed assembled matrix: entries dealt round-robin over ranks
      id%icntl(18) = 3
      id%n = n
      nloc = 0
      do i = 1, nz
        if (mod(i - 1, nprocs) == rank) nloc = nloc + 1
      end do
      id%nnz_loc = nloc
      allocate (id%irn_loc(nloc), id%jcn_loc(nloc), id%a_loc(nloc))
      nloc = 0
      do i = 1, nz
        if (mod(i - 1, nprocs) == rank) then
          nloc = nloc + 1
          id%irn_loc(nloc) = irn(i)
          id%jcn_loc(nloc) = jcn(i)
          id%a_loc(nloc) = a(i)
        end if
      end do
    end if
    id%job = 6
    call dmumps(id)
    if (id%infog(1) /= 0) then
      print *, 'FAIL: rank', rank, 'INFOG(1)=', id%infog(1), 'INFOG(2)=', id%infog(2)
      call mpi_abort(comm, 1_4, ierr)
    end if
    err(1) = 0d0
    if (rank == 0) then
      do i = 1, n
        err(1) = max(err(1), abs(id%rhs(i) - dble(i)))
      end do
      print '(A,I0,A,5F10.5)', 'case ', k, ' solution:', id%rhs
    end if
    call mpi_allreduce(err, errmax, 1_4, dp, opmax, comm, ierr)
    if (errmax(1) > 1d-10) then
      if (rank == 0) print *, 'FAIL: case', k, 'max error', errmax(1)
      call mpi_abort(comm, 1_4, ierr)
    end if
    if (rank == 0) then
      deallocate (id%rhs)
      if (k == 1) deallocate (id%irn, id%jcn, id%a)
    end if
    if (k == 2) deallocate (id%irn_loc, id%jcn_loc, id%a_loc)
    id%job = -2
    call dmumps(id)
  end do

  if (rank == 0) print '(A,I0,A)', 'OK: MPI MUMPS from a 64-bit-INTEGER caller on ', nprocs, ' ranks'
  call mpi_finalize(ierr)
end program test_mpi_i8
