#!/usr/bin/env bash
read -r -d '' usage <<'EOF'
This script regenerates a T63L47_jan_spec.nc input file from an existing T31 simulation in order to cope with adapted orography
Requirements:

$1 <EXPID>_echam5_main_mm_????01.nc
   --> NOTE This *MUST* be a January file!
$2 Adapted T63 orography
$3 Some output from a T63 model to get the vertical coordinate table

Paul Gierz, AWI Bremerhaven
December 2017
EOF

# Check the arguments!
if [ "$#" -ne 3 ]; then
    echo "Illegal number of parameters"
    echo "$usage"
    exit
fi

# Parse the inputs to this script
Old_T31_output_file=$1
Target_Orog_file=$2
Default_T63_output_file=$3

# Keep a cleanup variable around
rmlist=""

# Set up the environment for this script:
module load cdo                 # PG: Maybe think about using a different cdo version here?
echo "Using cdo Version: "
cdo -s -V

# Get the standard T63L47_jan_spec.nc to work with
Standard_T63L47_jan_spec_filepath_file=/home/ollie/pgierz/reference_stuff/T63L47_jan_spec.nc
cp $Standard_T63L47_jan_spec_filepath_file .
Standard_T63L47_jan_spec_file=$(basename $Standard_T63L47_jan_spec_filepath_file)
cp $Standard_T63L47_jan_spec_file "${Standard_T63L47_jan_spec_file%.*}_from_T31.nc"
ofile="${Standard_T63L47_jan_spec_file%.*}_from_T31.nc"
# Seperate variable STP (Spectral Temperature) into both spectral tmeperature
# and log of surface pressure, as it contains spectral temperature in levels
# 1:nlev, and log(SP) in level nlev+1
cdo -s import_e5ml ${Standard_T63L47_jan_spec_file} "${Standard_T63L47_jan_spec_file%.*}"_seperated.nc
cdo -s sp2gp "${Standard_T63L47_jan_spec_file%.*}"_seperated.nc "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp.nc

### Regenerate Q 
# Get the required variables from the old T31 output file
cdo -s -remapbil,t63grid \
    -selvar,q,t,aps \
    $Old_T31_output_file \
    "${Old_T31_output_file%.*}"_q_t_aps_T63L19.nc
rmlist="${Old_T31_output_file%.*}"_q_t_aps_T63L19.nc
# Get the vertical coordinate table
cdo -s vct $Default_T63_output_file > vct
rmlist="vct $rmlist"
# Get the target orography (geosp)
cdo -s -chname,GEOSP,geosp -selvar,GEOSP $Target_Orog_file geosp_for_vertical_interpolation.nc
cdo -s remapeta,vct,geosp_for_vertical_interpolation.nc \
    "${Old_T31_output_file%.*}"_q_t_aps_T63L19.nc \
    "${Old_T31_output_file%.*}"_q_t_aps_T63L47.nc
rmlist="geosp_for_vertical_interpolation.nc $rmlist"
remapped_file="${Old_T31_output_file%.*}"_q_t_aps_T63L47.nc
rmlist="$remapped_file $rmlist"
# FIXME: geosp not found?
### DONE! (cdo still warns us about not existing geosp)

### Replace the new Q in the output file:
# Kill the time dimension
ncwa -a time $remapped_file tmp && mv tmp $remapped_file
ncdump $remapped_file | sed 's/float/double/g' > tmp; ncgen -o $remapped_file tmp; rm tmp
ncrename -v q,Q $remapped_file tmp; mv tmp $remapped_file
# Put the Q in the output file
ncks -A -C -v Q $remapped_file "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp.nc
### DONE! 

### Regenerate SVO
cdo -s -remapbil,t63grid \
    -chname,svo,SVO \
    -selvar,svo,aps \
    ${Old_T31_output_file} \
    "${Old_T31_output_file%.*}"_svo_aps_T63L19.nc
rmlist="${Old_T31_output_file%.*}"_svo_aps_T63L19.nc
cdo -s -remapeta,vct,geosp_for_vertical_interpolation.nc \
    "${Old_T31_output_file%.*}"_svo_aps_T63L19.nc \
    "${Old_T31_output_file%.*}"_svo_aps_T63L47.nc
