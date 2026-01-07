/* -----------------------------------------------------------------
 * Programmer(s): Cody J. Balos, Aaron Collier and Radu Serban @ LLNL
 * -----------------------------------------------------------------
 * SUNDIALS Copyright Start
 * Copyright (c) 2002-2023, Lawrence Livermore National Security
 * and Southern Methodist University.
 * All rights reserved.
 *
 * See the top-level LICENSE and NOTICE files for details.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 * SUNDIALS Copyright End
 * -----------------------------------------------------------------
 * SUNDIALS configuration header file.
 * -----------------------------------------------------------------*/

#ifndef _SUNDIALS_CONFIG_H
#define _SUNDIALS_CONFIG_H

#include "sundials/sundials_export.h"

#ifndef SUNDIALS_DEPRECATED_MSG
#  define SUNDIALS_DEPRECATED_MSG(msg) __attribute__ ((__deprecated__(msg)))
#endif

#ifndef SUNDIALS_DEPRECATED_EXPORT_MSG
#  define SUNDIALS_DEPRECATED_EXPORT_MSG(msg) SUNDIALS_EXPORT SUNDIALS_DEPRECATED_MSG(msg)
#endif

#ifndef SUNDIALS_DEPRECATED_NO_EXPORT_MSG
#  define SUNDIALS_DEPRECATED_NO_EXPORT_MSG(msg) SUNDIALS_NO_EXPORT SUNDIALS_DEPRECATED_MSG(msg)
#endif

/* ------------------------------------------------------------------
 * Define SUNDIALS version numbers
 * -----------------------------------------------------------------*/


#define SUNDIALS_VERSION "6.7.0"
#define SUNDIALS_VERSION_MAJOR 6
#define SUNDIALS_VERSION_MINOR 7
#define SUNDIALS_VERSION_PATCH 0
#define SUNDIALS_VERSION_LABEL ""
#define SUNDIALS_GIT_VERSION ""


/* ------------------------------------------------------------------
 * SUNDIALS build information
 * -----------------------------------------------------------------*/

#define SUNDIALS_C_COMPILER_HAS_MATH_PRECISIONS
#define SUNDIALS_C_COMPILER_HAS_ISINF_ISNAN
#define SUNDIALS_C_COMPILER_HAS_INLINE

/* Define precision of SUNDIALS data type 'realtype'
 * Depending on the precision level, one of the following
 * three macros will be defined:
 *     #define SUNDIALS_SINGLE_PRECISION 1
 *     #define SUNDIALS_DOUBLE_PRECISION 1
 *     #define SUNDIALS_EXTENDED_PRECISION 1
 */
#define SUNDIALS_DOUBLE_PRECISION 1

/* Define type of vector indices in SUNDIALS 'sunindextype'.
 * Depending on user choice of index type, one of the following
 * two macros will be defined:
 *     #define SUNDIALS_INT64_T 1
 *     #define SUNDIALS_INT32_T 1
 */
#define SUNDIALS_INT64_T 1

/* Define the type of vector indices in SUNDIALS 'sunindextype'.
 * The macro will be defined with a type of the appropriate size.
 */
#define SUNDIALS_INDEX_TYPE int64_t

/* Use std-c math functions
 * DEPRECATED SUNDIALS_USE_GENERIC_MATH
 */
/* #undef SUNDIALS_USE_GENERIC_MATH */

/* Use POSIX timers if available.
 *     #define SUNDIALS_HAVE_POSIX_TIMERS
 */
#define SUNDIALS_HAVE_POSIX_TIMERS

/* BUILD CVODE with fused kernel functionality */
/* #undef SUNDIALS_BUILD_PACKAGE_FUSED_KERNELS */

/* BUILD SUNDIALS with monitoring functionalities */
/* #undef SUNDIALS_BUILD_WITH_MONITORING */

/* BUILD SUNDIALS with profiling functionalities */
/* #undef SUNDIALS_BUILD_WITH_PROFILING */

/* BUILD SUNDIALS with logging functionalities */
#define SUNDIALS_LOGGING_LEVEL 0

/* BUILD SUNDIALS with MPI-enabled logging */
/* #undef SUNDIALS_LOGGING_ENABLE_MPI */

/* Is snprintf available? */
#define SUNDIALS_C_COMPILER_HAS_SNPRINTF_AND_VA_COPY
#ifndef SUNDIALS_C_COMPILER_HAS_SNPRINTF_AND_VA_COPY
#define SUNDIALS_MAX_SPRINTF_SIZE 
#endif

/* Build metadata */
#define SUN_C_COMPILER "Clang"
#define SUN_C_COMPILER_VERSION "18.0.0"
#define SUN_C_COMPILER_FLAGS ""

