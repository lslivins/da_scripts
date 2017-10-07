#!/bin/csh
#set verbose
module list

if ($machine == 'theia') then
  module list
  module load intel/15.1.133
  module load impi/5.0.3.048
  #module switch impi mvapich2/2.1rc1
  module list
endif

setenv nprocs `expr $cores \/ $enkf_threads`
setenv mpitaskspernode `expr $corespernode \/ $enkf_threads`
setenv OMP_NUM_THREADS $enkf_threads
setenv OMP_STACKSIZE 256M
if ($machine != 'wcoss') then
   if (! $?hostfilein) then
     setenv hostfilein $PBS_NODEFILE
   endif
   setenv HOSTFILE $datapath2/machinefile_enkf
   /bin/rm -f $HOSTFILE
   if ($enkf_threads > 1) then
      awk "NR%${enkf_threads} == 1" ${hostfilein} >&! $HOSTFILE
   else
      setenv HOSTFILE $hostfilein
   endif
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
   if ($iau_delthrs != -1) then
      set analfile="${datapath2}/sanl_${analdate}_${charfhr}_${charnanal}"
   else
      set analfile="${datapath2}/sanl_${analdate}_${charnanal}"
   endif
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
  lupd_satbiasc=$satbiasc,zhuberleft=$zhuberleft,zhuberright=$zhuberright,huber=$huber,varqc=$varqc,
  covinflatemax=$covinflatemax,covinflatemin=$covinflatemin,pseudo_rh=$pseudo_rh,
  corrlengthnh=$corrlengthnh,corrlengthsh=$corrlengthsh,corrlengthtr=$corrlengthtr,
  obtimelnh=$obtimelnh,obtimelsh=$obtimelsh,obtimeltr=$obtimeltr,iassim_order=$iassim_order,
  lnsigcutoffnh=$lnsigcutoffnh,lnsigcutoffsh=$lnsigcutoffsh,lnsigcutofftr=$lnsigcutofftr,
  lnsigcutoffsatnh=$lnsigcutoffsatnh,lnsigcutoffsatsh=$lnsigcutoffsatsh,lnsigcutoffsattr=$lnsigcutoffsattr,
  lnsigcutoffpsnh=$lnsigcutoffpsnh,lnsigcutoffpssh=$lnsigcutoffpssh,lnsigcutoffpstr=$lnsigcutoffpstr,
  simple_partition=.true.,nlons=$LONA,nlats=$LATA,smoothparm=$SMOOTHINF,
  readin_localization=$readin_localization,saterrfact=$saterrfact,numiter=$numiter,
  sprd_tol=$sprd_tol,paoverpb_thresh=$paoverpb_thresh,letkf_flag=$letkf_flag,
  use_qsatensmean=$use_qsatensmean,
  reducedgrid=$reducedgrid,nlevs=$LEVS,nanals=$nanals,deterministic=$deterministic,
  npefiles=0,lobsdiag_forenkf=.false.write_spread_diag=.true.,
  sortinc=$sortinc,univaroz=$univaroz,massbal_adjust=$massbal_adjust,nhr_anal=$iaufhrs,nhr_state=$enkfstatefhrs,
  covl_minfact=$covl_minfact,covl_efold=$covl_efold,
  use_gfs_nemsio=.true.,adp_anglebc=.true.,angord=4,newpc4pred=.true.,use_edges=.false.,emiss_bc=.true.,biasvar=-500,write_spread_diag=.true.,nobsl_max=$nobsl_max
 /
 &satobs_enkf
 /
 &END
 &ozobs_enkf
 /
 &END
EOF1


cat enkf.nml

/bin/rm -f ${datapath2}/enkf.log
/bin/mv -f ${current_logdir}/ensda.out ${current_logdir}/ensda.out.save
setenv PGM $enkfbin
sh ${enkfscripts}/runmpi >>& ${current_logdir}/ensda.out
if ( ! -s ${datapath2}/enkf.log ) then
   echo "no enkf log file found"
   exit 1
endif

if ($satbiasc == '.true.')  /bin/cp -f ${datapath2}/satbias_out $ABIAS

else
echo "enkf update already done..."
endif # filemissing='yes'

setenv mpitaskspernode `python -c "import math; print int(math.ceil(float(${nanals})/float(${NODES})))"`
if ($mpitaskspernode < 1) setenv mpitaskspernode 1
setenv OMP_NUM_THREADS `expr $corespernode \/ $mpitaskspernode`
echo "mpitaskspernode = $mpitaskspernode threads = $OMP_NUM_THREADS"
setenv nprocs $nanals
if ($machine != 'wcoss') then
    # HOSTFILE is machinefile to use for programs that require $nanals tasks.
    # if enough cores available, just one core on each node.
    # NODEFILE is machinefile containing one entry per node.
    setenv HOSTFILE $datapath2/machinefile_enkf
    setenv NODEFILE $datapath2/nodefile_enkf
    cat $hostfilein | uniq > $NODEFILE
    if ($NODES >= $nanals) then
      ln -fs $NODEFILE $HOSTFILE
    else
      # otherwise, leave as many cores empty as possible
      awk "NR%${OMP_NUM_THREADS} == 1" ${hostfilein} >&! $HOSTFILE
    endif
endif

# check output files again.
set nanal=1
set filemissing='no'
while ($nanal <= $nanals)
   set charnanal="mem"`printf %03i $nanal`
   if ($#iaufhrs2 == 1 && $iau_delthrs != -1) then
      echo "rename output file sanl_${analdate}_${charnanal} to sanl_${analdate}_${charfhr}_${charnanal}"
      /bin/mv -f ${datapath2}/sanl_${analdate}_${charnanal} ${datapath2}/sanl_${analdate}_${charfhr}_${charnanal}
   endif
   if ($iau_delthrs != -1) then
      set analfile=${datapath2}/sanl_${analdate}_${charfhr}_${charnanal}
   else
      set analfile=${datapath2}/sanl_${analdate}_${charnanal}
   endif
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

echo "$analdate starting ens mean analysis computation `date`"
csh ${enkfscripts}/compute_ensmean_enkf.csh >&!  ${current_logdir}/compute_ensmean_anal.out
echo "$analdate done computing ensemble mean analyses `date`"

exit 0
