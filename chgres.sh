export nprocs=1
export mpitaskspernode=1
export OMP_NUM_THREADS=1
export PGM=$CHGRESEXEC

export VERBOSE=YES
export OMP_STACKSIZE=512M
charnanal="ensmean"
pushd ${datapath2}

iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`
echo  "iaufhrs2= $iaufhrs2"
for nhr_anal in $iaufhrs2; do
charfhr="fhr"`printf %02i $nhr_anal`

# reduce resolution of gfs hybrid analysis and recenter enkf ensemble around it.
SIGI=${datapath2}/${fileprefixin}_${analdate}_${charfhr}_${charnanal}
SIGO=${datapath2}/${fileprefixin}_${analdate}_${charfhr}_${charnanal}.chgres
terrain_file=${datapath2}/${fileprefixout}_${analdate}_${charfhr}_ensmean

DATA=$datapath2/chgrestmp$$
mkdir -p $DATA
pushd $DATA
ln -fs ${SIGI}            atmanl_gsi
ln -fs ${terrain_file} atmanl_ensmean
echo "interpolate ${SIGI} to ${LONB} x ${LATB} grid"
echo "terrain from ${terrain_file"
echo "output to ${SIGO}"
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

${enkfscripts}/runmpi
#$CHGRESEXEC
/bin/mv -f atmanl_gsi_ensres ${SIGO}
popd
/bin/rm -rf $DATA

done # next time
popd

exit -