#define SUN_CXX_COMPILER "Clang"
#define SUN_CXX_COMPILER_VERSION "18.0.0"
#define SUN_CXX_COMPILER_FLAGS ""

#define SUN_FORTRAN_COMPILER ""
#define SUN_FORTRAN_COMPILER_VERSION ""
#define SUN_FORTRAN_COMPILER_FLAGS ""

#define SUN_BUILD_TYPE ""

#define SUN_JOB_ID "20231220201619"
#define SUN_JOB_START_TIME "20231220201619"

#define SUN_TPL_LIST ""
#define SUN_TPL_LIST_SIZE ""

#define SUNDIALS_SPACK_VERSION ""

/* ------------------------------------------------------------------
 * SUNDIALS TPL macros
 * -----------------------------------------------------------------*/

/* Caliper */
/* #undef SUNDIALS_CALIPER_ENABLED */

/* Adiak */
/* #undef SUNDIALS_ADIAK_ENABLED */

/* Ginkgo */
/* #undef SUNDIALS_GINKGO_ENABLED */
#define SUN_GINKGO_VERSION ""

/* HYPRE */
/* #undef SUNDIALS_HYPRE_ENABLED */
#define SUN_HYPRE_VERSION ""

/* KLU */
/* #undef SUNDIALS_KLU_ENABLED */
#define SUN_KLU_VERSION ""

/* KOKKOS */
/* #undef SUNDIALS_KOKKOS_ENABLED */
#define SUN_KOKKOS_VERSION ""

/* KOKKOS_KERNELS */
/* #undef SUNDIALS_KOKKOS_KERNELS_ENABLED */
#define SUN_KOKKOS_KERNELS_VERSION ""

/* LAPACK */
/* #undef SUNDIALS_BLAS_LAPACK_ENABLED */
#define SUN_LAPACK_VERSION ""

/* MAGMA */
/* #undef SUNDIALS_MAGMA_ENABLED */
#define SUN_MAGMA_VERSION ""

/* MPI */
#define SUN_MPI_C_COMPILER ""
#define SUN_MPI_C_VERSION ""

#define SUN_MPI_CXX_COMPILER ""
#define SUN_MPI_CXX_VERSION ""

#define SUN_MPI_FORTRAN_COMPILER ""
#define SUN_MPI_FORTRAN_VERSION ""

/* ONEMKL */
/* #undef SUNDIALS_ONEMKL_ENABLED */
#define SUN_ONEMKL_VERSION ""

/* OpenMP */
/* #undef SUNDIALS_OPENMP_ENABLED */
#define SUN_OPENMP_VERSION ""

/* PETSC */
/* #undef SUNDIALS_PETSC_ENABLED */
#define SUN_PETSC_VERSION ""

/* PTHREADS */
/* #undef SUNDIALS_PTHREADS_ENABLED */
#define SUN_PTHREADS_VERSION ""

/* RAJA */
/* #undef SUNDIALS_RAJA_ENABLED */
#define SUN_RAJA_VERSION ""

/* SUPERLUDIST */
/* #undef SUNDIALS_SUPERLUDIST_ENABLED */
#define SUN_SUPERLUDIST_VERSION ""

/* SUPERLUMT */
/* #undef SUNDIALS_SUPERLUMT_ENABLED */
#define SUN_SUPERLUMT_VERSION ""

/* TRILLINOS */
/* #undef SUNDIALS_TRILLINOS_ENABLED */
#define SUN_TRILLINOS_VERSION ""

/* XBRAID */
/* #undef SUNDIALS_XBRAID_ENABLED */
#define SUN_XBRAID_VERSION ""

/* RAJA backends */
/* #undef SUNDIALS_RAJA_BACKENDS_CUDA */
/* #undef SUNDIALS_RAJA_BACKENDS_HIP */
/* #undef SUNDIALS_RAJA_BACKENDS_SYCL */

/* Ginkgo backends */
/* #undef SUNDIALS_GINKGO_BACKENDS_CUDA */
/* #undef SUNDIALS_GINKGO_BACKENDS_HIP */
/* #undef SUNDIALS_GINKGO_BACKENDS_OMP */
/* #undef SUNDIALS_GINKGO_BACKENDS_REF */
/* #undef SUNDIALS_GINKGO_BACKENDS_DPCPP */

/* MAGMA backends */
/* #undef SUNDIALS_MAGMA_BACKENDS_CUDA */
/* #undef SUNDIALS_MAGMA_BACKENDS_HIP */

/* Set if SUNDIALS is built with MPI support, then
 *     #define SUNDIALS_MPI_ENABLED 1
 * otherwise
 *     #define SUNDIALS_MPI_ENABLED 0
 */
