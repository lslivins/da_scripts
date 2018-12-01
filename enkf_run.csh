#!/bin/csh
#set verbose

setenv nprocs `expr $cores \/ $enkf_threads`
setenv mpitaskspernode `expr $corespernode \/ $enkf_threads`
setenv OMP_NUM_THREADS $enkf_threads
setenv OMP_STACKSIZE 512M
if ($machine == 'theia') then
   if (! $?hostfilein) then
     setenv hostfilein $PBS_NODEFILE
     setenv NODEFILE $datapath2/nodefile_enkf
     cat $hostfilein | uniq > $NODEFILE
   endif
   setenv HOSTFILE $datapath2/machinefile_enkf
   /bin/rm -f $HOSTFILE
   if ($enkf_threads > 1) then
      awk "NR%${enkf_threads} == 1" ${hostfilein} >&! $HOSTFILE
   else
      setenv HOSTFILE $hostfilein
   endif
   # only one task on root node
   # (root node has to hold two copies of ob space ensemble for LETKF)
   #if ($mpitaskspernode > 1) then
   #   sed -i "2,${mpitaskspernode}d" $HOSTFILE
   #   setenv nprocs `wc -l $HOSTFILE | cut -f1 -d" "`
   #endif
   echo "${nprocs} cores"
   cat $HOSTFILE
   wc -l $HOSTFILE
endif

set iaufhrs2=`echo $iaufhrs | sed 's/,/ /g'`

foreach nfhr ( $iaufhrs2 )
set charfhr="fhr"`printf %02i $nfhr`
# check output files.
set nanal=1
set filemissing='no'
while ($nanal <= $nanals)
   set charnanal="mem"`printf %03i $nanal`
   set analfile="${datapath2}/sanl_${analdate}_${charfhr}_${charnanal}"
   if ( ! -s $analfile) set filemissing='yes'
   @ nanal = $nanal + 1
end
end

if ($lupd_satbiasc == '.true.') then
   set satbiasc=".true."
else
   set satbiasc=".false."
endif
if ( $satbiasc == ".true." &&  ! -s $ABIAS) set filemissing='yes'


if ($filemissing == 'yes') then

echo "computing enkf update..."

date
cd ${datapath2}

