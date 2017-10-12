#!/bin/csh

if ($machine == 'wcoss') then
   module load nco-gnu-sandybridge
else
   module load nco/4.6.0
endif
set NODES=`wc -l ${datapath2}/machinesx | cut -f1 -d " "`

cd ${datapath2}

echo "compute ensemble mean nemsio files `date`"
#set fh=${FHMIN}
set fh=0
while ($fh <= $FHMAX)

  set charfhr="fhr`printf %02i $fh`"

  if ($cleanup_ensmean == 'true' || ($cleanup_ensmean == 'false' && ! -s ${datapath}/${analdate}/bfg_${analdate}_${charfhr}_ensmean)) then
      echo "running  ${execdir}/getsfcensmeanp.x ${datapath2}/ bfg_${analdate}_${charfhr}_ensmean bfg_${analdate}_${charfhr} ${nanals}"
      /bin/rm -f ${datapath2}/bfg_${analdate}_${charfhr}_ensmean
      setenv PGM "${execdir}/getsfcensmeanp.x ${datapath2}/ bfg_${analdate}_${charfhr}_ensmean bfg_${analdate}_${charfhr} ${nanals}"
      sh ${enkfscripts}/runmpi
  endif
  if ($cleanup_ensmean == 'true' || ($cleanup_ensmean == 'false' && ! -s ${datapath}/${analdate}/sfg_${analdate}_${charfhr}_ensmean)) then
      /bin/rm -f ${datapath2}/sfg_${analdate}_${charfhr}_ensmean
      echo "running ${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg_${analdate}_${charfhr}_ensmean sfg_${analdate}_${charfhr} ${nanals} ${JCAP}"
      setenv PGM "${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sfg_${analdate}_${charfhr}_ensmean sfg_${analdate}_${charfhr} ${nanals} ${JCAP}"
      sh ${enkfscripts}/runmpi
      if ($fh == $ANALINC) then
      echo "running ${execdir}/getsigensstatp.x ${datapath2}/ sfg_${analdate}_${charfhr} ${nanals}"
      setenv PGM "${execdir}/getsigensstatp.x ${datapath2}/ sfg_${analdate}_${charfhr} ${nanals}"
      sh ${enkfscripts}/runmpi
      endif
  endif

  @ fh = $fh + $FHOUT

end
echo "done computing ensemble mean nemsio files `date`"

# now compute ensemble mean restart files.
if ( $cleanup_ensmean == 'true' || ( $cleanup_ensmean == 'false' && ! -s ${datapath2}/ensmean/INPUT/fv_core.res.tile1.nc ) ) then
if ( $fg_only == 'false') then
   echo "compute ensemble mean restart files `date`"
   setenv nprocs 1
   setenv mpitaskspernode 1
   setenv OMP_NUM_THREADS $corespernode
   set pathout=${datapath2}/ensmean/INPUT
   mkdir -p $pathout
   set ncount=1
   foreach tile (tile1 tile2 tile3 tile4 tile5 tile6)
      foreach filename (fv_core.res.${tile}.nc fv_tracer.res.${tile}.nc fv_srf_wnd.res.${tile}.nc sfc_data.${tile}.nc)
         setenv PGM "nces -O `ls -1 ${datapath2}/mem*/INPUT/${filename}` ${pathout}/${filename}"
         if ($machine != 'wcoss' && $machine != 'gaea') then
            set host=`head -$ncount ${datapath2}/machinesx | tail -1`
            setenv HOSTFILE ${datapath2}/hostfile_nces_${ncount}
            echo $host >! $HOSTFILE
         endif
         echo "computing ens mean for $filename"
         sh ${enkfscripts}/runmpi &
         #nces -O `ls -1 ${datapath2}/mem*/INPUT/${filename}` ${pathout}/${filename} &
         if ($ncount == $NODES) then
            echo "waiting for backgrounded jobs to finish..."
            wait
            set ncount=1
         else
            @ ncount = $ncount + 1
         endif
      end
   end
   wait
   echo "done computing ensemble mean restart files `date`"
   /bin/rm -f ${datapath2}/hostfile_nces*
   /bin/cp -f ${datapath2}/mem001/INPUT/fv_core.res.nc ${pathout}
   echo "compute ensemble mean history files `date`"
   set pathout=${datapath2}/ensmean
   set ncount=1
   foreach tile (tile1 tile2 tile3 tile4 tile5 tile6)
      #foreach filename (fv3_history.${tile}.nc fv3_history2d.${tile}.nc)
      foreach filename (fv3_history.${tile}.nc)
         setenv PGM "nces -O `ls -1 ${datapath2}/mem*/${filename}` ${pathout}/${filename}"
         if ($machine != 'wcoss' && $machine != 'gaea') then
            set host=`head -$ncount ${datapath2}/machinesx | tail -1`
            setenv HOSTFILE ${datapath2}/hostfile_nces_${ncount}
            echo $host >! $HOSTFILE
         endif
         echo "computing ens mean for $filename"
         sh ${enkfscripts}/runmpi &
         #nces -O `ls -1 ${datapath2}/mem*/${filename}` ${pathout}/${filename} &
         if ($ncount == $NODES) then
            echo "waiting for backgrounded jobs to finish..."
            wait
            set ncount=1
         else
            @ ncount = $ncount + 1
         endif
      end
   end
   wait
   /bin/rm -f ${datapath2}/hostfile_nces*
   echo "done computing ensemble mean history files `date`"

