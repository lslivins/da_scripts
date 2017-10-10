#!/bin/csh

if ($machine == 'wcoss') then
   module load nco-gnu-sandybridge
else
   module load nco/4.6.0
endif
setenv HOSTFILE ${datapath2}/machinesx
set NODES=`wc -l $HOSTFILE | cut -f1 -d " "`

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
            set host=`head -$ncount $machinesx | tail -1`
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
            set host=`head -$ncount $machinesx | tail -1`
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
endif
endif
# lossy compression: ncks -4 --ppc default=5 -O
# lossless: ncks -4 -L 5 -O

exit 0