ncwa -a time "${Old_T31_output_file%.*}"_svo_aps_T63L47.nc tmp && mv tmp "${Old_T31_output_file%.*}"_svo_aps_T63L47.nc
ncdump "${Old_T31_output_file%.*}"_svo_aps_T63L47.nc | sed 's/float/double/g' > tmp; ncgen -o "${Old_T31_output_file%.*}"_svo_aps_T63L47.nc tmp; rm tmp
ncks -A -C -v SVO "${Old_T31_output_file%.*}"_svo_aps_T63L47.nc "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp.nc

### Regenerate SD
cdo -s -remapbil,t63grid \
    -chname,sd,SD \
-selvar,sd,aps \
    ${Old_T31_output_file} \
    "${Old_T31_output_file%.*}"_sd_aps_T63L19.nc
rmlist="${Old_T31_output_file%.*}"_sd_aps_T63L19.nc
cdo -s -remapeta,vct,geosp_for_vertical_interpolation.nc \
    "${Old_T31_output_file%.*}"_sd_aps_T63L19.nc \
    "${Old_T31_output_file%.*}"_sd_aps_T63L47.nc
ncwa -a time "${Old_T31_output_file%.*}"_sd_aps_T63L47.nc tmp && mv tmp "${Old_T31_output_file%.*}"_sd_aps_T63L47.nc
ncdump "${Old_T31_output_file%.*}"_sd_aps_T63L47.nc | sed 's/float/double/g' > tmp; ncgen -o "${Old_T31_output_file%.*}"_sd_aps_T63L47.nc tmp; rm tmp
ncks -A -C -v SD "${Old_T31_output_file%.*}"_sd_aps_T63L47.nc "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp.nc

##### Clean Up:
rm $rmlist
exit

### Regenerate STP
cdo -s -remapbil,t63grid \
    -chname,t,STP \
    -selvar,t,aps \
    ${Old_T31_output_file} \
    "${Old_T31_output_file%.*}"_t_aps_T63L19.nc
rmlist="${Old_T31_output_file%.*}"_t_aps_T63L19.nc
cdo -s -remapeta,vct,geosp_for_vertical_interpolation.nc \
    "${Old_T31_output_file%.*}"_t_aps_T63L19.nc \
    "${Old_T31_output_file%.*}"_t_aps_T63L47.nc
ncwa -a time "${Old_T31_output_file%.*}"_t_aps_T63L47.nc tmp && mv tmp "${Old_T31_output_file%.*}"_t_aps_T63L47.nc
ncdump "${Old_T31_output_file%.*}"_t_aps_T63L47.nc | sed 's/float/double/g' > tmp; ncgen -o "${Old_T31_output_file%.*}"_t_aps_T63L47.nc tmp; rm tmp
ncks -A -C -v STP "${Old_T31_output_file%.*}"_t_aps_T63L47.nc "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp.nc

### Regenerate LSP
cdo -s -remapbil,t63grid \
    -chname,lsp,LSP \
    -selvar,lsp,aps \
    ${Old_T31_output_file} \
    "${Old_T31_output_file%.*}"_lsp_aps_T63L19.nc
rmlist="${Old_T31_output_file%.*}"_lsp_aps_T63L19.nc
cdo -s -remapeta,vct,geosp_for_vertical_interpolation.nc \
    "${Old_T31_output_file%.*}"_lsp_aps_T63L19.nc \
    "${Old_T31_output_file%.*}"_lsp_aps_T63L47.nc
ncwa -a time "${Old_T31_output_file%.*}"_lsp_aps_T63L47.nc tmp && mv tmp "${Old_T31_output_file%.*}"_lsp_aps_T63L47.nc
ncdump "${Old_T31_output_file%.*}"_lsp_aps_T63L47.nc | sed 's/float/double/g' > tmp; ncgen -o "${Old_T31_output_file%.*}"_lsp_aps_T63L47.nc tmp; rm tmp
ncks -A -C -v LSP "${Old_T31_output_file%.*}"_lsp_aps_T63L47.nc "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp.nc





##### Clean Up:
rm $rmlist
exit