# lossy compression: ncks -4 --ppc default=5 -O
# lossless: ncks -4 -L 5 -O

# compute ens spread
# first aggregate ens members into a single file
# ncecat -O -v z500 /scratch3/BMC/gsienkf/Jeffrey.S.Whitaker/20CR/C96_iau_psonly/1999090118/mem*/*history*tile1*nc test.nc 
# compute ens mean in testm.nc
# ncwa -O -v z500 -a record test.nc testm.nc
# now over-write individual members with deviations from ens mean
# ncbo -O -v z500 testm.nc test.nc test.nc
# finally, compute standard deviation
# ncra -O -y rmssdn test.nc test.nc
   setenv nprocs 1
   setenv mpitaskspernode 1
   setenv OMP_NUM_THREADS $corespernode
   set pathout=${datapath2}/ensmean
   set ncount=1
   set vars="z50,u50,v50,t50,z500,u500,v500,t500,z250,u250,v250,t250,z850,u850,v850,t850"
   echo "compute ensemble mean and spread files `date`"
   foreach tile (tile1 tile2 tile3 tile4 tile5 tile6)
     set filename=fv3_history.${tile}.nc
     set files=`ls -1 ${datapath2}/mem*/${filename}`
     cat > ensmeansprd_${tile}.sh << EOF
#!/bin/sh
ncecat -O -v ${vars} ${files} ${pathout}/plevenssprd.${tile}.nc
ncwa -O -v ${vars} -a record ${pathout}/plevenssprd.${tile}.nc ${pathout}/plevensmean.${tile}.nc
ncbo -O -v ${vars} ${pathout}/plevensmean.${tile}.nc ${pathout}/plevenssprd.${tile}.nc ${pathout}/plevenssprd.${tile}.nc
ncra -O -y rmssdn ${pathout}/plevenssprd.${tile}.nc ${pathout}/plevenssprd.${tile}.nc
EOF
     chmod 755 ensmeansprd_${tile}.sh
     cat ensmeansprd_${tile}.sh
     setenv PGM $PWD/ensmeansprd_${tile}.sh
     if ($machine != 'wcoss' && $machine != 'gaea') then
        set host=`head -$ncount ${datapath2}/machinesx | tail -1`
        setenv HOSTFILE ${datapath2}/hostfile_nces_${ncount}
        echo $host >! $HOSTFILE
     endif
     echo "computing ens mean and spread for $filename"
     sh ${enkfscripts}/runmpi &
     if ($ncount == $NODES) then
        echo "waiting for backgrounded jobs to finish..."
        wait
        set ncount=1
     else
        @ ncount = $ncount + 1
     endif
   end
   wait
   /bin/rm -f ${datapath2}/hostfile_nces*
   /bin/rm -f ensmeansprd_*.sh
   echo "done computing ensemble mean and spread files `date`"
endif
endif

exit 0
