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

# Generate the output file name using the old expid:
only_name=$(basename $Old_T31_output_file)
oldexpid="${only_name%_echam5*}"
ofile="${Standard_T63L47_jan_spec_file%.*}_from_${oldexpid}_T31L19.nc"

# Seperate variable STP (Spectral Temperature) into both spectral temperature
# and log of surface pressure, as it contains spectral temperature in levels
# 1:nlev, and log(SP) in level nlev+1
cdo -s import_e5ml ${Standard_T63L47_jan_spec_file} "${Standard_T63L47_jan_spec_file%.*}"_seperated.nc
rmlist="${Standard_T63L47_jan_spec_file%.*}_seperated.nc $rmlist"
cdo -s sp2gp "${Standard_T63L47_jan_spec_file%.*}"_seperated.nc "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp.nc
rmlist="${Standard_T63L47_jan_spec_file%.*}_seperated_sp2gp.nc $rmlist"

function regrid_vertical_and_horizontal_T31L19_to_T63L47(){
    varname=$1
    newname=$2
    echo "Performing lateral and vertical intepolation for $varname --> $newname"
    # Figure out if we have temperature or humidity as an input, since this
    # needs both to remap correctly...
    if [ $varname == "q" ] || [ $varname == "t" ]
    then
        vars="q,t,aps"
    else
        vars="${varname},aps"
    fi
    #
    # Regrid laterally
    #
    cdo -s remapbil,t63grid \
        -selvar,$vars \
        ${Old_T31_output_file} \
        regrid_file_T63L19.nc
    rmlist="regrid_file_T63L19.nc $rmlist"
    #
    # Determine files needed for vertical regridding
    # 1. Vertical coordinate table
    # FIXME: This is always the same for T63L47...probably, it could be packaged
    # with the script as a requirement, instead of needed a T63 output file...
    cdo -s vct $Default_T63_output_file > vct
    rmlist="vct $rmlist"
    # 2. Target Orography
    cdo -s -chname,GEOSP,geosp -selvar,GEOSP $Target_Orog_file geosp_for_vertical_interpolation.nc
    rmlist="geosp_for_vertical_interpolation.nc $rmlist"
    #
    # Regrid vertically
    #
    cdo -s remapeta,vct,geosp_for_vertical_interpolation.nc \
        regrid_file_T63L19.nc \
        regrid_file_T63L47.nc
    rmlist="regrid_file_T63L47.nc $rmlist"
    # remove the time coordinate
    ncwa -a time regrid_file_T63L47.nc tmp && mv tmp regrid_file_T63L47.nc
    # make sure everything is double and not float (this causes chaos and strange numbers otherwise...)
    ncdump regrid_file_T63L47.nc | sed 's/float/double/g' > tmp; ncgen -o regrid_file_T63L47.nc tmp; rm tmp
    ncrename -v $varname,$newname regrid_file_T63L47.nc tmp; mv tmp regrid_file_T63L47.nc
    ncks -A -C -v $newname regrid_file_T63L47.nc "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp.nc
}


regrid_vertical_and_horizontal_T31L19_to_T63L47 q Q
regrid_vertical_and_horizontal_T31L19_to_T63L47 svo SVO
regrid_vertical_and_horizontal_T31L19_to_T63L47 sd SD
regrid_vertical_and_horizontal_T31L19_to_T63L47 t STP
### Regenerate LSP (2D field, no vertical interpolation needed)
echo "Performing lateral interpolation for lsp --> LSP"
cdo -s -remapbil,t63grid \
    -chname,lsp,LSP \
    -selvar,lsp,aps \
    ${Old_T31_output_file} \
    "${Old_T31_output_file%.*}"_lsp_aps_T63L19.nc
rmlist="${Old_T31_output_file%.*}_lsp_aps_T63L19.nc $rmlist"
ncwa -a time "${Old_T31_output_file%.*}"_lsp_aps_T63L19.nc tmp && mv tmp "${Old_T31_output_file%.*}"_lsp_aps_T63L19.nc
ncdump "${Old_T31_output_file%.*}"_lsp_aps_T63L19.nc | sed 's/float/double/g' > tmp; ncgen -o "${Old_T31_output_file%.*}"_lsp_aps_T63L19.nc tmp; rm tmp
ncks -A -C -v LSP "${Old_T31_output_file%.*}"_lsp_aps_T63L19.nc "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp.nc

# Split up the variables:
cdo splitname "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp.nc "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp_
# Go back to spectral space for the spectral variables:
for var in SVO SD STP LSP
do
    cdo -s gp2sp "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp_${var}.nc "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp_${var}_gp2sp.nc
    rmlist="${Standard_T63L47_jan_spec_file%.*}_seperated_sp2gp_${var}.nc ${Standard_T63L47_jan_spec_file%.*}_seperated_sp2gp_${var}_gp2sp.nc $rmlist"
done
rmlist="${Standard_T63L47_jan_spec_file%.*}_seperated_sp2gp_Q.nc $rmlist"

cdo merge \
    "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp_SVO_gp2sp.nc \
    "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp_SD_gp2sp.nc \
    "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp_STP_gp2sp.nc \
    "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp_LSP_gp2sp.nc \
    "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp_Q.nc \
    "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp_gp2sp.nc

# Add the LSP layer back to STP
cdo -s export_e5ml "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp_gp2sp.nc "${Standard_T63L47_jan_spec_file%.*}"_sp2gp_gp2sp.nc
rmlist="${Standard_T63L47_jan_spec_file%.*}_seperated_sp2gp_gp2sp.nc ${Standard_T63L47_jan_spec_file%.*}_sp2gp_gp2sp.nc $rmlist"
mv "${Standard_T63L47_jan_spec_file%.*}"_sp2gp_gp2sp.nc ${ofile}

##### Clean Up:
rm -f $rmlist
exit
