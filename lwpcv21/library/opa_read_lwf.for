      SUBROUTINE OPA_READ_LWF
     &          (lu_lwf,file_id,case_id,prfl_id,
     &           xmtr_id,freq,tlat,tlon,power,ralt,stndev,
     &           path_id,oplat1,oplon1,oplat2,oplon2,
     &           mxpath,nrpath,bearing,rhomax,rxlat,rxlon,
     &           mxprm,nrprm,param,
     &           mxpts,nrpts,dst_lwf,amp_lwf,phs_lwf,
     &           nrcmp,nrlwf,nrec,
     &           amp_rho,sig_rho)

c Reads file generated by a mode summing program which must be
c signal vs. distance along several paths.

c***********************************************************************

c     lu_lwf        logical unit number for input data

c     case_id       case identification
c     prfl_id       ionospheric profile identification

c     xmtr_id       transmitter identification
c     freq          frequency; kHz
c     tlat          latitude  of the transmitter
c     tlon          longitude of the transmitter
c     power         power; kW
c     ralt          receiver altitude; km
c     stndev        standard deviation of the signal for day, night,
c                   dawn, dusk; dB

c     path_id
c     oplat1
c     oplon1
c     oplat2
c     oplon2

c     mxpath
c     nrpath
c     bearing
c     rhomax
c     rxlat
c     rxlon

c     mxprm         maximum number of parameters
c     nrprm                 number of parameters
c     param                           parameters from mode summing

c     mxpts
c     nrpts
c     dst_lwf
c     amp_lwf
c     phs_lwf

c     amp_rho
c     sig_rho

c     nrcmp         number of field components
c     nrlwf         number of parametric records

c     nrec          the number of the record to select

c***********************************************************************

c  Change history:
c     06 Apr 94     Smooth the mode sum over 5 points;
c                   added 4 standard deviations (1: day; 2: night;
c                   3: dawn transition, 4: dusk transition).

c     13 Jan 95     Corrected EOF error when more than one component is
c                   in the LWF file.

c*******************!***************************************************

      parameter    (mxprmx=21,mxps=11,mxsgmnt=201)

      character*  8 archive,prgmidx
      character* 20 xmtr_id,path_id
      character* 40 prfl_id,prflidx
      character* 80 case_id
      character*120 file_id(3)
      character*200 error_msg
      logical       begin_file,end_file,
     &              diurnal
      integer       print_lwf/0/,
     &              month,day,year,UT,
     &              TxDrnl,RxDrnl
      real*4        freq,tlat,tlon,bearng,rhomx,rlat,rlon,rrho,
     &              dst_lwf(mxpts),amp_lwf(mxpts,3),phs_lwf(mxpts,3),
     &              amp_rho(mxpts,2,mxpath),sig_rho(mxpts,2,mxpath),
     &              paramx(mxprmx),param(mxprm),sgmnt(mxps,mxsgmnt),
     &              stndev(4),

     &              am(0:4,3),
     &              rlng,rclt,crclt,srclt,
     &              lng1,clt1,cclt1,sclt1

      data          dtr/0.01745329252/,rtk/6366.197/


      call READ_HDR
     &    (lu_lwf,print_lwf,
     &     archive,file_id,prgmidx,
     &     case_id,prfl_id,
     &     xmtr_id,freq,tlat,tlon,
     &     path_id,oplat1,oplon1,oplat2,oplon2,
     &     mxpath,nrpath,bearing,rhomax,rxlat,rxlon,
     &     begin_file,end_file,'Binary')

c     Extract profile identification for specified date and time
      prflidx=prfl_id
      call STR_UPPER (prflidx,0,0)
      n1=INDEX (prflidx,'DATE: ')
      if (n1 .eq. 0) then

c        Fixed diurnal condition along the paths
         diurnal=.false.

         n1=INDEX (prflidx,'LWPM')
         if (n1 .eq. 0) then

c           Unknown ionospheric model; use daytime values
            TxDrnl=1
         else

c           LWPM model
            n1=INDEX (prflidx,'DAY')
            if (n1 .eq. 0) then

c              Must be night
               TxDrnl=2
            else

c              Is day
               TxDrnl=1
            end if
         end if
      else

c        Variable diurnal conditions along the paths
         diurnal=.true.

c        Get date and time
         read (prflidx(n1+6:),
     &       '(2(i2,1x),i2,1x,i4)')
     &         month,day,year,UT

