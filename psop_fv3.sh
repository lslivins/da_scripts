cd $datapath2
ls -l ${datapath2}/psobs.txt
/bin/rm -rf diag*
ntimes=`expr 1 + \( $FHMAX - $FHMIN \) \/ $FHOUT`
cat > psop.nml <<EOF
&psop_nml
   res = ${RES},
   date = '${analdate}',
   datapath = '${datapath2}',
   ntimes = ${ntimes},
   fhmin = ${FHMIN},
   fhout = ${FHOUT},
   nlev = 16,
   obsfile = '${datapath2}/psobs.txt',
   meshfile = '${enkfscripts}/C${RES}_grid.pickle'
/
EOF
# these are set in main.csh
#export nprocs=$nanals
#export HOSTFILE=${datapath2}/machinesx
#export OMP_NUM_THREADS=1
export PGM="$python ${enkfscripts}/psop_fv3_mpi.py"
sh ${enkfscripts}/runmpi
ls -l diag_conv_ges*
