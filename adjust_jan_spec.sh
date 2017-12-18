#!/usr/bin/env bash
echo -e "\033[1;32m S T A R T   O F   P R O G R A M "
echo    adjust_jan_spec.sh
echo -e "\033[0m"

read -r -d '' usage <<'EOF'
This script regenerates a T63L47_jan_spec.nc input file from an existing T31 simulation in order to cope with adapted orography
Requirements:

$1 <EXPID>_echam5_main_mm_????01.nc
   --> NOTE This *MUST* be a January file!
$2 Original T31 orography (a T31GR30_jan_surf file)
$3 Adapted T63 orography (a T63GR15_jan_surf file)
$4 Some output from a T63 model to get the vertical coordinate table

Paul Gierz, AWI Bremerhaven
December 2017
EOF

# Check the arguments!
if [ "$#" -ne 4 ]; then
    echo "Illegal number of parameters"
    echo "$usage"
    exit
fi

# Parse the inputs to this script
Old_T31_output_file=$1
Source_Orog_file=$2
Target_Orog_file=$3
Default_T63_output_file=$4

# Keep a cleanup variable around
rmlist=""

# Get the standard T63L47_jan_spec.nc to work with
# and set up the environment for this script
module purge
case $HOSTNAME in
    (mlogin*)
        Standard_T63L47_jan_spec_filepath_file=/pool/data/ECHAM6/T63/T63L47_jan_spec.nc
        module load cdo
        module load nco
        module load netcdf_c/4.3.2-gcc48
        ;;
    (ollie*)
        Standard_T63L47_jan_spec_filepath_file=/home/ollie/pgierz/reference_stuff/T63L47_jan_spec.nc
        module load cdo
        module load nco
        module load netcdf
        ;;
    (*)
        echo "I don't know where to look for the standard T63L47_jan_spec.nc file! Please add a case!"
        exit
esac

echo -e "\033[1;33m Using cdo Version: "
cdo -s -V
echo -e "\033[0m"

# Print some info about the CDO stuff that needed to be learned:
echo -e "\033[1;33m For more information about the"
echo "cdo remapeta command, please see: "
echo "https://code.mpimet.mpg.de/issues/8144"
echo -e "\033[0m"

cp $Standard_T63L47_jan_spec_filepath_file .
Standard_T63L47_jan_spec_file=$(basename $Standard_T63L47_jan_spec_filepath_file)

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
    echo -e "\033[0;36m Performing lateral and vertical intepolation for $varname --> $newname \033[0m"
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
    #
    # Make sure the spectral coefficients are in the regrid file
    #
    if      $(ncdump -h regrid_file_T63L19.nc | grep -q hyai) ||
            $(ncdump -h regrid_file_T63L19.nc | grep -q hybi) ||
            $(ncdump -h regrid_file_T63L19.nc | grep -q hyma) ||
            $(ncdump -h regrid_file_T63L19.nc | grep -q hybm)
    then
        : #  Variables found, do nothing...
    else
        ncks -v hyai,hybi,hyam,hybm ${Old_T31_output_file} spectral_parameters.nc
        ncks -A spectral_parameters.nc regrid_file_T63L19.nc
        rmlist="spectral_parameters.nc $rmlist"
    fi
    #
    # Ensure that the lev is described correctly
    #
    ncatted \
        -a standard_name,lev,o,c,"hybrid_sigma_pressure" \
        -a long_name,lev,o,c,"hybrid level at layer midpoints" \
        -a formula,lev,o,c,"hyam hybm (mlev=hyam+hyb*aps)" \
        -a formula_terms,lev,o,c,"ap: hyam b: hybm ps: aps" \
        -a units,lev,o,c,"level" \
        -a positive,lev,o,c,"down" \
        regrid_file_T63L19.nc \
        tmp
    mv tmp regrid_file_T63L19.nc
    #
    # Add the SOURCE orography to the input file
    #
    cdo -s remapbil,t63grid \
        -selvar,GEOSP \
        ${Source_Orog_file} \
        source_orography.nc
    cdo -s merge source_orography.nc regrid_file_T63L19.nc tmp
    mv tmp regrid_file_T63L19.nc
    rmlist="regrid_file_T63L19.nc source_orography.nc $rmlist"
    #
    # Determine files needed for vertical regridding
    # 1. Vertical coordinate table
    cdo -s vct $Default_T63_output_file > vct
    rmlist="vct $rmlist"
    # 2. Target Orography
    cdo -s -chname,GEOSP,geosp -selvar,GEOSP $Target_Orog_file target_geosp_for_vertical_interpolation.nc
    rmlist="target_geosp_for_vertical_interpolation.nc $rmlist"
    #
    # Regrid vertically
    #
    cdo -s remapeta,vct,target_geosp_for_vertical_interpolation.nc \
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
echo -e "\033[0;36m Performing lateral interpolation for lsp --> LSP \033[0m"
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
cdo -s splitname "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp.nc "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp_
# Go back to spectral space for the spectral variables:
for var in SVO SD STP LSP
do
    cdo -s gp2sp "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp_${var}.nc "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp_${var}_gp2sp.nc
    rmlist="${Standard_T63L47_jan_spec_file%.*}_seperated_sp2gp_${var}.nc ${Standard_T63L47_jan_spec_file%.*}_seperated_sp2gp_${var}_gp2sp.nc $rmlist"
done
rmlist="${Standard_T63L47_jan_spec_file%.*}_seperated_sp2gp_Q.nc $rmlist"

cdo -s merge \
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


echo -e "\033[1;32m F I N I S H E D! "
echo -e "\033[0m"
exit
