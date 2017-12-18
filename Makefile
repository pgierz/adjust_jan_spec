# This Makefile makes testing easy. Hooray for testing! :-)
#
# Dr. Paul Gierz
# AWI Bremerhaven

testdirPI = tests/T63L47_PI
testdirLGM = tests/T63L47_LGM

all:
	test_PI

test_PI:
	./adjust_jan_spec.sh \
		${testdirPI}/data/EXP003_echam5_main_mm_560101.nc \
		${testdirPI}/data/T31GR30_jan_surf.nc \
		${testdirPI}/data/T63GR15_jan_surf.nc \
		${testdirPI}/data/E280_echam6_echam_2681.grb
