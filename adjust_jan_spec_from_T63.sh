#!/usr/bin/env bash
echo -e "\033[1;32m S T A R T   O F   P R O G R A M "
echo    adjust_jan_spec.sh
echo -e "\033[0m"

read -r -d '' usage <<'EOF'
This script regenerates a T63L47_jan_spec.nc input file from an existing T63 simulation in order to cope with adapted orography
Requirements:

$1 <EXPID>_echam6_echam_????01.nc
   --> NOTE This *MUST* be a January file!

   Paul Gierz, AWI Bremerhaven
December 2017
EOF

# Check the arguments!
if [ "$#" -ne 1 ]; then
    echo "Illegal number of parameters"
    echo "$usage"
    exit
fi

# Parse the inputs to this script
Old_T63_output_file=$1

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
only_name=$(basename $Old_T63_output_file)
oldexpid="${only_name%_echam6*}"
ofile="${Standard_T63L47_jan_spec_file%.*}_from_${oldexpid}_T63L47.nc"

# Seperate variable STP (Spectral Temperature) into both spectral temperature
# and log of surface pressure, as it contains spectral temperature in levels
# 1:nlev, and log(SP) in level nlev+1
cdo -s import_e5ml ${Standard_T63L47_jan_spec_file} "${Standard_T63L47_jan_spec_file%.*}"_seperated.nc
rmlist="${Standard_T63L47_jan_spec_file%.*}_seperated.nc $rmlist"
cdo -s sp2gp "${Standard_T63L47_jan_spec_file%.*}"_seperated.nc "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp.nc
rmlist="${Standard_T63L47_jan_spec_file%.*}_seperated_sp2gp.nc $rmlist"

cdo -s sp2gp ${Old_T63_output_file} "${Old_T63_output_file%.*}"_sp2gp.nc
rmlist="${Old_T63_output_file%.*}_sp2gp.nc $rmlist"

function insert_into_jan_spec_from_T63L47_run() {
    varname=$1
    newname=$2
    echo -e "\033[0;36m Inserting T63 Output into jan_spec file for $varname --> $newname \033[0m"
    cdo -s \
        -selvar,$varname \
        "${Old_T63_output_file%.*}"_sp2gp.nc \
        regrid_file_T63L47.nc
    rmlist="regrid_file_T63L47.nc $rmlist"
    ncwa -a time regrid_file_T63L47.nc tmp && mv tmp regrid_file_T63L47.nc
    # make sure everything is double and not float (this causes chaos and strange numbers otherwise...)
    ncdump regrid_file_T63L47.nc | sed 's/float/double/g' > tmp; ncgen -o regrid_file_T63L47.nc tmp; rm tmp
    ncrename -v $varname,$newname regrid_file_T63L47.nc tmp; mv tmp regrid_file_T63L47.nc
    ncks -A -C -v $newname regrid_file_T63L47.nc "${Standard_T63L47_jan_spec_file%.*}"_seperated_sp2gp.nc
}

insert_into_jan_spec_from_T63L47_run q Q
insert_into_jan_spec_from_T63L47_run svo SVO
insert_into_jan_spec_from_T63L47_run sd SD
insert_into_jan_spec_from_T63L47_run t STP
insert_into_jan_spec_from_T63L47_run lsp LSP

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
