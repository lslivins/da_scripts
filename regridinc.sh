#!/bin/sh
set -x
source $MODULESHOME/init/sh
module load nco
module load cdo

input_fg_lores=$1
input_anal_lores=$2
input_fg_hires=$3
input_anal_hires=$4
targetgrid_file=$input_fg_hires
output_anal_lores=$5
output_anal_hires=$6
alpha=$7 # weight for lores increment
beta=$8 # weight for hires increment

wt_lores=`python -c "print $alpha / 1000.0"`
wt_hires=`python -c "print $beta / 1000.0"`
echo "wt_lores,wt_hires = $wt_lores,$wt_hires"

#  compute high res inc target grid definition
cdo griddes $input_fg_hires > /tmp/hires_griddef$$
#  compute low res inc target grid definition
cdo griddes $input_fg_lores > /tmp/lores_griddef$$

# compute low res increment file
ncdiff $input_anal_lores $input_fg_lores /tmp/loresinc$$.nc4
ls -l /tmp/loresinc$$.nc4

# compute high res increment file
ncdiff $input_anal_hires $input_fg_hires /tmp/hiresinc$$.nc4
ls -l  /tmp/hiresinc$$.nc4

# remap low res inc to high res grid
cdo remapbil,/tmp/hires_griddef$$ /tmp/loresinc$$.nc4 /tmp/loresinc_hires$$.nc4
ls -l /tmp/loresinc_hires$$.nc4

# remap high res inc to low res grid
cdo remapbil,/tmp/lores_griddef$$ /tmp/hiresinc$$.nc4 /tmp/hiresinc_lores$$.nc4
ls -l /tmp/hiresinc_lores$$.nc4

# compute weighted average of increments on low res grid
ncflint -w $wt_lores,$wt_hires /tmp/loresinc$$.nc4 /tmp/hiresinc_lores$$.nc4 /tmp/blendedinc_lores$$.nc4

# compute weighted average of increments on high res grid
ncflint -w $wt_lores,$wt_hires /tmp/loresinc_hires$$.nc4 /tmp/hiresinc$$.nc4 /tmp/blendedinc_hires$$.nc4
ls -l /tmp/blendedinc_hires$$.nc4

# compute new analysis file on high res grid
ncflint -w 1.0,1.0 -O $input_fg_hires /tmp/blendedinc_hires$$.nc4 ${output_anal_hires}.nc4
ls -l ${output_anal_hires}.nc4

# compute new analysis file on high res grid
ncflint -w 1.0,1.0 -O $input_fg_lores /tmp/blendedinc_lores$$.nc4 ${output_anal_lores}.nc4
ls -l ${output_anal_lores}.nc4

# save increment files.
#/bin/mv -f /tmp/blendedinc_hires$$.nc4 ${datapath2}/blendedinc_hires_${charfhr}.nc4
#/bin/mv -f /tmp/hiresinc$$.nc4 ${datapath2}/hiresinc_${charfhr}.nc4
#/bin/mv -f /tmp/loresinc_hires$$.nc4 ${datapath2}/loresinc_hires_${charfhr}.nc4
#/bin/mv -f /tmp/blendedinc_lores$$.nc4 ${datapath2}/blendedinc_lores_${charfhr}.nc4
#/bin/mv -f /tmp/loresinc$$.nc4 ${datapath2}/loresinc_${charfhr}.nc4
#/bin/mv -f /tmp/hiresinc_lores$$.nc4 ${datapath2}/hiresinc_lores_${charfhr}.nc4

/bin/rm -f /tmp/*$$.nc4 /tmp/*griddef$$

# convert $output_anal_hires $output_anal_lores back to nemsio binary
nemsio_file="$(dirname $input_anal_hires)/$(basename $input_anal_hires .nc4)"
${execdir}/nctonemsio.x ${output_anal_hires}.nc4 $nemsio_file ${output_anal_hires}
nemsio_file="$(dirname $input_anal_lores)/$(basename $input_anal_lores .nc4)"
${execdir}/nctonemsio.x ${output_anal_lores}.nc4 $nemsio_file ${output_anal_lores}
ls -l ${output_anal_hires}
ls -l ${output_anal_lores}