cat <<EOF1 >! enkf.nml
 &nam_enkf
  datestring="$analdate",datapath="$datapath2",
  analpertwtnh=$analpertwtnh,analpertwtsh=$analpertwtsh,analpertwttr=$analpertwttr,
  analpertwtnh_rtpp=$analpertwtnh_rtpp,analpertwtsh_rtpp=$analpertwtsh_rtpp,analpertwttr_rtpp=$analpertwttr_rtpp,
  lupd_satbiasc=$satbiasc,zhuberleft=$zhuberleft,zhuberright=$zhuberright,huber=$huber,varqc=$varqc,
  covinflatemax=$covinflatemax,covinflatemin=$covinflatemin,pseudo_rh=$pseudo_rh,
  corrlengthnh=$corrlengthnh,corrlengthsh=$corrlengthsh,corrlengthtr=$corrlengthtr,
  obtimelnh=$obtimelnh,obtimelsh=$obtimelsh,obtimeltr=$obtimeltr,iassim_order=$iassim_order,
  lnsigcutoffnh=$lnsigcutoffnh,lnsigcutoffsh=$lnsigcutoffsh,lnsigcutofftr=$lnsigcutofftr,
  lnsigcutoffsatnh=$lnsigcutoffsatnh,lnsigcutoffsatsh=$lnsigcutoffsatsh,lnsigcutoffsattr=$lnsigcutoffsattr,
  lnsigcutoffpsnh=$lnsigcutoffpsnh,lnsigcutoffpssh=$lnsigcutoffpssh,lnsigcutoffpstr=$lnsigcutoffpstr,
  simple_partition=.true.,nlons=$LONA,nlats=$LATA,smoothparm=$SMOOTHINF,
  readin_localization=$readin_localization,saterrfact=$saterrfact,numiter=$numiter,
  sprd_tol=$sprd_tol,paoverpb_thresh=$paoverpb_thresh,letkf_flag=$letkf_flag,denkf=$denkf,
  use_qsatensmean=$use_qsatensmean,letkf_novlocal=$letkf_novlocal,modelspace_vloc=$modelspace_vloc,save_inflation=.false.,
  reducedgrid=$reducedgrid,nlevs=$LEVS,nanals=$nanals,deterministic=$deterministic,imp_physics=$imp_physics,
  npefiles=$npefiles,lobsdiag_forenkf=.true.,write_spread_diag=.true.,netcdf_diag=.true.,
  sortinc=$sortinc,univaroz=$univaroz,nhr_anal=$iaufhrs,nhr_state=$enkfstatefhrs,getkf=$getkf,
  use_gfs_nemsio=.true.,adp_anglebc=.true.,angord=4,newpc4pred=.true.,use_edges=.false.,emiss_bc=.true.,biasvar=-500,nobsl_max=$nobsl_max,dfs_sort=$dfs_sort
 /
 &satobs_enkf
  sattypes_rad(1) = 'amsua_n15',     dsis(1) = 'amsua_n15',
  sattypes_rad(2) = 'amsua_n18',     dsis(2) = 'amsua_n18',
  sattypes_rad(3) = 'amsua_n19',     dsis(3) = 'amsua_n19',
  sattypes_rad(4) = 'amsub_n16',     dsis(4) = 'amsub_n16',
  sattypes_rad(5) = 'amsub_n17',     dsis(5) = 'amsub_n17',
  sattypes_rad(6) = 'amsua_aqua',    dsis(6) = 'amsua_aqua',
  sattypes_rad(7) = 'amsua_metop-a', dsis(7) = 'amsua_metop-a',
  sattypes_rad(8) = 'airs_aqua',     dsis(8) = 'airs281SUBSET_aqua',
  sattypes_rad(9) = 'hirs3_n17',     dsis(9) = 'hirs3_n17',
  sattypes_rad(10)= 'hirs4_n19',     dsis(10)= 'hirs4_n19',
  sattypes_rad(11)= 'hirs4_metop-a', dsis(11)= 'hirs4_metop-a',
  sattypes_rad(12)= 'mhs_n18',       dsis(12)= 'mhs_n18',
  sattypes_rad(13)= 'mhs_n19',       dsis(13)= 'mhs_n19',
  sattypes_rad(14)= 'mhs_metop-a',   dsis(14)= 'mhs_metop-a',
  sattypes_rad(15)= 'goes_img_g11',  dsis(15)= 'imgr_g11',
  sattypes_rad(16)= 'goes_img_g12',  dsis(16)= 'imgr_g12',
  sattypes_rad(17)= 'goes_img_g13',  dsis(17)= 'imgr_g13',
  sattypes_rad(18)= 'goes_img_g14',  dsis(18)= 'imgr_g14',
  sattypes_rad(19)= 'goes_img_g15',  dsis(19)= 'imgr_g15',
  sattypes_rad(20)= 'avhrr_n18',     dsis(20)= 'avhrr3_n18',
  sattypes_rad(21)= 'avhrr_metop-a', dsis(21)= 'avhrr3_metop-a',
  sattypes_rad(22)= 'avhrr_n19',     dsis(22)= 'avhrr3_n19',
  sattypes_rad(23)= 'amsre_aqua',    dsis(23)= 'amsre_aqua',
  sattypes_rad(24)= 'ssmis_f16',     dsis(24)= 'ssmis_f16',
  sattypes_rad(25)= 'ssmis_f17',     dsis(25)= 'ssmis_f17',
  sattypes_rad(26)= 'ssmis_f18',     dsis(26)= 'ssmis_f18',
  sattypes_rad(27)= 'ssmis_f19',     dsis(27)= 'ssmis_f19',
  sattypes_rad(28)= 'ssmis_f20',     dsis(28)= 'ssmis_f20',
  sattypes_rad(29)= 'sndrd1_g11',    dsis(29)= 'sndrD1_g11',
  sattypes_rad(30)= 'sndrd2_g11',    dsis(30)= 'sndrD2_g11',
  sattypes_rad(31)= 'sndrd3_g11',    dsis(31)= 'sndrD3_g11',
  sattypes_rad(32)= 'sndrd4_g11',    dsis(32)= 'sndrD4_g11',
  sattypes_rad(33)= 'sndrd1_g12',    dsis(33)= 'sndrD1_g12',
  sattypes_rad(34)= 'sndrd2_g12',    dsis(34)= 'sndrD2_g12',
  sattypes_rad(35)= 'sndrd3_g12',    dsis(35)= 'sndrD3_g12',
  sattypes_rad(36)= 'sndrd4_g12',    dsis(36)= 'sndrD4_g12',
  sattypes_rad(37)= 'sndrd1_g13',    dsis(37)= 'sndrD1_g13',
  sattypes_rad(38)= 'sndrd2_g13',    dsis(38)= 'sndrD2_g13',
  sattypes_rad(39)= 'sndrd3_g13',    dsis(39)= 'sndrD3_g13',
  sattypes_rad(40)= 'sndrd4_g13',    dsis(40)= 'sndrD4_g13',
  sattypes_rad(41)= 'sndrd1_g14',    dsis(41)= 'sndrD1_g14',
  sattypes_rad(42)= 'sndrd2_g14',    dsis(42)= 'sndrD2_g14',
  sattypes_rad(43)= 'sndrd3_g14',    dsis(43)= 'sndrD3_g14',
  sattypes_rad(44)= 'sndrd4_g14',    dsis(44)= 'sndrD4_g14',
  sattypes_rad(45)= 'sndrd1_g15',    dsis(45)= 'sndrD1_g15',
  sattypes_rad(46)= 'sndrd2_g15',    dsis(46)= 'sndrD2_g15',
  sattypes_rad(47)= 'sndrd3_g15',    dsis(47)= 'sndrD3_g15',
  sattypes_rad(48)= 'sndrd4_g15',    dsis(48)= 'sndrD4_g15',
  sattypes_rad(49)= 'iasi_metop-a',  dsis(49)= 'iasi616_metop-a',
  sattypes_rad(50)= 'seviri_m08',    dsis(50)= 'seviri_m08',
  sattypes_rad(51)= 'seviri_m09',    dsis(51)= 'seviri_m09',
  sattypes_rad(52)= 'seviri_m10',    dsis(52)= 'seviri_m10',
  sattypes_rad(53)= 'amsua_metop-b', dsis(53)= 'amsua_metop-b',
  sattypes_rad(54)= 'hirs4_metop-b', dsis(54)= 'hirs4_metop-b',
  sattypes_rad(55)= 'mhs_metop-b',   dsis(55)= 'mhs_metop-b',
  sattypes_rad(56)= 'iasi_metop-b',  dsis(56)= 'iasi616_metop-b',
  sattypes_rad(57)= 'avhrr_metop-b', dsis(57)= 'avhrr3_metop-b',
  sattypes_rad(58)= 'atms_npp',      dsis(58)= 'atms_npp',
  sattypes_rad(59)= 'cris_npp',      dsis(59)= 'cris_npp',
  sattypes_rad(60)= 'msu_n14',       dsis(60)= 'msu_n14',
  sattypes_rad(61)= 'hirs2_n14',     dsis(61)= 'hirs2_n14',
  sattypes_rad(62)= 'hirs3_n15',     dsis(62)= 'hirs3_n15',
  sattypes_rad(63)= 'hirs3_n16',     dsis(63)= 'hirs3_n16',
  sattypes_rad(64)= 'ssu_n14',       dsis(64)= 'ssu_n14',
  sattypes_rad(65)= 'sndr_g08',      dsis(65)= 'sndr_g08',
  sattypes_rad(66)= 'sndr_g09',      dsis(66)= 'sndr_g09',
  sattypes_rad(67)= 'sndr_g10',      dsis(67)= 'sndr_g10',
  sattypes_rad(68)= 'sndr_g11',      dsis(68)= 'sndr_g11',
  sattypes_rad(69)= 'sndr_g12',      dsis(69)= 'sndr_g12',
  sattypes_rad(70)= 'avhrr_n14',     dsis(70)= 'avhrr3_n14',
  sattypes_rad(71)= 'avhrr_n15',     dsis(71)= 'avhrr3_n15',
  sattypes_rad(72)= 'avhrr_n16',     dsis(72)= 'avhrr3_n16',
  sattypes_rad(73)= 'avhrr_n17',     dsis(73)= 'avhrr3_n17',
  sattypes_rad(74)='amsua_n16',      dsis(74)= 'amsua_n16'
  sattypes_rad(75)='amsub_n15',      dsis(75)= 'amsub_n15',  
  sattypes_rad(76)='avhrr_n14',      dsis(76)= 'avhrr2_n14',
 /
 &END
 &ozobs_enkf
  sattypes_oz(1) = 'sbuv2_n11',
  sattypes_oz(2) = 'sbuv2_n14',
  sattypes_oz(3) = 'sbuv2_n16',
  sattypes_oz(4) = 'sbuv2_n17',
  sattypes_oz(5) = 'sbuv2_n18',
  sattypes_oz(6) = 'sbuv2_n19',
  sattypes_oz(7) = 'omi_aura',
  sattypes_oz(8) = 'gome_metop-a',
  sattypes_oz(9) = 'gome_metop-b',
  sattypes_oz(10) = 'mls30_aura',
  
 /
 &END
