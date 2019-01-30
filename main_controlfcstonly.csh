# main driver script
# single resolution hybrid using jacobian in the EnKF

# allow this script to submit other scripts on WCOSS
unsetenv LSB_SUB_RES_REQ 
echo "nodes = $NODES"

set idate_job=1

while (${idate_job} <= ${ndates_job})

source $datapath/fg_only.csh # define fg_only variable.

setenv startupenv "${datapath}/analdate.csh"
source $startupenv

# if SATINFO in obs dir, use it
if ( -s ${obs_datapath}/bufr_${analdate}/global_satinfo.txt) then
   setenv SATINFO ${obs_datapath}/bufr_${analdate}/global_satinfo.txt
endif
setenv OZINFO `csh ${enkfscripts}/pickinfo.csh ${analdate} ozinfo`
setenv CONVINFO `csh ${enkfscripts}/pickinfo.csh ${analdate} convinfo`

#------------------------------------------------------------------------
mkdir -p $datapath

echo "BaseDir: ${basedir}"
echo "EnKFBin: ${enkfbin}"
echo "DataPath: ${datapath}"

############################################################################
# Main Program
# Please do not edit the code below; it is not recommended except lines relevant to getsfcensmean.csh.

env
echo "starting the cycle (${idate_job} out of ${ndates_job})"

# substringing to get yr, mon, day, hr info
setenv yr `echo $analdate | cut -c1-4`
setenv mon `echo $analdate | cut -c5-6`
setenv day `echo $analdate | cut -c7-8`
setenv hr `echo $analdate | cut -c9-10`
setenv ANALHR $hr
# set environment analdate
setenv datapath2 "${datapath}/${analdate}/"
/bin/cp -f ${ANAVINFO_ENKF} ${datapath2}/anavinfo

# setup node parameters used in blendinc.csh, recenter_ens_anal.csh and compute_ensmean_fcst.csh
setenv mpitaskspernode `python -c "import math; print int(math.ceil(float(${nanals})/float(${NODES})))"`
if ($mpitaskspernode < 1) setenv mpitaskspernode 1
setenv OMP_NUM_THREADS `expr $corespernode \/ $mpitaskspernode`
echo "mpitaskspernode = $mpitaskspernode threads = $OMP_NUM_THREADS"
setenv nprocs $nanals
if ($machine == 'theia') then
    # HOSTFILE is machinefile to use for programs that require $nanals tasks.
    # if enough cores available, just one core on each node.
    # NODEFILE is machinefile containing one entry per node.
    setenv HOSTFILE $datapath2/machinesx
    setenv NODEFILE $datapath2/nodefile
    cat $PBS_NODEFILE | uniq > $NODEFILE
    if ($NODES >= $nanals) then
      ln -fs $NODEFILE $HOSTFILE
    else
      # otherwise, leave as many cores empty as possible
      awk "NR%${OMP_NUM_THREADS} == 1" ${PBS_NODEFILE} >&! $HOSTFILE
    endif
    /bin/cp -f $PBS_NODEFILE $datapath2/pbs_nodefile
endif

# current analysis time.
setenv analdate $analdate
# previous analysis time.
set FHOFFSET=`expr $ANALINC \/ 2`
setenv analdatem1 `${incdate} $analdate -$ANALINC`
# next analysis time.
setenv analdatep1 `${incdate} $analdate $ANALINC`
# beginning of current assimilation window
setenv analdatem3 `${incdate} $analdate -$FHOFFSET`
# beginning of next assimilation window
setenv analdatep1m3 `${incdate} $analdate $FHOFFSET`
setenv hrp1 `echo $analdatep1 | cut -c9-10`
setenv hrm1 `echo $analdatem1 | cut -c9-10`
setenv hr `echo $analdate | cut -c9-10`
setenv datapathp1 "${datapath}/${analdatep1}/"
setenv datapathm1 "${datapath}/${analdatem1}/"
mkdir -p $datapathp1
setenv CDATE $analdate

date
echo "analdate minus 1: $analdatem1"
echo "analdate: $analdate"
echo "analdate plus 1: $analdatep1"

# make log dir for analdate
setenv current_logdir "${datapath2}/logs"
echo "Current LogDir: ${current_logdir}"
mkdir -p ${current_logdir}

if ($fg_only == 'false' && $readin_localization == ".true.") then
/bin/rm -f $datapath2/hybens_info
/bin/rm -f $datapath2/hybens_smoothinfo
if ( $?HYBENSINFO ) then
   /bin/cp -f ${HYBENSINFO} ${datapath2}/hybens_info
