#!/bin/sh

# setup node parameters used in blendinc.csh, recenter_ens_anal.csh and compute_ensmean_fcst.csh
export mpitaskspernode=`python -c "import math; print int(math.ceil(float(${nanals})/float(${NODES})))"`
if [ $mpitaskspernode -lt 1 ]; then
 export mpitaskspernode=1
fi
export OMP_NUM_THREADS=`expr $corespernode \/ $mpitaskspernode`
echo "mpitaskspernode = $mpitaskspernode threads = $OMP_NUM_THREADS"
export nprocs=$nanals

export VERBOSE=YES
export OMP_STACKSIZE=256M
charnanal="ensmean"
pushd ${datapath2}

iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`
echo  "iaufhrs2= $iaufhrs2"
for nhr_anal in $iaufhrs2; do
charfhr="fhr"`printf %02i $nhr_anal`

echo "recenter ensemble perturbations about low resolution hybrid analysis"
filename_meanin=${fileprefix}_${analdate}_${charfhr}_ensmean.orig
ls -l ${filename_meanin}
filename_meanout=${fileprefix}_${analdate}_${charfhr}_${charnanal}
ls -l ${filename_meanout}
filenamein=${fileprefix}_${analdate}_${charfhr}
ls -l ${fileprefix}_${analdate}_${charfhr}_mem0001
filenameout=${fileprefix}r_${analdate}_${charfhr}

export PGM="${execdir}/recentersigp.x $filenamein $filename_meanin $filename_meanout $filenameout $nanals"
errorcode=0
${enkfscripts}/runmpi
status=$?
if [ $status -ne 0 ]; then
 errorcode=1
fi

if [ $errorcode -eq 0 ]; then
   echo "yes" > ${current_logdir}/recenter_ens.log
else
   echo "no" > ${current_logdir}/recenter_ens.log
   exit 1
fi

# rename files.
nanal=1
while [ $nanal -le $nanals ]; do
   charnanal_tmp="mem"`printf %04i $nanal`
   analfiler=${fileprefix}r_${analdate}_${charfhr}_${charnanal_tmp}
   analfile=${fileprefix}_${analdate}_${charfhr}_${charnanal_tmp}
   if [ -s $analfiler ]; then
      /bin/mv -f $analfile ${analfile}.orig
      /bin/mv -f $analfiler $analfile
      status=$?
      if [ $status -ne 0 ]; then
       errorcode=1
      fi
   else
      echo "no" > ${current_logdir}/recenter_ens.log
      exit 1
   fi
   nanal=$((nanal+1))
done

if [ $errorcode -eq 0 ]; then
   echo "yes" > ${current_logdir}/recenter_ens.log
else
   echo "error encountered, copying original files back.."
   echo "no" >! ${current_logdir}/recenter_ens.log
   # rename files back
   nanal=1
   while [ $nanal -le $nanals ]; do
      charnanal_tmp="mem"`printf %04i $nanal`
      analfile=${fileprefix}_${analdate}_${charfhr}_${charnanal_tmp}
      /bin/mv -f ${analfile}.orig ${analfile}
      nanal=$((nanal+1))
   done
   exit 1
fi

done # next time
popd

exit 0
