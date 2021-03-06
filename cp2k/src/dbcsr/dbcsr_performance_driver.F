!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright (C) 2000 - 2016  CP2K developers group                                               !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \brief   Performance tester for DBCSR operations
!> \author  VW
!> \date    2010
!> \version 1.0
!>
!> <b>Modification history:</b>
!> - Created 2010
! **************************************************************************************************
PROGRAM dbcsr_performance_driver
   USE dbcsr_api,                       ONLY: dbcsr_finalize_lib,&
                                              dbcsr_init_lib,&
                                              dbcsr_mp_new,&
                                              dbcsr_mp_obj,&
                                              dbcsr_mp_release
   USE dbcsr_performance_multiply,      ONLY: dbcsr_perf_multiply
   USE dbcsr_test_methods,              ONLY: dbcsr_test_read_args
   USE kinds,                           ONLY: default_string_length
   USE machine,                         ONLY: default_output_unit
   USE message_passing,                 ONLY: mp_bcast,&
                                              mp_cart_create,&
                                              mp_cart_rank,&
                                              mp_comm_free,&
                                              mp_environ,&
                                              mp_world_finalize,&
                                              mp_world_init
#include "../base/base_uses.f90"

!$ USE OMP_LIB, ONLY: omp_get_max_threads, omp_get_thread_num, omp_get_num_threads

   IMPLICIT NONE

   INTEGER                                  :: mp_comm, group, numnodes, mynode, &
                                               prow, pcol, io_unit, narg, handle
   INTEGER, DIMENSION(2)                    :: npdims, myploc
   INTEGER, DIMENSION(:, :), POINTER         :: pgrid
   TYPE(dbcsr_mp_obj)                       :: mp_env
   CHARACTER(len=default_string_length)     :: args(100)

   CHARACTER(len=*), PARAMETER :: routineN = 'dbcsr_check_multiply'

   !***************************************************************************************

   !
   ! initialize libdbcsr errors
   CALL timeset(routineN, handle)

   !
   ! initialize mpi
   CALL mp_world_init(mp_comm)

   !
   ! setup the mp environment
   npdims(:) = 0
   CALL mp_cart_create(mp_comm, 2, npdims, myploc, group)
   CALL mp_environ(numnodes, mynode, group)
   ALLOCATE (pgrid(0:npdims(1)-1, 0:npdims(2)-1))
   DO prow = 0, npdims(1)-1
      DO pcol = 0, npdims(2)-1
         CALL mp_cart_rank(group, (/prow, pcol/), pgrid(prow, pcol))
      ENDDO
   ENDDO
   CALL dbcsr_mp_new(mp_env, pgrid, group, mynode, numnodes, &
                     myprow=myploc(1), mypcol=myploc(2))
   DEALLOCATE (pgrid)

   !
   ! set standard output parameters
   io_unit = 0
   IF (mynode .EQ. 0) io_unit = default_output_unit

   !
   ! read and distribute input args
   IF (mynode .EQ. 0) CALL dbcsr_test_read_args(narg, args)
   CALL mp_bcast(narg, 0, group)
   CALL mp_bcast(args, 0, group)
   IF (narg .LT. 1) &
      CPABORT("nargs not correct")

   !
   ! initialize libdbcsr
   CALL dbcsr_init_lib()

   !
   ! select the operation
   SELECT CASE (args (1))
   CASE ('dbcsr_multiply')
      CALL dbcsr_perf_multiply(group, mp_env, npdims, io_unit, narg, args)
   CASE DEFAULT
      CPABORT("operation not found")
   END SELECT

   !
   ! finalize libdbcsr
   CALL dbcsr_finalize_lib(mp_comm, io_unit)

   !
   ! clean mp enviroment
   CALL dbcsr_mp_release(mp_env)

   !
   ! finalize mpi
   CALL mp_comm_free(group)
   CALL mp_world_finalize()

   !
   ! finalize libdbcsr errors
   CALL timestop(handle)

END PROGRAM dbcsr_performance_driver