endif
if ( $?HYBENSMOOTH ) then
   /bin/cp -f ${HYBENSMOOTH} $datapath2/hybens_smoothinfo
endif
endif

setenv PREINP "${RUN}.t${hr}z."
setenv PREINP1 "${RUN}.t${hrp1}z."
setenv PREINPm1 "${RUN}.t${hrm1}z."

#if ($fg_only ==  'false') then
#
#echo "$analdate starting ens mean computation `date`"
#csh ${enkfscripts}/compute_ensmean_fcst.csh >&!  ${current_logdir}/compute_ensmean_fcst.out
#echo "$analdate done computing ensemble mean `date`"
#
## change orography in high-res control forecast nemsio file so it matches enkf ensemble,
## adjust surface pressure accordingly.
#if ($controlfcst == 'true' && $cleanup_ensmean == 'true') then
#   if ($replay_controlfcst == 'true') then
#     # sfg*control2 only used to compute IAU forcing
#     # and for gsi observer diagnostic calculation
#     set charnanal='control2'
#   else
#     set charnanal='control'
#   endif
#   echo "$analdate adjust orog/ps of control forecast on ens grid `date`"
#   /bin/rm -f ${current_logdir}/adjustps.out
#   touch ${current_logdir}/adjustps.out
#   set fh=$FHMIN
#   while ($fh <= $FHMAX)
#     set fhr=`printf %02i $fh`
#     # run concurrently, wait
#     sh ${enkfscripts}/adjustps.sh $datapath2/sfg_${analdate}_fhr${fhr}_${charnanal} $datapath2/sfg_${analdate}_fhr${fhr}_ensmean $datapath2/sfg_${analdate}_fhr${fhr}_${charnanal} >&! ${current_logdir}/adjustps_${fhr}.out &
#     @ fh = $fh + $FHOUT
#   end
#   wait
#   echo "$analdate done adjusting orog/ps of control forecast on ens grid `date`"
#endif
#
## for pure enkf or if replay cycle used for control forecast, symlink
## ensmean files to 'control'
#if ($controlfcst == 'false' || $replay_controlfcst == 'true') then
#   # single res hybrid, just symlink ensmean to control (no separate control forecast)
#   set fh=$FHMIN
#   while ($fh <= $FHMAX)
#     set fhr=`printf %02i $fh`
#     ln -fs $datapath2/sfg_${analdate}_fhr${fhr}_ensmean $datapath2/sfg_${analdate}_fhr${fhr}_control
#     ln -fs $datapath2/bfg_${analdate}_fhr${fhr}_ensmean $datapath2/bfg_${analdate}_fhr${fhr}_control
#     @ fh = $fh + $FHOUT
#   end
#endif
#
## if ${datapathm1}/cold_start_bias exists, GSI run in 'observer' mode
## to generate diag_rad files to initialize angle-dependent 
## bias correction.
#if ( -f ${datapathm1}/cold_start_bias ) then
#   setenv cold_start_bias "true"
#else
#   setenv cold_start_bias "false"
#endif
#
## do hybrid control analysis if controlanal=true
## uses control forecast background, except if replay_controlfcst=true
## ens mean background is used ("control" symlinked to "ensmean", control
## forecast uses "control2")
#if ($controlanal == 'true') then
#   if ($replay_controlfcst == 'true' || $controlfcst == 'false') then
#      # use ensmean mean background if no control forecast is run, or 
#      # control forecast is replayed to ens mean increment
#      setenv charnanal 'control'
#      setenv charnanal2 'ensmean'
#      setenv lobsdiag_forenkf '.true.'
#      setenv skipcat "false"
#   else
#      # use control forecast background if control forecast is run, and it is
#      # not begin replayed to ensemble mean increment.
#      setenv charnanal 'control'
#      setenv charnanal2 'control'
#      setenv lobsdiag_forenkf '.false.'
#      setenv skipcat "false"
#   endif
#   if ($hybgain == 'true') then
#      set type='3DVar'
#   else
#      set type='hybrid 4DEnVar'
#   endif
#   # run Var analysis
#   echo "$analdate run $type `date`"
#   csh ${enkfscripts}/run_hybridanal.csh >&! ${current_logdir}/run_gsi_hybrid.out 
#   # once hybrid has completed, check log files.
#   set hybrid_done=`cat ${current_logdir}/run_gsi_hybrid.log`
#   if ($hybrid_done == 'yes') then
#     echo "$analdate $type analysis completed successfully `date`"
#   else
#     echo "$analdate $type analysis did not complete successfully, exiting `date`"
#     exit 1
#   endif
#else
#   # run gsi observer with ens mean fcst background, saving jacobian.
#   # generated diag files used by EnKF. No control analysis.
#   setenv charnanal 'control' 
#   setenv charnanal2 'ensmean'
#   setenv lobsdiag_forenkf '.true.'
#   setenv skipcat "false"
#   echo "$analdate run gsi observer with `printenv | grep charnanal` `date`"
#   csh ${enkfscripts}/run_gsiobserver.csh >&! ${current_logdir}/run_gsi_observer.out 
#   # once observer has completed, check log files.
#   set hybrid_done=`cat ${current_logdir}/run_gsi_observer.log`
#   if ($hybrid_done == 'yes') then
#     echo "$analdate gsi observer completed successfully `date`"
#   else
#     echo "$analdate gsi observer did not complete successfully, exiting `date`"
#     exit 1
#   endif
#endif
#
## run enkf analysis.
#echo "$analdate run enkf `date`"
#if ($skipcat == "true") then
#  # read un-concatenated pe files (set npefiles to number of mpi tasks used by gsi observer)
#  setenv npefiles `expr $cores \/ $gsi_control_threads`
#else
#  setenv npefiles 0
#endif
#csh ${enkfscripts}/runenkf.csh  >>& ${current_logdir}/run_enkf.out  
## once enkf has completed, check log files.
#set enkf_done=`cat ${current_logdir}/run_enkf.log`
#if ($enkf_done == 'yes') then
#  echo "$analdate enkf analysis completed successfully `date`"
#else
#  echo "$analdate enkf analysis did not complete successfully, exiting `date`"
#  exit 1
#endif
#
## recenter enkf analyses around control analysis
#if ($controlanal == 'true' && $recenter_anal == 'true') then
#   if ($hybgain == 'true' && $alpha > 0) then
#      echo "$analdate blend enkf and 3dvar increments `date`"
#      csh ${enkfscripts}/blendinc.csh >&! ${current_logdir}/blendinc.out 
#      set blendinc_done=`cat ${current_logdir}/blendinc.log`
#      if ($blendinc_done == 'yes') then
#        echo "$analdate increment blending/recentering completed successfully `date`"
#      else
#        echo "$analdate increment blending/recentering did not complete successfully, exiting `date`"
#        exit 1
#      endif
#   else
#      echo "$analdate recenter enkf analysis ensemble around control analysis `date`"
#      csh ${enkfscripts}/recenter_ens_anal.csh >&! ${current_logdir}/recenter_ens_anal.out 
#      set recenter_done=`cat ${current_logdir}/recenter_ens.log`
#      if ($recenter_done == 'yes') then
#        echo "$analdate recentering enkf analysis completed successfully `date`"
#      else
#        echo "$analdate recentering enkf analysis did not complete successfully, exiting `date`"
#        exit 1
#      endif
#   endif
#endif
#
## for passive (replay) cycling of control forecast, optionally run GSI observer
## on control forecast background (diag files saved with 'control2' suffix)
#if ($controlfcst == 'true' && $replay_controlfcst == 'true' && $replay_run_observer == "true") then
#   setenv charnanal 'control2'
#   setenv charnanal2 'control2'
#   setenv lobsdiag_forenkf '.false.'
#   setenv skipcat "false"
#   echo "$analdate run gsi observer with `printenv | grep charnanal` `date`"
#   csh ${enkfscripts}/run_gsiobserver.csh >&! ${current_logdir}/run_gsi_observer2.out 
#   # once observer has completed, check log files.
#   set hybrid_done=`cat ${current_logdir}/run_gsi_observer.log`
#   if ($hybrid_done == 'yes') then
#     echo "$analdate gsi observer completed successfully `date`"
#   else
#     echo "$analdate gsi observer did not complete successfully, exiting `date`"
#     exit 1
#   endif
#endif
#
#endif # skip to here if fg_only = true or fg_only == true

