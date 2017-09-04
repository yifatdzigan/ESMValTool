#!/bin/bash

#loop for pr files preparation
#interpolation on regolar 2.5x2.5 grid, NH selection, daily averages.
cdo=/usr/bin/cdo
cdonc="$cdo -f nc"
cdo4="$cdo -f nc4 -z zip"

#define experiment and years
year1=$1
year2=$2
infile=$3
outfile=$4



	#$cdonc sellonlatbox,0,360,0,90 -remapcon2,r144x73 -setlevel,50000 -setname,zg -selyear,$year1/$year2 $TEMPDIR/fullfile.nc $TEMPDIR/smallfile.nc
	$cdonc sellonlatbox,0,360,-90,90 -remapcon2,r144x73 -setname,pr -selyear,$year1/$year2 $infile $outfile



