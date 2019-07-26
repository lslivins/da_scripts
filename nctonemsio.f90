program nctonemsio

! convert netcdf file (converted from nemsio using cdo) back to nemsio.

!ifort -I${NEMSIO_INC} -I${NETCDF}/include -warn all nctonemsio.f90 ${NEMSIO_LIB} ${BACIO_LIB4} ${W3NCO_LIB4} -L${NETCDF}/lib -lnetcdf -lnetcdff -L${HDF5_DIR}/lib -lhdf5 -lhdf5_hl

  use netcdf
  use nemsio_module, only:  nemsio_init,nemsio_open,nemsio_close,nemsio_charkind
  use nemsio_module, only:  nemsio_gfile,nemsio_getfilehead,nemsio_readrec,&
       nemsio_writerec,nemsio_readrecv,nemsio_writerecv,nemsio_getrechead
  implicit none

  character*500 filename_nc,filename_nemsio,filename_o
  integer iret,latb,lonb,nrec,nlevs,npts,k,idsl,ncid,varid
  integer krect,krecq,krecu,krecv,ntrac,krecoz,kreccwmr,krecicmr
  real,allocatable,dimension(:,:) :: work,work2d
  real,allocatable,dimension(:,:,:) :: ugrd3d,vgrd3d,tmp3d,spfh3d,clwmr3d,icmr3d,o3mr3d
  real,allocatable,dimension(:) :: work1d
  !character(len=nemsio_charkind),allocatable,dimension(:) :: recnam
  !character(len=nemsio_charkind) field
  type(nemsio_gfile) :: gfile_nemsio,gfile_o

! read data from this netcdf file
  call getarg(1,filename_nc)

! use this nemsio file as a template
  call getarg(2,filename_nemsio)

! replace data from nemsio from netcdf, write to this file
  call getarg(3,filename_o)

  write(6,*)'NCTONEMSIO:'
  write(6,*)'filename_nc=',trim(filename_nc)
  write(6,*)'filename_nemsio=',trim(filename_nemsio)
  write(6,*)'filename_out=',trim(filename_o)

  call nemsio_open(gfile_nemsio,trim(filename_nemsio),'READ',iret=iret)
  if (iret == 0 ) then
      write(6,*)'Read nemsio ',trim(filename_nemsio),' iret=',iret
      call nemsio_getfilehead(gfile_nemsio, nrec=nrec, dimx=lonb, dimy=latb, dimz=nlevs, idsl=idsl,iret=iret)
      write(6,*)' lonb=',lonb,' latb=',latb,' levs=',nlevs,' nrec=',nrec
  else
      write(6,*)'***ERROR*** ',trim(filename_nemsio),' contains unrecognized format.  ABORT'
  endif

  npts=lonb*latb
  ! assumes ps,zs are first two records, then u,v,t,q,oz,cwmr,icmr
  if (nrec > 2 + 7*nlevs) then
     print *,'cannot handle nrec > ',2 + 7*nlevs
     stop
  endif
  ! q, oz, then microphys tracers are last (after u,v,Ts)
  krecq    = 2 + 3*nlevs + 1
  ntrac = (nrec-(krecq-1))/nlevs
  print *,'ntrac,nrec,idsl',ntrac,nrec,idsl

  allocate(work(npts,nrec))
  allocate(work1d(npts))
  allocate(work2d(lonb,latb))
  allocate(ugrd3d(lonb,latb,nlevs))
  allocate(vgrd3d(lonb,latb,nlevs))
  allocate(tmp3d(lonb,latb,nlevs))
  allocate(spfh3d(lonb,latb,nlevs))
  allocate(clwmr3d(lonb,latb,nlevs))
  allocate(icmr3d(lonb,latb,nlevs))
  allocate(o3mr3d(lonb,latb,nlevs))

  ! read ps,zs from filename_nemsio
  call nemsio_readrecv(gfile_nemsio,'pres','sfc',1,work(:,1),iret=iret)
  if (iret /= 0) then
     print *,'Error reading ps from ',trim(filename_nemsio)
     stop
  endif
  call nemsio_readrecv(gfile_nemsio,'hgt','sfc',1,work(:,2),iret=iret)
  if (iret /= 0) then
     print *,'Error reading zs from ',trim(filename_nemsio)
     stop
  endif
  do k = 1,nlevs
      krecu    = 2 + 0*nlevs + k
      krecv    = 2 + 1*nlevs + k
      krect    = 2 + 2*nlevs + k
      krecq    = 2 + 3*nlevs + k
      krecoz   = 2 + 4*nlevs + k
      kreccwmr = 2 + 5*nlevs + k
      krecicmr = 2 + 6*nlevs + k
      call nemsio_readrecv(gfile_nemsio,'ugrd', 'mid layer',k,work(:,krecu),   iret=iret)
      if (iret /= 0) then
         print *,'Error reading u from ',trim(filename_nemsio),k
         stop
      endif
      call nemsio_readrecv(gfile_nemsio,'vgrd', 'mid layer',k,work(:,krecv),   iret=iret)
      if (iret /= 0) then
         print *,'Error reading v from ',trim(filename_nemsio),k
         stop
      endif
      call nemsio_readrecv(gfile_nemsio,'tmp',  'mid layer',k,work(:,krect),   iret=iret)
      if (iret /= 0) then
         print *,'Error reading t from ',trim(filename_nemsio),k
         stop
      endif
      call nemsio_readrecv(gfile_nemsio,'spfh', 'mid layer',k,work(:,krecq),   iret=iret)
      if (iret /= 0) then
         print *,'Error reading q from ',trim(filename_nemsio),k
         stop
      endif
      call nemsio_readrecv(gfile_nemsio,'o3mr', 'mid layer',k,work(:,krecoz),  iret=iret)
      if (iret /= 0) then
         print *,'Error reading o3 from ',trim(filename_nemsio),k
         stop
      endif
      call nemsio_readrecv(gfile_nemsio,'clwmr','mid layer',k,work(:,kreccwmr),iret=iret)
      if (iret /= 0) then
         print *,'Error reading cwmr from ',trim(filename_nemsio),k
         stop
      endif
      call nemsio_readrecv(gfile_nemsio,'icmr','mid layer',k,work(:,krecicmr),iret=iret)
      if (iret /= 0) then
         print *,'Error reading icmr from ',trim(filename_nemsio),k
         stop
      endif
  enddo