if ($controlfcst == 'true') then
    #echo "$analdate run high-res control first guess `date`"
    #csh ${enkfscripts}/run_fg_control.csh  >&! ${current_logdir}/run_fg_control.out  
    #set control_done=`cat ${current_logdir}/run_fg_control.log`
    #if ($control_done == 'yes') then
    #  echo "$analdate high-res control first-guess completed successfully `date`"
    #else
    #  echo "$analdate high-res control did not complete successfully, exiting `date`"
    #  exit 1
    #endif
    ## run longer forecast at 00UTC
    #if ($hr == '00' && $run_long_fcst == "true") then
    if ($run_long_fcst == "true") then
       if ($hr == '00') then
         setenv FHMAX_LONG 120
       else
         setenv FHMAX_LONG $FHMAX
       endif
       echo "$analdate run high-res control long forecast `date`"
       sh ${enkfscripts}/run_long_fcst.sh  >&! ${current_logdir}/run_long_fcst.out  
       set control_done=`cat ${current_logdir}/run_long_fcst.log`
       if ($control_done == 'yes') then
         echo "$analdate high-res control long forecast completed successfully `date`"
       else
         echo "$analdate high-res control long forecast did not complete successfully `date`"
       endif
       ln -fs $datapath2/fv3longcontrol2_historyp_2016010600_latlon.nc $datapath2/fv3control2_historyp_2016010600_latlon.nc
    endif
