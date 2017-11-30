#!/usr/bin/env bash
#
# This script regenerates a T63L47_jan_spec.nc input file from an existing T31 simulation in order to cope with adapted orography
# Requirements:
#
# $1 <EXPID>_echam5_main_mm_????01.nc
#    --> NOTE This *MUST* be a January file!
# $2 Adapted T63 orography
# $3 Some output from a T63 model to get the vertical coordinate table
#
# Paul Gierz, AWI Bremerhaven
# December 2017

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
module list > currently_loaded_modules
rmlist="currently_loaded_modules $rmlist"
module purge
module load cdo                 # PG: Maybe think about using a different CDO version here?
echo "Using CDO Version: "
cdo -V

# Get the standard T63L47_jan_spec.nc to work with
Standard_T63L47_jan_spec_filepath_file=/home/ollie/pgierz/reference_stuff/T63L47_jan_spec.nc
cp $Standard_T63L47_jan_spec_filepath_file .
Standard_T63L47_jan_spec_file=$(basename $Standard_T63L47_fan_spec_filepath_file)
cp $Standard_T63L46_jan_spec_file "{$Standard_T63L46_jan_spec_file%.*}_from_T31.nc"
ofile="{$Standard_T63L46_jan_spec_file%.*}_from_T31.nc"
# Seperate variable STP (Spectral Temperature) into both spectral tmeperature
# and log of surface pressure, as it contains spectral temperature in levels
# 1:nlev, and log(SP) in level nlev+1
cdo import_e5ml ${Standard_T63L47_jan_spec_file} "${Standard_T63L47_jan_spec_file%.*}"_seperated.nc

### Regenerate Q onto T63 in the right dimensionality
# Get the required variables from the old T31 output file
cdo -remapbil,t63grid \
    -selvar,q,t,aps \
    $Old_T31_output_file \
    "${Old_T31_output_file%.*}"_q_t_aps_T63L19.nc
# Get the vertical coordinate table
cdo vct $Default_T63_output_file > vct
# Get the target orography (geosp)
cdo -chname,GEOSP,geosp -selvar,GEOSP $Target_Orog_file geosp_for_vertical_interpolation.nc
cdo remapeta,vct,geosp_for_vertical_interpolation.nc \
    "${Old_T31_output_file%.*}"_q_t_aps_T63L19.nc \
    "${Old_T31_output_file%.*}"_q_t_aps_T63L47.nc
remapped_file="${Old_T31_output_file%.*}"_q_t_aps_T63L47.nc
# FIXME: geosp not found?
### DONE! (cdo still warns us about not existing geosp)

### Replace the new Q in the output file:
# Kill the time dimension
ncwa -a time $remapped_file tmp1
rmlist="tmp1 $rmlist"
# Make sure it's called nlev, not lev
ncrename -d lev,nlev -v lev,nlev tmp1 tmp2
rmlist="tmp2 $rmlist"
# Put the dimensions in the right order
ncpdq -a lat,nlev,lon tmp2 tmp3
rmlist="tmp3 $rmlist"
# Rename q to Q
ncrename -v q,Q tmp3 tmp4
rmlist="tmp4 $rmlist"
# Get *JUST* Q and none of the other crap that might still be there
ncks -v Q tmp4 tmp5
rmlist="tmp5 $rmlist"
# For some reason, there may still be a aps. Kill that too:
cdo delname,aps tmp5 tmp6
rmlist="tmp6 $rmlist"
# Change floats to doubles
ncdump tmp6 | sed 's/float/double/g' > tmp7; ncgen -o tmp8 tmp7
rmlist="tmp7 tmp8 $rmlist"
# Put the Q in the output file
ncks -A -v Q tmp8 $ofile
### DONE! Now we need to work on SVO
