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
ta-da!

## Example Usage

Basic usage is exemplified below:

```shell
$ ./adjust_jan_spec_from_T31.sh \
   ${file1} \
   ${file2} \
   ${file3} \
   ${file4}
```

Where:
- `file1`: A `${EXPID}_echam5_main_mm_????01.nc` file (standard post-processing is assumed!)
- `file2`: Original T31 orography (e.g. a `T31GR30_jan_surf.nc` file)
- `file3`: Target T63 orography file
- `File4`: Model output with the target vertical resolution to generate a vertical coordinate table.

Running the script without any argumetns will print a help message.

The resulting file `T63L47_jan_spec_from_T31L19.nc` contains:
- humidity `Q`
- temperature `STP`
- vorticity `SVO`
- divergence `SD`
- log surface pressure `LSP`
vertically and laterally interpolated from the simulated values of the `T31L19` run. 

## Testing and Reproducibility

You may use the supplied `Makefile` to perform a test of PI as well as LGM runs. Prerequisites are an approriately configured `.netrc` file on `mistral`.

```shell
make
```

Configuration files for the `mkexp` program (generator for `mpiesm` runscripts) are also supplied, you may use these to reproduce the `orog_???` tests.

## Contact

For questions, improvement suggestions, or to report bugs; please make use of
the GitHub issue tracker or contact:

Dr. Paul Gierz

Paleoclimate Dynamics

AWI Bremerhaven

email: pgierz@awi.de

<a href="https://orcid.org/0000-0002-4512-087X" target="orcid.widget" rel="noopener noreferrer" style="vertical-align:top;"><img src="https://orcid.org/sites/default/files/images/orcid_16x16.png" style="width:1em;margin-right:.5em;" alt="ORCID iD icon">orcid.org/0000-0002-4512-087X</a>