c        Get sub-solar point
         UT_hours=(UT-(UT/100)*40)/60.
         call ALMNAC
     &       (year,month,day,UT_hours,ssclt,sslng)

         cssclt=COS(ssclt)
         sssclt=SIN(ssclt)

c        Transmitter parameters
         tlng=tlon*dtr
         tclt=(90.-tlat)*dtr
         ctclt=COS(tclt)
         stclt=SIN(tclt)

c        Calculate solar zenith angle at transmitter
         call GCDBR2
     &       (tlng-sslng,tclt,ctclt,stclt,ssclt,cssclt,sssclt,
     &        zn,br,0)

         chi=zn/dtr

c        Determine the diurnal condition at the transmitter
         if (chi .le. 90.) then
            TxDrnl=1
         else
     &   if (chi .ge. 100.) then
            TxDrnl=2
         else
            TxDrnl=0
         end if
      end if

      npath=1
      do while (.not.end_file)
         do nr=1,nrec
            nc=0
            nrc=1
            do while (nc .lt. nrc)
               nc=nc+1
               call READ_LWF
     &             (lu_lwf,print_lwf,
     &              bearng,rhomx,rlat,rlon,rrho,
     &              mxps,nrps,mxsgmnt,nrsgmnt,sgmnt,
     &              mxprm,nrprm,param,nrcmp,nrlwf,
     &              mxpts,nrpts,dst_lwf,
     &              amp_lwf(1,nc),phs_lwf(1,nc),
     &              begin_file,end_file)
               nrc=nrcmp
               if (end_file) nc=nrc
            end do

            if (nrec .gt. nrlwf .and. nrlwf .gt. 0) then
               write(error_msg,
     &             '(''[OPA_READ_LWF]: '',
     &               '' Requested record is out of range'')')
               call LWPC_error('ERROR', error_msg)
            endif
         end do

         if (.not.end_file) then

            if (power .eq. 0.) then
               pwr=param(1)
               adjpwr=1.
               adj_db=0.
            else
               pwr=power
               adjpwr=power/param(1)
               adj_db=10.*LOG10(adjpwr)
               param(1)=power
            end if
            pwrdb=10.*LOG10(pwr)

            xtr=bearng*dtr
            sinxtr=SIN(xtr)

            ralt=param(6)

            if (rlat .ne. 99.) nrpts=nrpts-1

c           Store smoothed signal amplitude for current radial

c           First, set up the first 4 averages
            do i=2,5
               n=MOD(i,5)
               am(n,1)=amp_lwf(i,1)
               if (nrcmp .gt. 1) then
                  am(n,2)=amp_lwf(i,2)
                  if (nrcmp .gt. 2)
     &               am(n,3)=amp_lwf(i,3)
               end if
            end do

c           Average 2nd and 3rd points
            amp_lwf(2,1)=(am(2,1)+am(3,1))/2.
            if (nrcmp .gt. 1) then
               amp_lwf(2,2)=(am(2,2)+am(3,2))/2.
               if (nrcmp .gt. 2)
     &            amp_lwf(2,3)=(am(2,3)+am(3,3))/2.
            end if

c           Average 2nd, 3rd and 4th points
            amp_lwf(3,1)=(am(2,1)+am(3,1)+am(4,1))/3.
            if (nrcmp .gt. 1) then
               amp_lwf(3,2)=(am(2,2)+am(3,2)+am(4,2))/3.
               if (nrcmp .gt. 2)
     &            amp_lwf(3,3)=(am(2,3)+am(3,3)+am(4,3))/3.
            end if

            do i=6,nrpts-2

               n=MOD(i,5)
               am(n,1)=amp_lwf(i,1)
               if (nrcmp .gt. 1) then
                  am(n,2)=amp_lwf(i,2)
                  if (nrcmp .gt. 2) then
                     am(n,3)=amp_lwf(i,3)
                  end if
               end if

c              Store smoothed values
               amp_lwf(i-2,1)=(am(0,1)+am(1,1)+am(2,1)
     &                 +am(3,1)+am(4,1))/5.
               if (nrcmp .gt. 1) then
                  amp_lwf(i-2,2)=(am(0,2)+am(1,2)+am(2,2)
     &                    +am(3,2)+am(4,2))/5.
                  if (nrcmp .gt. 2)
     &               amp_lwf(i-2,3)=(am(0,3)+am(1,3)+am(2,3)
     &                       +am(3,3)+am(4,3))/5.
               end if
            end do

