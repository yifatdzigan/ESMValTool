#!/bin/bash

#loop for pr files preparation
#interpolation on common regolar grid (conservative), lon/lat selection, year/season selection .
cdo=/usr/bin/cdo
cdonc="$cdo -f nc"
cdo4="$cdo -f nc4 -z zip"

#define experiment and years
exp=$1
year1=$2
year2=$3
rgrid=$4               # select common grid for analysis. E.g., rgrid="r320x160"
rlonlatdata=($5 $6 $7 $8)     #$7         # select lon/lat box to limit data array. E.g., (0,360,-90,90)
rlon1=$5
rlon2=$6
rlat1=$7
rlat2=$8
infile=$9
prfilename=${10}

DATADIR=$(dirname $prfilename)
TEMPDIR=$DATADIR/tempdir_${exp}_$RANDOM
mkdir -p $TEMPDIR

echo $prfilename
ls $prfilename
if [ ! -f $prfilename ] ; then

	echo "PR data are missing... full extraction is performed"
        echo "********" $rlon1 $rlon2 $rlat1 $rlat2

	#create a single huge file: not efficient but universal
#	$cdonc cat $INDIR/*.nc $TEMPDIR/fullfile.nc
	#$cdonc sellonlatbox,0,360,0,90 -remapcon2,r144x73 -setlevel,50000 -setname,zg -selyear,$year1/$year2 $TEMPDIR/fullfile.nc $TEMPDIR/smallfile.nc
	#$cdonc sellonlatbox,0,360,-90,90 -remapcon2,r320x160 -selyear,$year1/$year2 $infile $TEMPDIR/smallfile.nc

#	$cdonc sellonlatbox,${rlonlatdata[*]} -remapcon2,$rgrid -selyear,$year1/$year2 $infile $TEMPDIR/smallfile.nc
#	$cdonc sellonlatbox,$rlon1,$rlon2,$rlat1,$rlat2 -remapcon2,$rgrid -selyear,$year1/$year2 $infile $TEMPDIR/smallfile.nc
	$cdonc  -remapcon2,$rgrid -selyear,$year1/$year2 $infile $TEMPDIR/smallfile.nc

	$cdo4 -a copy $TEMPDIR/smallfile.nc $prfilename

else
	echo "Precipitation NetCDF data seems there, avoid pr_prepare.sh"
fi

#check cleaning
rm -f $TEMPDIR/*.nc
rmdir $TEMPDIR


