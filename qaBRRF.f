C     Last change:  LKS  21 Jan 2008    5:42 pm
      subroutine qaBRRF(BRRFdisc) 
C 
C     core routine on file qaBRRF.f
C 
c     This routine computes quad-averaged Bidirectional Radiance 
c     Reflectance Functions (BRRFs) for use in modeling finite-depth
c     bottom boundaries.  The formalism of Eq. (8.13) (with s = 1) is used.
c
c*****NOTE:  The bidirectional reflectance distribution function (BRDF)
c     is the function commonly used to specify surface reflectance properties.
c     However, Hydrolight requires the BRRF, which is related to the BRDF by
c     BRRF(mu',phi',mu,phi) = BRDF(mu',phi',mu,phi) * mu'.
c     For user convenience, the USER-SUPPLIED supbroutine, BRDFbotm,
c     should return the BRDF, which is then converted to the BRRF in
c     the core routine qaBRRF.
c
c*****NOTE:  Hydrolight requires that the bottom boundary BRDF be 
c     azimuthally isotropic, i.e. that BRDF(mu',phi',mu,phi) depends
c     on the difference (phi' - phi), and not on phi' and phi individually.  
c     This means that only the s = 1 values of the discretized BRRF,
c     BRRFdisc(r,s,u,v), need to be explicitly computed, because phi'
c     can be set to 0 (just as for phase functions or the sea surface).
c
C+++++WARNING:  Make sure that the desired version of the user-supplied 
c     function "BRDFbotm" has been loaded into the executable file (as 
c     generated by the makefile) 
c 
c     nsubmu and nsubphi are the base numbers of quad subdivisions in the
c     mu and phi directions, as used for numerical integration of the 
c     continuous BRDFbotm as seen in Eq. (8.13).  
c 
      INCLUDE "DIMENS_XL.INC"
C 
c     BRRFdisc(ir,iu,iv) = the discretized BRRF(r,s,u,v) (for s = 1).  
c     No special indexing is used to save storage, even though the azimuthal 
c     symmetry means that not all BRRFdisc values are independent. 
      dimension BRRFdisc(mxmu,mxmu,mxphi)
c
      COMMON /Cgrid/ fmu(mxmu),bndmu(mxmu),omega(mxmu),deltmu(mxmu),
     1               zgeo(mxz),zeta(mxz)
      COMMON /CgridPhi/phi(mxphi),bndphi(mxphi)
      COMMON /CMISC/ imisc(30),fmisc(30) 
c
c     BRDFbotm = the continuous BRDF(mu',phi',mu,phi) (1/sr)
c     that describes the reflectance of the bottom boundary
      external BRDFbotm
c
      nmu = imisc(1)
      nphi = imisc(2) 
      twopi = 2.0*fmisc(1)
      DELPHI = twopi/FLOAT(nphi)
c
C     Initialize the BRRF
C
c     initialize the BRRF routine: 
      dummy = BRDFbotm(1.0,0.0,1.0,0.0)
      dummy = dummy  ! to avoid compiler warnings about unused variable
c
c     Compute the quad-averaged BRRF 
C
c*****Note:  nsubmu = 1 and nsubphi = 1 are OK for Lambertian bottoms,
c     which have a constant BRDF.  These values should be increased (e.g.,
c     to nsubmu = 2 and nsubphi = 3) for non-Lambertine BRDFs.
      nsubmu = 1
      nsubphi = 1
c      write(10,1014) nsubmu,nsubphi

      do k=1,mxphi
         DO J=1,mxmu
            DO I=1,mxmu
               BRRFdisc(I,J,K) = 0.
            end do
         end do
      end do
C 
C     Loop over the r, u, and v quad indices of Eq. (8.13)
C 
      DO IU=1,nmu
C 
      DO IR=1,nmu
C 
      NCOMPV = nphi
      IF(IU.EQ.nmu) NCOMPV = 1 

      DO IV=1,ncompv
c
C     Boundaries of the mu (= iu) quad 
      umumin = 0. 
      if(iu.gt.1) umumin = bndmu(iu-1)
      dmu = deltmu(iu)/float(nsubmu) 
      u0 = umumin + 0.5*dmu 
c     size of the phi-j subquads
      if(iu.eq.nmu) then
         dphi = twopi/float(nsubphi) 
      else
         dphi = delphi/float(nsubphi)
      endif 
c 
c     Boundaries of the mu prime (= ir) quad
      rmumin = 0. 
      if(ir.gt.1) rmumin = bndmu(ir-1)
      dmup = deltmu(ir)/float(nsubmu)
      u0p = rmumin + 0.5*dmup 
c     size of the phi prime-l subquads
      if(ir.eq.nmu) then
         dphip = twopi/float(nsubphi)
      else
         dphip = delphi/float(nsubphi) 
      endif 
c 
      fact = dmu*dphi*dmup*dphip/omega(iu)
c 
c     Boundaries of the phi (= iv) quad 
      phimin = bndphi(nphi) 
      if(iv.gt.1) phimin = bndphi(iv-1) 
      phi0 = phimin + 0.5*dphi
c 
c     Integrate over phi prime only for the phi prime = 0 quads (is = 1)
      phi0p = bndphi(nphi) + 0.5*dphip
c 
c     Compute the quadruple sum (8.13) over the selected quads 
c 
      sum = 0. 
      do ju=1,nsubmu
c 
c     define a mu value 
      umu = u0 + float(ju-1)*dmu
c 
      do jr=1,nsubmu
c 
c     define a mu prime value 
      rmup = u0p + float(jr-1)*dmup
c 
      do jv=1,nsubphi
c 
c     define a phi value
      vphi = phi0 + float(jv-1)*dphi
c 
      do js=1,nsubphi
c 
c     define a phi prime value
      sphip = phi0p + float(js-1)*dphip 
c 
c     Compute contributions to integrals
c     This is where the user-supplied BRDF is converted to the BRRF

      sum = sum + BRDFbotm(rmup,sphip,umu,vphi) * rmup

      end do   ! js loop
      end do   ! jv
      end do   ! jr
      end do   ! ju
c 
      BRRFdisc(ir,iu,iv) = BRRFdisc(ir,iu,iv) + sum*fact 
      
      end do   ! iv loop
      end do   ! ir 
      end do   ! iu
c 
      idbug = 0
      IF(idbug.ne.0) THEN 
         CALL P3ARAY(BRRFdisc,nmu,nmu,2,mxmu,mxmu,2,
     1    ' Quad-averaged BRRF(r,1;u,v)') 
      ENDIF 
c
      return
C 
 1014 format(//5x,'The bottom BRRF is quad-averaged using nsubmu =',
     1i3,' and nsubphi =',i3)
       END