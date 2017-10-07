subroutine write_diag(obsfile,nobstot,nproc,idate,statinfo,stattype,oblon,oblat,obtime,&
 ob,zob,stdev,stdevorig,anal_ob,anal_obz,biasob)
 ! f2py -c write_diag.f90 -m write_diag
 integer, parameter :: nchar=8 ! need it to be 64, requires mods in EnKF
 integer, parameter :: nreal=20
 integer, intent(in) :: nobstot,idate,nproc,stattype(nobstot)
 real, intent(in),dimension(nobstot) :: oblat,oblon,obtime,ob,zob,stdev,stdevorig,anal_ob,biasob,anal_obz
 character(len=120), intent(in) :: obsfile
 character, intent(in) :: statinfo(nchar,nobstot)
 real, dimension(:,:), allocatable :: rdiagbuf
 character(len=nchar),allocatable,dimension(:):: cdiagbuf
 integer i,iunito
 allocate(cdiagbuf(nobstot),rdiagbuf(nreal,nobstot))
 iunito = 9
 open(iunito,form="unformatted",file=trim(adjustl(obsfile)),status='replace',convert='big_endian')
 do i=1,nobstot
    do j=1,nchar
       cdiagbuf(i)(j:j)    = statinfo(j,i)  ! station id
    enddo
    rdiagbuf(1,i)  = stattype(i)       ! observation type
    rdiagbuf(2,i)  = stattype(i)       ! observation subtype
    rdiagbuf(3,i)  = oblat(i) ! observation latitude (degrees)
    rdiagbuf(4,i)  = oblon(i) ! observation longitude (degrees)
    rdiagbuf(5,i)  = zob(i)            ! station elevation (meters)
    rdiagbuf(6,i)  = ob(i)             ! observation pressure (hPa)
    rdiagbuf(7,i)  = anal_obz(i)       ! observation height (meters)
    rdiagbuf(8,i)  = obtime(i)         ! obs time (hours relative to analysis time)

    rdiagbuf(9,i)  = 1.                 ! input prepbufr qc or event mark
    rdiagbuf(10,i) = 1.e30              ! setup qc or event mark
    rdiagbuf(11,i) = 1.                 ! read_prepbufr data usage flag
    rdiagbuf(12,i) = 1.                 ! analysis usage flag (1=use, -1=not used)
    rdiagbuf(13,i) = 1.                 ! nonlinear qc relative weight
    rdiagbuf(14,i) = 1./stdevorig(i)   ! prepbufr inverse obs error (hPa**-1)
    rdiagbuf(15,i) = 1./stdevorig(i)   ! read_prepbufr inverse obs error (hPa**-1)
    rdiagbuf(16,i) = 1./stdev(i)       ! final inverse observation error (hPa**-1)
    rdiagbuf(17,i) = ob(i)  ! surface pressure observation (hPa)
    ! bias correction applied to Hx (guess in ob space).
    ! biasob is mean O-F over last 60 or so days.
    ! obs-ges used in analysis (coverted to hPa)
    rdiagbuf(18,i) = ob(i)-(anal_ob(i)+biasob(i))
    ! obs-ges w/o bias correction.
    rdiagbuf(19,i) = ob(i)-anal_ob(i)
    rdiagbuf(20,i) = 1.e+10             ! spread (filled in by EnKF)
 enddo
 write(iunito) idate
 write(iunito)' ps',nchar,nreal,nobstot,nproc,nreal
 write(iunito)cdiagbuf(1:nobstot),rdiagbuf(:,1:nobstot)
 close(iunito)
 deallocate(rdiagbuf,cdiagbuf)
end subroutine write_diag

subroutine strtoarr(strin, chararr, n_str)
  integer, intent(in) :: n_str
  character(len=n_str), intent(in) :: strin
  integer, intent(out) ::  chararr(n_str+1)
  chararr = 32 ! space
  do j=1,n_str
     chararr(j) = ichar(strin(j:j))
  enddo
  chararr(n_str+1) = 124 ! '|'
end subroutine strtoarr
