#!/bin/sh

export mpitaskspernode=`python -c "import math; print int(math.ceil(float(${nanals})/float(${NODES})))"`
if [ $mpitaskspernode -lt 1 ]; then
 export mpitaskspernode=1
fi
export OMP_NUM_THREADS=`expr $corespernode \/ $mpitaskspernode`
echo "mpitaskspernode = $mpitaskspernode threads = $OMP_NUM_THREADS"
export nprocs=$nanals
export VERBOSE=YES
export OMP_STACKSIZE=256M
pushd ${datapath2}

iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`
echo  "iaufhrs2= $iaufhrs2"

for nhr_anal in $iaufhrs2; do
charfhr="fhr"`printf %02i $nhr_anal`
echo "recenter ensemble perturbations about new mean for ${charfhr}"

/bin/mv -f ${fileprefixa}_${analdate}_${charfhr}_ensmean ${fileprefixa}_${analdate}_${charfhr}_ensmean.orig
filename_fg=${fileprefixb}_${analdate}_${charfhr}_ensmean # ens mean first guess
# set these in driving script
filename_anal1=`echo $filename_anal1 | sed -e "s/<charfhr>/${charfhr}/g"`
filename_anal2=`echo $filename_anal2 | sed -e "s/<charfhr>/${charfhr}/g"`
filename_anal=${fileprefixa}_${analdate}_${charfhr}_ensmean # analysis from blended increments
filenamein=${fileprefixa}_${analdate}_${charfhr}
filenameout=${fileprefixa}r_${analdate}_${charfhr}
# new_anal (filename_anal) = fg + alpha*(anal1-fg) + beta*(anal2-fg)
#                          = (1.-alpha-beta)*fg + alpha*anal_3dvar + beta*anal_enkf
export PGM="${execdir}/recenternemsiop_hybgain.x $filename_fg $filename_anal1 $filename_anal2 $filename_anal $filenamein $filenameout $alpha $beta $nanals"

errorcode=0
${enkfscripts}/runmpi
status=$?
if [ $status -ne 0 ]; then
  errorcode=1
fi

if [ $errorcode -eq 0 ]; then
   echo "yes" > ${current_logdir}/blendinc.log
else
   echo "no" > ${current_logdir}/blendinc.log
   exit 1
fi

# rename files.
nanal=1
while [ $nanal -le $nanals ]; do
   charnanal_tmp="mem"`printf %04i $nanal`
   analfiler=${fileprefixa}r_${analdate}_${charfhr}_${charnanal_tmp}
   analfile=${fileprefixa}_${analdate}_${charfhr}_${charnanal_tmp}
   if [ -s $analfiler ]; then
      /bin/mv -f $analfile ${analfile}.orig
      /bin/mv -f $analfiler $analfile
      status=$?
      if [ $status -ne 0 ]; then
        errorcode=1
      fi
   else
      echo "no" > ${current_logdir}/blendinc.log
      exit 1
   fi
   nanal=$((nanal+1))
done

if [ $errorcode -eq 0 ]; then
   echo "yes" > ${current_logdir}/blendinc.log
else
   echo "error encountered, copying original files back.."
   echo "no" > ${current_logdir}/blendinc.log
   # rename files back
   /bin/mv -f ${fileprefixa}_${analdate}_${charfhr}_ensmean.orig ${fileprefixa}_${analdate}_${charfhr}_ensmean
   nanal=1
   while [ $nanal -le $nanals ]; do
      charnanal_tmp="mem"`printf %04i $nanal`
      analfile=${fileprefixa}_${analdate}_${charfhr}_${charnanal_tmp}
      /bin/mv -f ${analfile}.orig ${analfile}
      nanal=$((nanal+1))
   done
   exit 1
fi

done # next time
echo "all done `date`"
popd

exit 0
