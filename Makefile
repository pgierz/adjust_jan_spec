# This Makefile makes testing easy. Hooray for testing! :-)
#
# Dr. Paul Gierz
# AWI Bremerhaven

testdirPI = tests/T63L47_PI
testdirLGM = tests/T63L47_LGM

.PHONY: default
default: all

all: get_test_data test_PI_from_echam5 test_PI_from_echam6 test_PI_from_echam6_without_sp2gp test_LGM_from_echam5 test_LGM_from_echam6 test_LGM_from_echam6_without_sp2gp

get_test_data:
	./get_test_data.sh
	tar -xzvf tests.tar.gz 
	
test_PI_from_echam5:
	./adjust_jan_spec_from_T31.sh \
		${testdirPI}/data/EXP003_echam5_main_mm_560101.nc \
		${testdirPI}/data/T31GR30_jan_surf.nc \
		${testdirPI}/data/T63GR15_jan_surf.nc \
		${testdirPI}/data/E280_echam6_echam_2681.grb

test_PI_from_echam6:
	./adjust_jan_spec_from_T63.sh \
		${testdirPI}/data/E280_echam6_echam_2700.nc

test_PI_from_echam6_without_sp2gp:
	./adjust_jan_spec_from_T63_without_spectral_gridpoint_smoothing.sh \
		${testdirPI}/data/E280_echam6_echam_2700.nc

test_LGM_from_echam5:
	./adjust_jan_spec_from_T31.sh \
		${testdirLGM}/data/lgmctl_wiso_echam5_main_mm_379901.nc \
		${testdirLGM}/data/T31GR30_jan_surf_LGM_PTA2SLM.nc \
		${testdirLGM}/data/T63GR15_jan_surf_21ka_Lev_full.nc \
		${testdirLGM}/data/Lev21ka_echam6_echam_2860.grb

test_LGM_from_echam6:
	./adjust_jan_spec_from_T63.sh \
		${testdirLGM}/data/Lev21ka_echam6_echam_2850.nc

test_LGM_from_echam6_without_sp2gp:
	./adjust_jan_spec_from_T63_without_spectral_gridpoint_smoothing.sh \
		${testdirLGM}/data/Lev21ka_echam6_echam_2850.nc
