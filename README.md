# Adjusting `MPIESM` input file `T63L47_jan_spec.nc` from an existant T31L19 `COSMOS` Simulation

The script contained in this repository serves the purpose of creating a new
`T63L47_jan_spec.nc` file utilizing output from a `COSMOS echam5 T31L19`
simulation. Please read the following documentation before you use it.

## "Install"
`cdo` is required. Please make sure to use: `cdo -V >= 1.9.0`

You don't really need to install this. Just do:
```
git clone ${adjust_jan_spec_repo} ${my_favorite_location}
```
ta-da! Congrats. You probably just used `git` for the first time...start using it!! It makes your life easier. I promise.

## Example Usage

Basic usage is exemplified below:

```
$ ./adjust_jan_spec.sh \
   ${file1} \
   ${file2} \
   ${file3}
```

The resulting file `T63L47_jan_spec_from_T31L19.nc` contains:
- humidity `Q`
- temperature `STP`
- vorticity `SVO`
- divergence `SD`
- log surface pressure `LSP`
vertically and laterally interpolated from the simulated values of the `T31L19` run. 


## Contact

For questions, improvement suggestions, or to report bugs; please make use of
the GitHub issue tracker or contact:

Dr. Paul Gierz
Paleoclimate Dynamics
AWI Bremerhaven

email: pgierz@awi.de
orcid: fjalfas
ResearchGate: 