endif
#echo "$analdate run enkf ens first guess `date`"
#csh ${enkfscripts}/run_fg_ens.csh  >>& ${current_logdir}/run_fg_ens.out  
#set ens_done=`cat ${current_logdir}/run_fg_ens.log`
#if ($ens_done == 'yes') then
#  echo "$analdate enkf first-guess completed successfully `date`"
#else
#  echo "$analdate enkf first-guess did not complete successfully, exiting `date`"
#  exit 1
#endif

#if ($fg_only == 'false') then
#
## cleanup
#if ($do_cleanup == 'true') then
#   csh ${enkfscripts}/clean.csh >&! ${current_logdir}/clean.out
#endif # do_cleanup = true
#
#wait # wait for backgrounded processes to finish
#
## only save full ensemble data to hpss if checkdate.py returns 0
## a subset will be saved if save_hpss_subset="true" and save_hpss="true"
#set date_check=`python ${homedir}/checkdate.py ${analdate}`
#if ($date_check == 0) then
#  setenv save_hpss_full "true"
#else
#  setenv save_hpss_full "false"
#endif
#cd $homedir
#if ( $save_hpss == "true" ) then
#cat ${machine}_preamble_hpss hpss.sh >! job_hpss.sh
#if ($machine == 'wcoss') then
#   bsub -env "all" < job_hpss.sh
#else if ($machine == 'gaea') then
#   msub -V job_hpss.sh
#else if ($machine == 'cori') then
#   sbatch --export=ALL job_hpss.sh
#else
#   qsub -V job_hpss.sh
#endif
#endif

#if ($run_long_fcst == "true") then
#   if ($hr == "00") then
#   #if ($hr == "00" || $hr == "12") then
#     cat ${machine}_preamble_longfcst run_long_fcst.sh >! job_longfcst.sh
#     if ($machine == 'wcoss') then
#         bsub -env "all" < job_longfcst.sh
#     else if ($machine == 'gaea') then
#         msub -V job_longfcst.sh
#     else if ($machine == 'cori') then
#         sbatch --export=ALL job_longfcst.sh
#     else
#         qsub -V job_longfcst.sh
#     endif
#   endif
#endif

endif # skip to here if fg_only = true

echo "$analdate all done"

# next analdate: increment by $ANALINC
setenv analdate `${incdate} $analdate $ANALINC`

echo "setenv analdate ${analdate}" >! $startupenv
echo "setenv analdate_end ${analdate_end}" >> $startupenv
echo "setenv fg_only false" >! $datapath/fg_only.csh

cd $homedir

echo "$analdate all done `date`"

if ( ${analdate} <= ${analdate_end} ) then
  @ idate_job = ${idate_job} + 1
else
  @ idate_job = $ndates_job + 1
endif

end # next analysis time


if ( ${analdate} <= ${analdate_end}  && ${resubmit} == 'true') then
   echo "current time is $analdate"
   if ($resubmit == "true") then
      echo "resubmit script"
      echo "machine = $machine"
      cat ${machine}_preamble config.sh >! job.sh
      if ($machine == 'wcoss') then
          bsub < job.sh
      else if ($machine == 'gaea') then
          msub job.sh
      else if ($machine == 'cori') then
          sbatch job.sh
      else
          qsub job.sh
      endif
   endif
endif

exit 0