EOF1


cat enkf.nml

cp ${enkfscripts}/vlocal_eig.dat ${datapath2}

/bin/rm -f ${datapath2}/enkf.log
/bin/mv -f ${current_logdir}/ensda.out ${current_logdir}/ensda.out.save
#module switch impi mvapich2/2.1rc1
setenv PGM $enkfbin
echo "OMP_NUM_THREADS = $OMP_NUM_THREADS"
sh ${enkfscripts}/runmpi >>& ${current_logdir}/ensda.out
if ( ! -s ${datapath2}/enkf.log ) then
   echo "no enkf log file found"
   exit 1
endif
#module switch mvapich2/2.1rc1 impi
if ($satbiasc == '.true.')  /bin/cp -f ${datapath2}/satbias_out $ABIAS

else
echo "enkf update already done..."
endif # filemissing='yes'

# check output files again.
set nanal=1
set filemissing='no'
while ($nanal <= $nanals)
   set charnanal="mem"`printf %03i $nanal`
   set analfile=${datapath2}/sanl_${analdate}_${charfhr}_${charnanal}
   if ( ! -s $analfile) set filemissing='yes'
   @ nanal = $nanal + 1
end
if ( $satbiasc == ".true." &&  ! -s $ABIAS) set filemissing='yes'

if ($filemissing == 'yes') then
    echo "there are output files missing!"
    exit 1
else
    echo "all output files seem OK `date`"
endif

exit 0
