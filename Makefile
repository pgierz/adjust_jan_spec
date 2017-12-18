# This Makefile makes testing easy. Hooray for testing! :-)
#
# Dr. Paul Gierz
# AWI Bremerhaven

testdirPI = tests/T63L47_PI
testdirLGM = tests/T63L47_LGM

all:
	get_test_data
	test_PI
	test_LGM

get_test_data:
	./get_test_data.sh
	tar -xzvf tests.tar.gz 
	
test_PI:
	./adjust_jan_spec.sh \
		${testdirPI}/data/EXP003_echam5_main_mm_560101.nc \
		${testdirPI}/data/T31GR30_jan_surf.nc \
		${testdirPI}/data/T63GR15_jan_surf.nc \
		${testdirPI}/data/E280_echam6_echam_2681.grb

test_LGM:
	./adjust_jan_spec.sh \
		${testdirLGM}/data/lgmctl_wiso_echam5_main_mm_379901.nc \
		${testdirLGM}/data/T31GR30_jan_surf_LGM_PTA2SLM.nc \
		${testdirLGM}/data/T63GR15_jan_surf_21ka_Lev_full.nc \
		${testdirLGM}/data/Lev21ka_echam6_echam_2860.grb

