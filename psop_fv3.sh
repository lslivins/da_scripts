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
mpirun -np $nanals $python ${enkfscripts}/psop_fv3_mpi.py
ls -l diag_conv_ges*
