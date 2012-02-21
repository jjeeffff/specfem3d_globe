!=====================================================================
!
!          S p e c f e m 3 D  G l o b e  V e r s i o n  5 . 1
!          --------------------------------------------------
!
!          Main authors: Dimitri Komatitsch and Jeroen Tromp
!                        Princeton University, USA
!             and University of Pau / CNRS / INRIA, France
! (c) Princeton University / California Institute of Technology and University of Pau / CNRS / INRIA
!                            April 2011
!
! This program is free software; you can redistribute it and/or modify
! it under the terms of the GNU General Public License as published by
! the Free Software Foundation; either version 2 of the License, or
! (at your option) any later version.
!
! This program is distributed in the hope that it will be useful,
! but WITHOUT ANY WARRANTY; without even the implied warranty of
! MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
! GNU General Public License for more details.
!
! You should have received a copy of the GNU General Public License along
! with this program; if not, write to the Free Software Foundation, Inc.,
! 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
!
!=====================================================================

  subroutine finalize_simulation()

  use specfem_par
  use specfem_par_crustmantle
  use specfem_par_innercore
  use specfem_par_outercore
  use specfem_par_movie
  implicit none

  ! synchronize all processes, waits until all processes have written their seismograms
  call sync_all()

  ! closes Stacey absorbing boundary snapshots
  if( ABSORBING_CONDITIONS ) then
    ! crust mantle
    if (nspec2D_xmin_crust_mantle > 0 .and. (SIMULATION_TYPE == 3 &
      .or. (SIMULATION_TYPE == 1 .and. SAVE_FORWARD))) then
      call close_file_abs(0)
    endif

    if (nspec2D_xmax_crust_mantle > 0 .and. (SIMULATION_TYPE == 3 &
      .or. (SIMULATION_TYPE == 1 .and. SAVE_FORWARD))) then
      call close_file_abs(1)
    endif

    if (nspec2D_ymin_crust_mantle > 0 .and. (SIMULATION_TYPE == 3 &
      .or. (SIMULATION_TYPE == 1 .and. SAVE_FORWARD))) then
      call close_file_abs(2)
    endif

    if (nspec2D_ymax_crust_mantle > 0 .and. (SIMULATION_TYPE == 3 &
      .or. (SIMULATION_TYPE == 1 .and. SAVE_FORWARD))) then
      call close_file_abs(3)
    endif

    ! outer core
    if (nspec2D_xmin_outer_core > 0 .and. (SIMULATION_TYPE == 3 &
      .or. (SIMULATION_TYPE == 1 .and. SAVE_FORWARD))) then
      call close_file_abs(4)
    endif

    if (nspec2D_xmax_outer_core > 0 .and. (SIMULATION_TYPE == 3 &
      .or. (SIMULATION_TYPE == 1 .and. SAVE_FORWARD))) then
      call close_file_abs(5)
    endif

    if (nspec2D_ymin_outer_core > 0 .and. (SIMULATION_TYPE == 3 &
      .or. (SIMULATION_TYPE == 1 .and. SAVE_FORWARD))) then
      call close_file_abs(6)
    endif

    if (nspec2D_ymax_outer_core > 0 .and. (SIMULATION_TYPE == 3 &
      .or. (SIMULATION_TYPE == 1 .and. SAVE_FORWARD))) then
      call close_file_abs(7)
    endif

    if (nspec2D_zmin_outer_core > 0 .and. (SIMULATION_TYPE == 3 &
      .or. (SIMULATION_TYPE == 1 .and. SAVE_FORWARD))) then
      call close_file_abs(8)
    endif

    ! frees memory
    deallocate(absorb_xmin_crust_mantle, &
              absorb_xmax_crust_mantle, &
              absorb_ymin_crust_mantle, &
              absorb_ymax_crust_mantle, &
              absorb_xmin_outer_core, &
              absorb_xmax_outer_core, &
              absorb_ymin_outer_core, &
              absorb_ymax_outer_core, &
              absorb_zmin_outer_core)
  endif

  ! save/read the surface movie using the same c routine as we do for absorbing boundaries (file ID is 9)
  if (NOISE_TOMOGRAPHY/=0) then
    call close_file_abs(9)
  endif

  ! synchronize all processes
  call sync_all()

  ! save files to local disk or tape system if restart file
  call save_forward_arrays()

  ! synchronize all processes
  call sync_all()

  ! dump kernel arrays
  if (SIMULATION_TYPE == 3) then
    ! crust mantle
    call save_kernels_crust_mantle(myrank,scale_t,scale_displ, &
                  cijkl_kl_crust_mantle,rho_kl_crust_mantle, &
                  alpha_kl_crust_mantle,beta_kl_crust_mantle, &
                  ystore_crust_mantle,zstore_crust_mantle, &
                  rhostore_crust_mantle,muvstore_crust_mantle, &
                  kappavstore_crust_mantle,ibool_crust_mantle, &
                  kappahstore_crust_mantle,muhstore_crust_mantle, &
                  eta_anisostore_crust_mantle,ispec_is_tiso_crust_mantle, &
              ! --idoubling_crust_mantle, &
                  LOCAL_PATH)

    ! noise strength kernel
    if (NOISE_TOMOGRAPHY == 3) then
       call save_kernels_strength_noise(myrank,LOCAL_PATH,Sigma_kl_crust_mantle)
    endif

    ! outer core
    call save_kernels_outer_core(myrank,scale_t,scale_displ, &
                        rho_kl_outer_core,alpha_kl_outer_core, &
                        rhostore_outer_core,kappavstore_outer_core, &
                        deviatoric_outercore,nspec_beta_kl_outer_core,beta_kl_outer_core, &
                        LOCAL_PATH)

    ! inner core
    call save_kernels_inner_core(myrank,scale_t,scale_displ, &
                          rho_kl_inner_core,beta_kl_inner_core,alpha_kl_inner_core, &
                          rhostore_inner_core,muvstore_inner_core,kappavstore_inner_core, &
                          LOCAL_PATH)

    ! boundary kernel
    if (SAVE_BOUNDARY_MESH) then
      call save_kernels_boundary_kl(myrank,scale_t,scale_displ, &
                                  moho_kl,d400_kl,d670_kl,cmb_kl,icb_kl, &
                                  LOCAL_PATH,HONOR_1D_SPHERICAL_MOHO)
    endif

    ! approximate hessian
    if( APPROXIMATE_HESS_KL ) then
      call save_kernels_hessian(myrank,scale_t,scale_displ, &
                                            hess_kl_crust_mantle,LOCAL_PATH)
    endif
  endif

  ! save source derivatives for adjoint simulations
  if (SIMULATION_TYPE == 2 .and. nrec_local > 0) then
    call save_kernels_source_derivatives(nrec_local,NSOURCES,scale_displ,scale_t, &
                                nu_source,moment_der,sloc_der,stshift_der,shdur_der,number_receiver_global)
  endif

  ! frees dynamically allocated memory
  ! mpi buffers
  deallocate(buffer_send_faces, &
            buffer_received_faces, &
            b_buffer_send_faces, &
            b_buffer_received_faces)

  ! central cube buffers
  deallocate(sender_from_slices_to_cube, &
            buffer_all_cube_from_slices, &
            b_buffer_all_cube_from_slices, &
            buffer_slices, &
            b_buffer_slices, &
            buffer_slices2, &
            ibool_central_cube)

  ! sources
  deallocate(islice_selected_source, &
          ispec_selected_source, &
          Mxx, &
          Myy, &
          Mzz, &
          Mxy, &
          Mxz, &
          Myz, &
          xi_source, &
          eta_source, &
          gamma_source, &
          tshift_cmt, &
          hdur, &
          hdur_gaussian, &
          theta_source, &
          phi_source, &
          nu_source)
  if (SIMULATION_TYPE == 1  .or. SIMULATION_TYPE == 3) deallocate(sourcearrays)
  if (SIMULATION_TYPE == 2 .or. SIMULATION_TYPE == 3) then
    deallocate(iadj_vec)
    if(nadj_rec_local > 0) then
      deallocate(adj_sourcearrays)
      deallocate(iadjsrc,iadjsrc_len)
    endif
  endif

  ! receivers
  deallocate(islice_selected_rec, &
          ispec_selected_rec, &
          xi_receiver, &
          eta_receiver, &
          gamma_receiver, &
          station_name, &
          network_name, &
          stlat, &
          stlon, &
          stele, &
          stbur, &
          nu, &
          number_receiver_global)
  if( nrec_local > 0 ) then
    deallocate(hxir_store, &
              hetar_store, &
              hgammar_store)
    if( SIMULATION_TYPE == 2 ) then
      deallocate(moment_der,stshift_der)
    endif
  endif
  deallocate(seismograms)

  if (SIMULATION_TYPE == 3) then
    if( APPROXIMATE_HESS_KL ) then
      deallocate(hess_kl_crust_mantle)
    endif
    deallocate(beta_kl_outer_core)
  endif

  ! movies
  if(MOVIE_SURFACE .or. NOISE_TOMOGRAPHY /= 0 ) then
    deallocate(store_val_x, &
              store_val_y, &
              store_val_z, &
              store_val_ux, &
              store_val_uy, &
              store_val_uz)
    if (MOVIE_SURFACE) then
      deallocate(store_val_x_all, &
            store_val_y_all, &
            store_val_z_all, &
            store_val_ux_all, &
            store_val_uy_all, &
            store_val_uz_all)
    endif
  endif
  if(MOVIE_VOLUME) then
    deallocate(nu_3dmovie)
  endif

  ! noise simulations
  if ( NOISE_TOMOGRAPHY /= 0 ) then
    deallocate(noise_sourcearray, &
            normal_x_noise, &
            normal_y_noise, &
            normal_z_noise, &
            mask_noise, &
            noise_surface_movie)
  endif

  ! close the main output file
  if(myrank == 0) then
    write(IMAIN,*)
    write(IMAIN,*) 'End of the simulation'
    write(IMAIN,*)
    close(IMAIN)
  endif

  ! synchronize all the processes to make sure everybody has finished
  call sync_all()

  end subroutine finalize_simulation
