#!/bin/sh

# setup node parameters used in blendinc.csh, recenter_ens_anal.csh and compute_ensmean_fcst.csh
export mpitaskspernode=`python -c "import math; print int(math.ceil(float(${nanals})/float(${NODES})))"`
if [ $mpitaskspernode -lt 1 ]; then
 export mpitaskspernode=1
fi
export OMP_NUM_THREADS=`expr $corespernode \/ $mpitaskspernode`
echo "mpitaskspernode = $mpitaskspernode threads = $OMP_NUM_THREADS"
export nprocs=$nanals

cd ${datapath2}

iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`

echo "compute ensemble mean analyses..."

for nhr_anal in $iaufhrs2; do

charfhr="fhr"`printf %02i $nhr_anal`
charfhr2=`printf %02i $nhr_anal`

if [ $cleanup_ensmean == 'true' ] || ([ $cleanup_ensmean == 'false' ] && [ ! -s ${datapath}/${analdate}/${fileprefix}_${analdate}_${charfhr}_ensmean ]); then
   /bin/rm -f ${fileprefix}_${analdate}_${charfhr}_ensmean
   export PGM="${execdir}/getsigensmeanp_smooth.x ${datapath2}/ ${fileprefix}_${analdate}_${charfhr}_ensmean ${fileprefix}_${analdate}_${charfhr} ${nanals}"
   ${enkfscripts}/runmpi
   if [ $nhr_anal -eq $ANALINC ]; then
      export PGM="${execdir}/getsigensstatp.x ${datapath2}/ ${fileprefix}_${analdate}_${charfhr} ${nanals}"
      ${enkfscripts}/runmpi
   fi
fi

done
ls -l ${datapath2}/${fileprefix}_${analdate}*ensmean