#define SUNDIALS_MPI_ENABLED 0

/* oneMKL interface options */
/* #undef SUNDIALS_ONEMKL_USE_GETRF_LOOP */
/* #undef SUNDIALS_ONEMKL_USE_GETRS_LOOP */

/* SUPERLUMT threading type */
#define SUNDIALS_SUPERLUMT_THREAD_TYPE ""

/* Trilinos with MPI is available, then
 *    #define SUNDIALS_TRILINOS_HAVE_MPI
 */
/* #undef SUNDIALS_TRILINOS_HAVE_MPI */


/* ------------------------------------------------------------------
 * SUNDIALS language macros
 * -----------------------------------------------------------------*/

/* CUDA */
/* #undef SUNDIALS_CUDA_ENABLED */
#define SUN_CUDA_VERSION ""
#define SUN_CUDA_COMPILER ""
#define SUN_CUDA_ARCHITECTURES ""

/* HIP */
/* #undef SUNDIALS_HIP_ENABLED */
#define SUN_HIP_VERSION ""
#define SUN_AMDGPU_TARGETS ""

/* SYCL options */
/* #undef SUNDIALS_SYCL_2020_UNSUPPORTED */


/* ------------------------------------------------------------------
 * SUNDIALS modules enabled
 * -----------------------------------------------------------------*/

#define SUNDIALS_ARKODE 1
#define SUNDIALS_CVODE 1
#define SUNDIALS_CVODES 1
#define SUNDIALS_IDA 1
#define SUNDIALS_IDAS 1
#define SUNDIALS_KINSOL 1
#define SUNDIALS_NVECTOR_SERIAL 1
#define SUNDIALS_NVECTOR_MANYVECTOR 1
#define SUNDIALS_SUNMATRIX_BAND 1
#define SUNDIALS_SUNMATRIX_DENSE 1
#define SUNDIALS_SUNMATRIX_SPARSE 1
#define SUNDIALS_SUNLINSOL_BAND 1
#define SUNDIALS_SUNLINSOL_DENSE 1
#define SUNDIALS_SUNLINSOL_PCG 1
#define SUNDIALS_SUNLINSOL_SPBCGS 1
#define SUNDIALS_SUNLINSOL_SPFGMR 1
#define SUNDIALS_SUNLINSOL_SPGMR 1
#define SUNDIALS_SUNLINSOL_SPTFQMR 1
#define SUNDIALS_SUNNONLINSOL_NEWTON 1
#define SUNDIALS_SUNNONLINSOL_FIXEDPOINT 1



/* ------------------------------------------------------------------
 * SUNDIALS fortran configuration
 * -----------------------------------------------------------------*/


/* Define Fortran name-mangling macro for C identifiers.
 * Depending on the inferred scheme, one of the following six
 * macros will be defined:
 *     #define SUNDIALS_F77_FUNC(name,NAME) name
 *     #define SUNDIALS_F77_FUNC(name,NAME) name ## _
 *     #define SUNDIALS_F77_FUNC(name,NAME) name ## __
 *     #define SUNDIALS_F77_FUNC(name,NAME) NAME
 *     #define SUNDIALS_F77_FUNC(name,NAME) NAME ## _
 *     #define SUNDIALS_F77_FUNC(name,NAME) NAME ## __
 */


/* Define Fortran name-mangling macro for C identifiers
 * which contain underscores.
 */


/* Allow user to specify different MPI communicator
 * If it was found that the MPI implementation supports MPI_Comm_f2c, then
 *      #define SUNDIALS_MPI_COMM_F2C 1
 * otherwise
 *      #define SUNDIALS_MPI_COMM_F2C 0
 */



/* ------------------------------------------------------------------
 * SUNDIALS inline macros.
 * -----------------------------------------------------------------*/


/* Mark SUNDIALS function as inline.
 */
#ifndef SUNDIALS_CXX_INLINE
#define SUNDIALS_CXX_INLINE inline
#endif

#ifndef SUNDIALS_C_INLINE
#ifdef SUNDIALS_C_COMPILER_HAS_INLINE
#define SUNDIALS_C_INLINE inline
#else
#define SUNDIALS_C_INLINE
#endif
#endif

#ifdef __cplusplus
#define SUNDIALS_INLINE SUNDIALS_CXX_INLINE
#else
#define SUNDIALS_INLINE SUNDIALS_C_INLINE
#endif

/* Mark SUNDIALS function as static inline.
 */
#define SUNDIALS_STATIC_INLINE static SUNDIALS_INLINE

#endif /* _SUNDIALS_CONFIG_H */