! open netcdf file, replace data in nemsio file
  iret=nf90_open(trim(filename_nc),nf90_nowrite,ncid)
  call netcdf_err(iret)

  gfile_o=gfile_nemsio
  call nemsio_open(gfile_o,trim(filename_o),'WRITE',iret=iret)
  if (iret /= 0) then
     print *,'Error opening ',trim(filename_o)
     stop
  endif
! interpolate fields to new pressures (update rest of work).
  krecu    = 2 + 0*nlevs + 1
  krecv    = 2 + 1*nlevs + 1
  krect    = 2 + 2*nlevs + 1
  krecq    = 2 + 3*nlevs + 1

  ! write out all fields to filename_o
  iret=nf90_inq_varid(ncid, 'pressfc', varid)
  call netcdf_err(iret)
  iret=nf90_get_var(ncid, varid, work2d)
  call netcdf_err(iret)
  call twodtooned(work2d, work1d, lonb, latb)
  work(:,1) = work1d
  call nemsio_writerecv(gfile_o,'pres','sfc',1,work(:,1),iret=iret)
  if (iret /= 0) then
     print *,'Error writing ps to ',trim(filename_o)
     stop
  else
     print *,'wrote ps ',minval(work(:,1)),maxval(work(:,1))
  endif
  call nemsio_writerecv(gfile_o,'hgt','sfc',1,work(:,2),iret=iret)
  if (iret /= 0) then
     print *,'Error writing zs to ',trim(filename_o)
     stop
  else
     print *,'wrote zs ',minval(work(:,2)),maxval(work(:,2))
  endif

  iret=nf90_inq_varid(ncid, 'ugrdmidlayer', varid)
  call netcdf_err(iret)
  iret=nf90_get_var(ncid, varid, ugrd3d)
  call netcdf_err(iret)
  iret=nf90_inq_varid(ncid, 'vgrdmidlayer', varid)
  call netcdf_err(iret)
  iret=nf90_get_var(ncid, varid, vgrd3d)
  call netcdf_err(iret)
  iret=nf90_inq_varid(ncid, 'tmpmidlayer', varid)
  call netcdf_err(iret)
  iret=nf90_get_var(ncid, varid, tmp3d)
  call netcdf_err(iret)
  iret=nf90_inq_varid(ncid, 'spfhmidlayer', varid)
  call netcdf_err(iret)
  iret=nf90_get_var(ncid, varid, spfh3d)
  call netcdf_err(iret)
  iret=nf90_inq_varid(ncid, 'clwmrmidlayer', varid)
  call netcdf_err(iret)
  iret=nf90_get_var(ncid, varid, clwmr3d)
  call netcdf_err(iret)
  iret=nf90_inq_varid(ncid, 'icmrmidlayer', varid)
  call netcdf_err(iret)
  iret=nf90_get_var(ncid, varid, icmr3d)
  call netcdf_err(iret)
  iret=nf90_inq_varid(ncid, 'o3mrmidlayer', varid)
  call netcdf_err(iret)
  iret=nf90_get_var(ncid, varid, o3mr3d)
  call netcdf_err(iret)

  do k = 1,nlevs
      krecu    = 2 + 0*nlevs + k
      krecv    = 2 + 1*nlevs + k
      krect    = 2 + 2*nlevs + k
      krecq    = 2 + 3*nlevs + k
      krecoz   = 2 + 4*nlevs + k
      kreccwmr = 2 + 5*nlevs + k
      krecicmr = 2 + 6*nlevs + k
      call twodtooned(ugrd3d(:,:,k),work1d,lonb,latb)
      work(:,krecu) = work1d
      call nemsio_writerecv(gfile_o,'ugrd', 'mid layer',k,work(:,krecu),   iret=iret)
      if (iret /= 0) then
         print *,'Error writing u to ',trim(filename_o),k
         stop
      else
         print *,'wrote u level ',k,minval(work(:,krecu)),maxval(work(:,krecu))
      endif
      call twodtooned(vgrd3d(:,:,k),work1d,lonb,latb)
      work(:,krecv) = work1d
      call nemsio_writerecv(gfile_o,'vgrd', 'mid layer',k,work(:,krecv),   iret=iret)
      if (iret /= 0) then
         print *,'Error writing v to ',trim(filename_o),k
         stop
      else
         print *,'wrote v level ',k,minval(work(:,krecv)),maxval(work(:,krecv))
      endif
      call twodtooned(tmp3d(:,:,k),work1d,lonb,latb)
      work(:,krect) = work1d
      call nemsio_writerecv(gfile_o,'tmp',  'mid layer',k,work(:,krect),   iret=iret)
      if (iret /= 0) then
         print *,'Error writing t to ',trim(filename_o),k
         stop
      else
         print *,'wrote t level ',k,minval(work(:,krect)),maxval(work(:,krect))
      endif
      call twodtooned(spfh3d(:,:,k),work1d,lonb,latb)
      work(:,krecq) = work1d
      call nemsio_writerecv(gfile_o,'spfh', 'mid layer',k,work(:,krecq),   iret=iret)
      if (iret /= 0) then
         print *,'Error writing q to ',trim(filename_o),k
         stop
      else
         print *,'wrote q level ',k,minval(work(:,krecq)),maxval(work(:,krecq))
      endif
      call twodtooned(o3mr3d(:,:,k),work1d,lonb,latb)
      work(:,krecoz) = work1d
      call nemsio_writerecv(gfile_o,'o3mr', 'mid layer',k,work(:,krecoz),  iret=iret)
      if (iret /= 0) then
         print *,'Error writing o3 to ',trim(filename_o),k
         stop
      else
         print *,'wrote o3 level ',k,minval(work(:,krecoz)),maxval(work(:,krecoz))
      endif
      call twodtooned(clwmr3d(:,:,k),work1d,lonb,latb)
      work(:,kreccwmr) = work1d
      call nemsio_writerecv(gfile_o,'clwmr','mid layer',k,work(:,kreccwmr),iret=iret)
      if (iret /= 0) then
         print *,'Error writing cwmr to ',trim(filename_o),k
         stop
      else
         print *,'wrote cwmr level ',k,minval(work(:,kreccwmr)),maxval(work(:,kreccwmr))
      endif
      call twodtooned(icmr3d(:,:,k),work1d,lonb,latb)
      work(:,krecicmr) = work1d
      call nemsio_writerecv(gfile_o,'icmr','mid layer',k,work(:,krecicmr),iret=iret)
      if (iret /= 0) then
         print *,'Error writing icmr to ',trim(filename_o),k
         stop
      else
         print *,'wrote icmr level ',k,minval(work(:,krecicmr)),maxval(work(:,krecicmr))
      endif
  enddo
  deallocate(work,work1d,work2d,ugrd3d,vgrd3d,tmp3d,spfh3d,clwmr3d,icmr3d,o3mr3d)
  call nemsio_close(gfile_o,iret=iret)
  if (iret /= 0) then
     print *,'Error closing ',trim(filename_o)
     stop
  endif
  call nemsio_close(gfile_nemsio,iret=iret)
  if (iret /= 0) then
     print *,'Error closing ',trim(filename_nemsio)
     stop
  endif
! close netcdf file
  iret = nf90_close(ncid)

END program nctonemsio

subroutine twodtooned(datain,dataout,nlons,nlats)
  implicit none
  integer, intent(in) :: nlons,nlats
  real, intent(in) :: datain(nlons,nlats)
  real, intent(out) :: dataout(nlons*nlats)
  integer i,j,nn
  nn = 0
  do j=1,nlats
  do i=1,nlons
     nn = nn + 1
     dataout(nn) = datain(i,j)
  enddo
  enddo
end subroutine twodtooned

subroutine netcdf_err(ncstat)
  use netcdf, only : nf90_strerror
  implicit none
  integer, intent(in) :: ncstat
  if (ncstat /= 0) then
     write(0,*)'netcdf-error: ', trim(nf90_strerror(ncstat))
     stop
  endif
end subroutine netcdf_err
