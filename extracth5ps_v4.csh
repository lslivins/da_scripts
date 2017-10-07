module load hdf5
set date=$1
set fileout=$2
/bin/rm -f $fileout
touch $fileout
${execdir}/h5totxt_v4 $date >> $fileout
