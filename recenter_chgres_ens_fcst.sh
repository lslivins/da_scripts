#!/bin/csh

# setup node parameters used in blendinc.csh, recenter_ens_anal.csh and compute_ensmean_fcst.csh
export mpitaskspernode=`python -c "import math; print int(math.ceil(float(${nanals})/float(${NODES})))"`
if [ $mpitaskspernode -lt 1 ]; then
 export mpitaskspernode=1
fi
export OMP_NUM_THREADS=`expr $corespernode \/ $mpitaskspernode`
echo "mpitaskspernode = $mpitaskspernode threads = $OMP_NUM_THREADS"
export nprocs=$nanals
export VERBOSE YES
export OMP_STACKSIZE 512M
charnanal="ensmean"
pushd ${datapath2}

iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`
echo  "iaufhrs2= $iaufhrs2"
for nhr_anal in $iaufhrs2; do
charfhr="fhr"`printf %02i $nhr_anal`

# reduce resolution of gfs hybrid analysis and recenter enkf ensemble around it.
SIGI=${datapath2}/${fileprefixin}_${analdate}_${charfhr}_${charnanal}
SIGO=${datapath2}/${fileprefixin}_${analdate}_${charfhr}_${charnanal}_lores
filename_meanin=${datapath2}/${fileprefixout}_${analdate}_${charfhr}_ensmean

DATA=$datapath2/chgrestmp$$
mkdir -p $DATA
pushd $DATA
ln -fs ${SIGI}            atmanl_gsi
ln -fs ${filename_meanin} atmanl_ensmean
ls -l

LEVSp1=`expr $LEVS \+ 1`
SIGLEVEL=${FIXGLOBAL}/global_hyblev.l${LEVSp1}.txt

rm -f fort.43
cat > fort.43 << EOF
&nam_setup
  i_output=$LONB
  j_output=$LATB
  input_file="atmanl_gsi"
  output_file="atmanl_gsi_ensres"
  terrain_file="atmanl_ensmean"
  vcoord_file="$SIGLEVEL"
/
EOF

nprocs_save=$nprocs
mpitaskspernode_save=$mpitaskspernode
threads_save=$OMP_NUM_THREADS
export nprocs=1
export mpitaskspernode=1
export OMP_NUM_THREADS=1
export PGM=$CHGRESEXEC
${enkfscripts}/runmpi
#$CHGRESEXEC
#/bin/mv -f atmanl_gsi_ensres ${SIGO}
# make sure idate, fhour are correct in header
${execdir}/nemsio_chgdate.x atmanl_gsi_ensres ${analdatem1} ${nhr_anal} atmanl_gsi_ensres.chgdate
/bin/mv -f atmanl_gsi_ensres.chgdate ${SIGO}
popd
/bin/rm -rf $DATA

if [ ! -s $SIGO ]; then
    echo "error encountered running global_chgres"
    echo "no" > ${current_logdir}/recenter_ens.log
    exit 1
else
    ls -l $SIGO
fi
export nprocs=$nprocs_save
export mpitaskspernode=$mpitaskspernode_save
export OMP_NUM_THREADS=$threads_save


echo "recenter ensemble perturbations about low resolution hybrid analysis"
filename_meanin=${fileprefixout}_${analdate}_${charfhr}_ensmean
filename_meanout=${fileprefixin}_${analdate}_${charfhr}_${charnanal}_lores
filenamein=${fileprefixout}_${analdate}_${charfhr}
filenameout=${fileprefixout}r_${analdate}_${charfhr}

export PGM="${execdir}/recentersigp.x $filenamein $filename_meanin $filename_meanout $filenameout $nanals"
sh ${enkfscripts}/runmpi
if [ $? -eq 0 ]; then
   echo "yes" > ${current_logdir}/recenter_ens.log
else
   echo "no" > ${current_logdir}/recenter_ens.log
   exit 1
fi

# rename files.
/bin/mv -f $filename_meanin  ${filename_meanin}.orig
/bin/cp -f $filename_meanout $filename_meanin
errorcode=0
nanal=1
while [ $nanal -le $nanals ]; do
   charnanal_tmp="mem"`printf %04i $nanal`
   analfiler=${fileprefixout}r_${analdate}_${charfhr}_${charnanal_tmp}
   analfile=${fileprefixout}_${analdate}_${charfhr}_${charnanal_tmp}
   if [ -s $analfiler ]; then
      /bin/mv -f $analfile ${analfile}.orig
      /bin/mv -f $analfiler $analfile
      if [ $? -ne 0 ]; then
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
   /bin/mv -f ${filename_meanin}.orig  ${filename_meanin}
   nanal=1
   while [ $nanal -le $nanals ]; do
      charnanal_tmp="mem"`printf %04i $nanal`
      analfile=${fileprefixout}_${analdate}_${charfhr}_${charnanal_tmp}
      /bin/mv -f ${analfile}.orig ${analfile}
      nanal=$((nanal+1))
   done
   exit 1
fi

done # next time
popd

exit 0
