#!/bin/csh

setenv HOSTFILE ${datapath2}/machinesx

cd ${datapath2}

set iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`

echo "compute ensemble mean analyses..."
setenv HOSTFILE $datapath2/machinesx # set in main.csh

foreach nhr_anal ( $iaufhrs2 )
set charfhr="fhr"`printf %02i $nhr_anal`
set charfhr2=`printf %02i $nhr_anal`

if ($iau_delthrs != -1) then
   if ($cleanup_ensmean == 'true' || ($cleanup_ensmean == 'false' && ! -s ${datapath}/${analdate}/sanl_${analdate}_${charfhr}_ensmean)) then
   /bin/rm -f sanl_${analdate}_${charfhr}_ensmean
   setenv PGM "${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sanl_${analdate}_${charfhr}_ensmean sanl_${analdate}_${charfhr} ${nanals}"
   sh ${enkfscripts}/runmpi
   if ($nhr_anal == $ANALINC) then
      setenv PGM "${execdir}/getsigensstatp.x ${datapath2}/ sanl_${analdate}_${charfhr} ${nanals}"
      sh ${enkfscripts}/runmpi
   endif
   endif
else
   if ($cleanup_ensmean == 'true' || ($cleanup_ensmean == 'false' && ! -s ${datapath}/${analdate}/sanl_${analdate}_ensmean)) then
   /bin/rm -f sanl_${analdate}_ensmean
   setenv PGM "${execdir}/getsigensmeanp_smooth.x ${datapath2}/ sanl_${analdate}_ensmean sanl_${analdate} ${nanals}"
   sh ${enkfscripts}/runmpi
   setenv PGM "${execdir}/getsigensstatp.x ${datapath2}/ sanl_${analdate} ${nanals}"
   sh ${enkfscripts}/runmpi
   endif
endif

end
ls -l ${datapath2}/sanl_${analdate}*ensmean

# calculate ens mean increment file.
echo "compute ensemble mean increment file `date`"
setenv nprocs 1
setenv mpitaskspernode 1
setenv PGM ${execdir}/calc_increment.x
mkdir -p ${datapath2}/ensmean/INPUT
pushd ${datapath2}/ensmean/INPUT
if ($iau_delthrs != -1) then
set iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`
foreach nfhr ( $iaufhrs2 )
set charfhr="fhr"`printf %02i $nfhr`
cat > calc-increment.input <<EOF
&share
debug=F
analysis_filename="${datapath2}/sanl_${analdate}_${charfhr}_${charnanal}"
firstguess_filename="${datapath2}/sfg_${analdate}_${charfhr}_${charnanal}"
increment_filename="fv3_increment${nfhr}.nc"
/
EOF
sh ${enkfscripts}/runmpi
end
else
cat > calc-increment.input <<EOF
&share
debug=F
analysis_filename="${datapath2}/sanl_${analdate}_${charnanal}"
firstguess_filename="${datapath2}/sfg_${analdate}_fhr06_${charnanal}"
increment_filename="fv3_increment.nc"
/
EOF
sh ${enkfscripts}/runmpi
endif
popd
ls -l  ${datapath2}/ensmean/INPUT/fv*increment*nc
echo "done computing ensemble mean increment files `date`"

exit 0
