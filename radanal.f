C     Last change:  LKS   8 Dec 2011    3:18 pm
      SUBROUTINE RADANAL
c
c     core routine on file radanal.f
c
c     called by MAIN [MAIN->RADANAL]
c
c     calls IRRAD, KFCN, PRADSEL, SAVEDATA
C     calls routines (in file dataintp.f): fit1D
C     calls routines (in file excel.f): STORXCEL, WRTXCELS
c 
c     This subroutine takes the spectral radiances generated by
c     RADIANCE and computes the radiances, K functions, etc at
c     the current wavelength.
c
c     Selected data are written to files for later graphical and/or
c     spreadsheet analysis.
c 
      INCLUDE "DIMENS_XL.INC"
c
      COMMON /CEospl/ nspl,zspl(mxz),Eospl(mxz,mxwave),
     1                E2spl(mxz,mxwave),Edspl(mxz,mxwave)

      COMMON /Cirrad/ Eou(0:mxz),Eod(0:mxz),Eu(0:mxz),Ed(0:mxz),
     1                fMUu(0:mxz),fMUd(0:mxz),fMUtot(0:mxz),R(0:mxz),
     2                E2(0:mxz)
      COMMON /Cgrid/ fmu(mxmu),bndmu(mxmu),omega(mxmu),deltmu(mxmu),
     1               z(mxz),zeta(mxz)
      COMMON /Cpkfcn/ npkfcn,izkfcn(mxz) 
      COMMON /CKRAD/ npkrad,istart,istop,istep,jstart,jstop,jstep 
      COMMON /Cmisc/ imisc(30),fmisc(30)

      Common /Csource0/ ibiolum,ichlfl,icdomfl,iraman, ramanEXP
      Common /Cvarz/ indexz(0:mxwave),zopt(mxwave),zFPAR(mxwave)
      COMMON /Ciop/ acoef(mxz,0:mxcomp),bcoef(mxz,0:mxcomp),
     1		      atten(mxz),albedo(mxz), bbcoef(mxz,0:mxcomp)
c
c     declare temp vars
      integer nz, jwave, ioptflag, nspl
c
      logical IamEL
      external IamEL
!     ********************************************************
c
      nz = imisc(4)
      jwave = imisc(11)
      iOptRad = imisc(24)
      ioptflag = imisc(25)
      nspl = nz
c
C     Special call IFF HL
      if(.not.IamEL()) CALL SYNHL  !generate radiances from L-moments

c     Compute irradiances at the depths where the RTE was solved
      CALL IRRAD
c
c     If depth optimization was used and the RTE was not solved to
c     the max user-requested depth, first extrapolate the total 
c     irradiances Eo and E2 (at the present wavelength) from the
c     max computed depth, z(indexz(jwave)), to the max 
c     user-requested depth, z(nz).  Then generate a
c     spline function for Eo(z), for later use in computing the 
c     fluorescence source terms at any depth z (in routines srcchl and
c     srccdom).  Also, compute and save the spline information for the
c     second moment E2, for use in the Raman source function (in routine
c     srcram).
c
      if(IamEL()) then 
        izc = indexz(jwave)  !EL, the last computed depth
      else
        izc = imisc(4)       !HL  (nz)
      endif

c     save irradiances for the RTE-computed depths
      do iz=1,izc
         zspl(iz) = z(iz)
         E2spl(iz,jwave) = E2(iz)
         Eospl(iz,jwave) = Eou(iz) + Eod(iz)
         Edspl(iz,jwave) = Ed(iz) ! only for PAR(Ed) calculations
      end do

c     IFF EL, extrapolate below the computed depths, if necessary
      if(IamEL() .and. ioptflag.ne.0 .and. izc.lt.nz) then
c        use the layer-averaged Ko and K2 from the last two computed
c        depths to extrapolate the irradiances
         c = -1.0/(z(izc) - z(izc-1))
         fKo = c*alog(Eospl(izc,jwave)/Eospl(izc-1,jwave))
         fK2 = c*alog(E2spl(izc,jwave)/E2spl(izc-1,jwave))
         aizc = acoef(izc,0) + acoef(izc-1,0)

         do iz=izc+1,nz
            zspl(iz) = z(iz)
c     use the last computed Ko to extrapolate to all depths:
c            Eospl(iz,jwave) = Eospl(izc,jwave)*exp(-fKo*(z(iz)-z(izc)))
c            E2spl(iz,jwave) = E2spl(izc,jwave)*exp(-fK2*(z(iz)-z(izc)))
c     use the last computed Ko scaled by absorption at the last-computed
c     and current layers to extrapolate from one depth to the next:
             Eospl(iz,jwave) = Eospl(iz-1,jwave)*
     1     exp(-fKo*((acoef(iz,0)+acoef(iz-1,0))/aizc)*(z(iz)-z(iz-1)))
             E2spl(iz,jwave) = E2spl(iz-1,jwave)*
     1     exp(-fK2*((acoef(iz,0)+acoef(iz-1,0))/aizc)*(z(iz)-z(iz-1)))
         enddo
      endif
c
!     convert to natural logs for better interpolation
      Do iz=1,nz
         If(Eospl(iz,jwave).gt.0) then
           Eospl(iz,jwave) = log(Eospl(iz,jwave))
         Else
           Eospl(iz,jwave) = -1.0e+3   !exp of this should be zero         
         Endif
         If(E2spl(iz,jwave).gt.0) then
           E2spl(iz,jwave) = log(E2spl(iz,jwave))
         Else
           E2spl(iz,jwave) =  -1.0e+3   !exp of this should be zero            
         Endif
      Enddo
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c
c     Compute and print IRRADIANCE K functions
      if(npkfcn.gt.0) CALL KFCN

c     Print out selected radiances
      CALL PRADSEL

c     compute and print RADIANCE K functions and path functions
      if(.not.IamEL() .and. npkrad.gt.0) CALL KRADPATH

c     write the full radiance distribution to Lrootname
      if(iOptRad.gt.0) call writerad
c 
c     Save output for graphical or other post-run analysis.
c
c     write full output file at this wavelength
	iwrtIDL = imisc(22)
      if(iwrtIDL.ne.0) CALL SAVEDATA
c
c     accumulate arrays for multi-wavelength spreadsheet postprocessing
c     and for computation of the Secchi depth and CIE coordinates
      CALL STORXCEL
c
c     write selected output for (single-wavelength) spreadsheet
c     postprocessing, if requested
      iwrtss1 = imisc(20)
      if(iwrtss1 .ne. 0) CALL WRTXCELS
c
      return
      end

