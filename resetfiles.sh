export iaufhrs="3,6,9"
export fileprefixout="sfg2"
export analdate='2016010106'
export datapath='/lustre/f2/scratch/Jeffrey.S.Whitaker/C48C192C384_hybgain'
export datapath2=${datapath}/${analdate}
export nanals=1200

iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`
pushd $datapath2

for nhr_anal in $iaufhrs2; do
   charfhr="fhr"`printf %02i $nhr_anal`
   filename_meanin=${fileprefixout}_${analdate}_${charfhr}_ensmean
   ls -l ${filename_meanin}.orig
   ls -l ${filename_meanin}
   # rename files back
   /bin/mv -f ${filename_meanin}.orig  ${filename_meanin}
   nanal=1
   while [ $nanal -le $nanals ]; do
      charnanal="mem"`printf %04i $nanal`
      analfile=${fileprefixout}_${analdate}_${charfhr}_${charnanal}
      ls -l ${analfile}.orig
      ls -l ${analfile}
      /bin/mv -f ${analfile}.orig ${analfile}
      nanal=$((nanal+1))
   done
done

popd