c           Finish averaging to the end of the path
            n0=n
            n1=n-1
            if (n1 .lt. 0) n1=n1+5
            n2=n-2
            if (n2 .lt. 0) n2=n2+5
            n3=n-3
            if (n3 .lt. 0) n3=n3+5
            n4=n-4
            if (n4 .lt. 0) n4=n4+5

c           Store smoothed value for next to last point
            amp_lwf(nrpts-1,1)=(am(n0,1)+am(n1,1)+am(n2,1)
     &                         +am(n3,1))/4.
            if (nrcmp .gt. 1) then
               amp_lwf(nrpts-1,2)=(am(n0,2)+am(n1,2)+am(n2,2)
     &                            +am(n3,2))/4.
               if (nrcmp .gt. 2)
     &            amp_lwf(nrpts-1,3)=(am(n0,3)+am(n1,3)+am(n2,3)
     &                               +am(n3,3))/4.
            end if

c           Store smoothed value for last point
            amp_lwf(nrpts,1)=(am(n0,1)+am(n1,1)+am(n2,1))/3.
            if (nrcmp .gt. 1) then
               amp_lwf(nrpts,2)=(am(n0,2)+am(n1,2)+am(n2,2))/3.
               if (nrcmp .gt. 2)
     &            amp_lwf(nrpts,3)=(am(n0,3)+am(n1,3)+am(n2,3))/3.
            end if

c           Store signal amplitude and sigma for current radial
            do i=1,nrpts

               amp_rho(i,1,npath)=amp_lwf(i,1)+adj_db
               if (nrcmp .gt. 1)
     &            amp_rho(i,2,npath)=amp_lwf(i,2)+adj_db

c              Determine standard deviation of signal
               if (diurnal) then

c                 Get receiver coordinates
                  gcd=dst_lwf(i)/rtk
                  call RECVR2
     &                (tlng,tclt,ctclt,stclt,xtr,gcd,
     &                 rlng,rclt,crclt,srclt)

c                 Calculate signed solar zenith angle;
c                 -180<CHI<  0 is midnight to noon;
c                    0<CHI<180 is noon to midnight.

                  call GCDBR2
     &                (rlng-sslng,rclt,crclt,srclt,ssclt,cssclt,sssclt,
     &                 zn,br,0)

                  call RECVR2
     &                (tlng,tclt,ctclt,stclt,xtr,gcd+0.01,
     &                 lng1,clt1,cclt1,sclt1)

                  call GCDBR2
     &                (lng1-sslng,clt1,cclt1,sclt1,ssclt,cssclt,sssclt,
     &                 zn1,br,0)

                  if (zn1-zn .lt. 0.) zn=-zn
                  if (sinxtr .lt. 0.) zn=-zn

                  chi=zn/dtr

c                 Determine the diurnal condition at the receiver
                  if (TxDrnl .eq. 1 .and. ABS(chi) .le. 90.) then

c                    All day portion of the path
                     RxDrnl=1
                  else
     &            if (TxDrnl .eq. 2 .and. ABS(chi) .ge. 100.) then

c                    All night portion of the path
                     RxDrnl=2
                  else
     &            if (chi .lt. 0.) then

c                    Night to day transition on the path (dawn)
                     RxDrnl=3
                  else

c                    Day to night transition on the path (dusk)
                     RxDrnl=4

                  end if
                  sigm=stndev(RxDrnl)
               else

c                 Use fixed standard deviation
                  sigm=stndev(TxDrnl)

               end if

               sig_rho(i,1,npath)=sigm
               sig_rho(i,2,npath)=sigm*1.5
            end do

            if (nrec .lt. nrlwf) then

c              Read to the end of this path
               do nr=nrec+1,nrlwf
                  do ncmp=1,nrcmp
                     call READ_LWF
     &                   (lu_lwf,print_lwf,
     &                    bearng,rhomx,rlat,rlon,rrho,
     &                    mxps,nrps,mxsgmnt,nrsgmnt,sgmnt,
     &                    mxprmx,nrprmx,paramx,nrcmpx,nrlwfx,
     &                    mxpts,nrpts,dst_lwf,
     &                    amp_lwf(1,ncmp),phs_lwf(1,ncmp),
     &                    begin_file,end_file)
                  end do
               end do
            end if
         end if

         npath=npath+1
      end do

      REWIND (lu_lwf)

      RETURN
      END      ! OPA_READ_LWF