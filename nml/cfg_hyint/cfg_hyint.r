#####################################################################
#
#  HyInt configuration file
#
# About: configuration file for ESMValTool HyInt namelist.
#        General configuration for running the HyInt diagnostic 
#        (models and time period are defined in the HyInt namelist).
#        In order to optimize recursive analysis, users can spearately select: 
#        a) grid and region of HyInt pre-processing and dignostic calculation 
#        b) region and years to be plotted
#
#####################################################################

# Replace here global values from namelist_hyint.xml
write_ncdf=T
run_regridding=F
force_processing=F
run_diagnostic=F
force_calc=F
etccdi_preproc=F
run_timeseries=F
write_plots=T

# Pre-processing options
seasons <- c("ALL")   # seasons to be analysed: "ALL", "DJF", ...

rgrid   <- F #"r320x160"  # set FALSE or desired regridding resolution (e.g., comparing different datasets)
#rlonlatdata <- c(0,20,40,50)
rlonlatdata <- c(0,360,-90,90) # region where the pre-processing and diagnostic calculation is to be performed. NOTE: lon(0/360) 
                           # (keep global coverage to allow re-use of same data set for plots over different regions)
grid_file <- "./HyInt_r320x160.grd"
topography_file <- "./topo_r320x160.nc"
topography_highres <- "/home/arnone/work/data/Elevation/GMTED2010_15n030_0125deg.nc"

# Diagnostic options
norm_years=c(1976,2005)  # reference normalization period
external_norm="HIST"       # a) F=use internal data to normalize over the norm_years period
                      # b) list of names of normalization files (one per input data file or one for all)
                      # c) "HIST" to automatically generate the name of the historical experiment associated with the model name 
#c("/home/arnone/work/esmtest/work/HyInt/EC-Earth/1976_2005/ALL/HyInt_EC-Earth_historical_r8i1p1_r320x160_1976_2005_ALL.nc")

external_r95=external_norm    # a) F=use internal data to evaluate r95 threshold over the norm_years period  
                              # b) list of names of files (one per input data file or one for all) 
                              # c) "HIST" to automatically generate the name of the historical experiment associated with the model name
#c("/home/arnone/work/esmtest/work/HyInt/EC-Earth/1976_2005/ALL/HyInt_EC-Earth_historical_r8i1p1_r320x160_1976_2005_ALL.nc")

# Plotting options
plot_type <- 13  # 1) lon/lat maps per individual field/exp/single year, 2) lon/lat maps per individual field exp-ref-diff/single year, 
                # 3) lon/lat maps multi-field/exp-ref-diff/single year,  4) lon/lat maps multifield/exp/multiyear,  
                # 11) timeseries over required individual region/exp, 12) timeseries over multiple regions/exp
                # 13) timeseries with multiple models, 14) summary trend coefficients multiple regions  
                #  15) summary trend coefficients multiple models  
ryearplot <- 1999 # c(1997,2002,2003) # years to be plotted for experiments (maps over individual years): 
                  # a) actual years, b) "FIRST" = first year in dataset or c) "ALL"  = all years in dataset. E.g., c(1998,2000,2005)   
rmultiyear_mean <- T # T to plot multiyear mean (this override ryearplot)
ryearplot_ref <- c("EXP") # year to be plotted for reference dataset: options a) "EXP" == same as experiments, b) one year only, e.g. c(1998)    
force_ref <- F # set TRUE to force plotting of reference data as any other experiment
label= "demo" # user defined extra label for figure file name
map_continents <- -2 # thickness of continents: positive values in white, negative values in gray
map_continents_regions <- T # T to plot also regional boundaries
# colorbar
add_colorbar=F # T to add colorbar
legend_distance=3

# timeseries options
weight_tseries=T  # T to calculate area weighted time averages
trend_years=c(2006,2100,1976,2005) # c(1996,1999) # a) F=all; 
#trend_years=c(2090,2100) # c(1996,1999) # a) F=all; 
#trend_years=F # c(1996,1999) # a) F=all; 
                         # b) c(year1,year2) to apply trend calculation and plotting only to a limited time interval (year1<=years<=year2) 
                         # c) c(year1,year2,year3,year4) to apply trend to two separate time intervals (year1<=years<=year2) and (year3<=years<=year4)
removedesert=F      # T to remove (flag as NA) grid points with mean annual pr < 0.5 mm/day (desertic areas, Giorgi et al. 2014)
maskSeaLand=F # T to mask depending on seaLandElevation threshold
seaLandElevation=0 # a) 0 land; b) positive value: land above given elevation;
                   # c) negative value: ocean below given depth. The topography/bathymetry file is generated with cdo from ETOPO data. 
reverse_maskSeaLand=F # T to reject what selected, F to keep what selected
highreselevation=F#500 # a) F: neglect; b) value: threshold of minimum elevation to be overplotted with contour lines of elevation
highreselevation_only=F # T to plot only high resolution elevation contours
oplot_grid=F # T to plot grid points over maps

# timeseries and trend plotting options
lm_trend=T         # T to calculate linear trend
add_trend=T        # T to add linear trend to plot
add_trend_sd=F     # T to add stdev range to timeseries
add_trend_sd_shade=F   # T to add shade of stdev range to timeseries 
add_tseries_lines=T    # T to plot lines of timeseries over points
add_zeroline=T         # T to plot a dashed line at y=0 
trend_years_only=F # T to limit timeseries plotting to trend_years[1:2] time interval
scale100years=F    # T to plot trends as 1/100 years
scalepercent=F     # T to plot trends as percent change (this is not applied to HY-INT)
add_legend=4       # a) F=no legend; b) n>0 list disposed in n column; c) <0 horizontal legend 
xy_legend=c(0.03,0.4) # position of legend in fraction of plotting panel 
tag_legend=c(T,F,F) # 1=model name, 2=model experiment, 3=model ensemble (select one or more)

# region box matrix (predefined following Giorgi et al. 2011,2014): add here further regions and select those needed through iregion
region_names=c("World","World60","Tropics","South-America","Africa","North-America","India","Europe","East-Asia","Australia")
region_codes=c("Globe","GL","TR","SA","AF","NA","IN","EU","EA","AU")
selregions=c(1:10) # Select one or more index values to define regions to be used. Default c(1) == global. 
boxregion=0  #-2 # !=0 plot region boxes over maps with thickness = abs(boxregion) and white (>0) or grey (<0).  This automatically works on global maps only.

regions=matrix(nrow=length(region_names),ncol=4)
# c(lon1,lon2,lat1,lat2) NOTE: lon(-180/180)
regions[1,]=c(-180,180,-90,90) # First row = global
regions[2,]=c(-180,180,-60,60) # GL |lat|<60
regions[3,]=c(-180,180,-30,30)
regions[4,]=c(-90,-30,-60,10)
regions[5,]=c(-20,60,-40,35)
regions[6,]=c(-140,-60,10,60)
regions[7,]=c(60,100,0,35)
regions[8,]=c(-10,30,35,70)
regions[9,]=c(100,150,20,50)
regions[10,]=c(110,160,-40,-10)

# mountain regions
mountain_region_names=c("World","Tibetan-Plateau","Loess-Plateau","Yunnan-Guizhou-Plateau","Alps","US-Rockies",
                       "Appalachian-Mountains","Andes","Mongolian-Plateau","North-Tibetan-Plateau",
                       "South-Tibetan-Plateau")
mountain_region_codes=c("Globe","TP","LO","YG","AL","RO","AP","AN","MO","NT","ST")
mountain_regions=matrix(nrow=length(mountain_region_names),ncol=4)
mountain_regions[1,]=c(-180,180,-90,90) # First row = global
mountain_regions[2,]=c(70,106,25,40)
mountain_regions[3,]=c(100,116,33,43)
mountain_regions[4,]=c(96,110,20,29)
mountain_regions[5,]=c(4,19,43,49)
mountain_regions[6,]=c(-125,-95,34,49)
mountain_regions[7,]=c(-83,-68,34,46)
mountain_regions[8,]=c(-80,-62,-45,-10)
mountain_regions[9,]=c(88,120,42,52)
# From Wang et al. 2014 Cli Dyn
mountain_regions[10,]=c(92.43,102.03,32.20,38.80)
mountain_regions[11,]=c(80.08,102.97,27.73,33.58)

# define fields for timeseries calculation and plotting
hyint_list=c("int_norm","dsl_norm","wsl_norm","hyint","int","dsl","wsl","pa_norm","r95_norm")
etccdi_yr_list=c("altcddETCCDI","altcsdiETCCDI","altcwdETCCDI","altwsdiETCCDI","cddETCCDI",
              "csdiETCCDI","cwdETCCDI","dtrETCCDI","fdETCCDI","gslETCCDI","idETCCDI","prcptotETCCDI",
              "r10mmETCCDI","r1mmETCCDI","r20mmETCCDI","r95pETCCDI","r99pETCCDI","rx1dayETCCDI",
              "rx5dayETCCDI","sdiiETCCDI","suETCCDI","tn10pETCCDI","tn90pETCCDI","tnnETCCDI",
              "tnxETCCDI","trETCCDI","tx10pETCCDI","tx90pETCCDI","txnETCCDI","txxETCCDI","wsdiETCCDI")
field_names=c(hyint_list,etccdi_yr_list)
selfields=c(8,4,9,1,2,3) # c(1,2,3,4) # Select one or more fields to be plotted with the required order  
#selfields=c(9,21,12,16,20,31)+9 # c(1,2,3,4) # Select one or more fields to be plotted with the required order  
#selfields=c(5) # c(1,2,3,4) # Select one or more fields to be plotted with the required order  

# define titles and units
title_unit_m=matrix(nrow=length(field_names),ncol=4)
title_unit_m[1,]=c("SDII","Norm. annual mean INT","Norm. annual mean precipitation intensity","")
title_unit_m[2,]=c("DSL","Norm. annual mean DSL","Norm. annual mean dry spell length","")
title_unit_m[3,]=c("WSL","Norm. annual mean WSL","Norm. annual mean wet spell length","")
title_unit_m[4,]=c("HY-INT","HY-INT","Hydroclimatic intensity","")
title_unit_m[5,]=c("ABS_INT","Annual mean INT","Annual mean precipitation intensity","(mm/day)")
title_unit_m[6,]=c("ABS_DSL","Annual mean DSL","Annual mean dry spell length","(days)")
title_unit_m[7,]=c("ABS_WSL","Annual mean WSL","Annual mean wet spell length","(days)")
title_unit_m[8,]=c("PA","Normalized precipitation area","Norm. precipitation area","")
title_unit_m[9,]=c("R95","Norm. heavy precipitation index","Norm. % of total precip. above 95% percentile of reference distribution","")

# define levels for contour/yrange for abs. values: (minlev,maxlev,minlev_diff,maxlev_diff) and nlev
nlev=24
levels_m=matrix(nrow=length(field_names),ncol=4)
levels_m[1,]=c(0.8,1.4,-1.2,1.2)
levels_m[2,]=c(0.8,1.4,-1.2,1.2)
levels_m[3,]=c(0.8,1.4,-1.2,1.2)
levels_m[4,]=c(0.8,1.4,-1.2,1.2)
levels_m[5,]=c(0,10,-10,10)
levels_m[6,]=c(0,24,-10,10)
levels_m[7,]=c(0,24,-10,10)
levels_m[8,]=c(0.4,1.4,-1.2,1.2)
levels_m[9,]=c(0.8,1.4,-2,2)

if (F) {
levels_m[1,]=c(0.9,1.1,-1.2,1.2)
levels_m[2,]=c(0.9,1.1,-1.2,1.2)
levels_m[3,]=c(0.9,1.1,-1.2,1.2)
levels_m[4,]=c(0.9,1.1,-1.2,1.2)
levels_m[5,]=c(0,10,-10,10)
levels_m[6,]=c(0,24,-10,10)
levels_m[7,]=c(0,24,-10,10)
levels_m[8,]=c(0.9,1.1,-1.2,1.2)
levels_m[9,]=c(0.8,1.4,-2,2)
}

# define levels for contour/yrange for trends (minlev,maxlev)
ntlev=24
tlevels_m=matrix(nrow=length(field_names),ncol=2)
tlevels_m[1,]=c(-0.05,0.2)
tlevels_m[2,]=c(-0.1,0.4)
tlevels_m[3,]=c(-0.2,0.05)
tlevels_m[4,]=c(0,0.4)
tlevels_m[5,]=c(0,1.2)
tlevels_m[6,]=c(-1,8)
tlevels_m[7,]=c(-1,8)
tlevels_m[8,]=c(-0.3,0.15)
tlevels_m[9,]=c(0,0.6)

# define levels for contour/yrange for trends and multi-models
ntlev=24
tlevels_m=matrix(nrow=length(field_names),ncol=2)
tlevels_m[1,]=c(-0.05,0.3)
tlevels_m[2,]=c(-0.2,0.3)
tlevels_m[3,]=c(-0.2,0.3)
tlevels_m[4,]=c(0,0.5)
tlevels_m[5,]=c(0,1.2)
tlevels_m[6,]=c(-1,8)
tlevels_m[7,]=c(-1,8)
tlevels_m[8,]=c(-0.3,0.5)
tlevels_m[9,]=c(-0.2,0.6)


# define levels for mountain regions
ntlev=24
mountain_tlevels_m=matrix(nrow=length(field_names),ncol=2)
mountain_tlevels_m[1,]=c(-0.1,0.3)
mountain_tlevels_m[2,]=c(-0.3,0.3)
mountain_tlevels_m[3,]=c(-0.2,0.1)
mountain_tlevels_m[4,]=c(-0.2,0.4)
mountain_tlevels_m[5,]=c(0,1.2)
mountain_tlevels_m[6,]=c(-1,8)
mountain_tlevels_m[7,]=c(-1,8)
mountain_tlevels_m[8,]=c(-0.2,0.3)
mountain_tlevels_m[9,]=c(0,1.2)

# regions=mountain_regions
# region_names=mountain_region_names
# region_codes=mountain_region_codes
# tlevels_m=mountain_tlevels_m

# Specific settings for PNG output
png_height=720
png_width=720
#png_width=960
png_units="px"
png_pointsize=12
png_bg="white"

# Specific settings for PDF and EPS output (in inches)
pdf_width=12
pdf_height=12

# Specific settings for x11 output (in inches)
x11_width=7
x11_height=8

# color palette to be used
# palette0 is taken from tim.colors of field to avoid library dependencies...
palette0=colorRampPalette(c("#00008F", "#00009F", "#0000AF", "#0000BF", "#0000CF",
        "#0000DF", "#0000EF", "#0000FF", "#0010FF", "#0020FF",
        "#0030FF", "#0040FF", "#0050FF", "#0060FF", "#0070FF",
        "#0080FF", "#008FFF", "#009FFF", "#00AFFF", "#00BFFF",
        "#00CFFF", "#00DFFF", "#00EFFF", "#00FFFF", "#10FFEF",
        "#20FFDF", "#30FFCF", "#40FFBF", "#50FFAF", "#60FF9F",
        "#70FF8F", "#80FF80", "#8FFF70", "#9FFF60", "#AFFF50",
        "#BFFF40", "#CFFF30", "#DFFF20", "#EFFF10", "#FFFF00",
        "#FFEF00", "#FFDF00", "#FFCF00", "#FFBF00", "#FFAF00",
        "#FF9F00", "#FF8F00", "#FF8000", "#FF7000", "#FF6000",
        "#FF5000", "#FF4000", "#FF3000", "#FF2000", "#FF1000",
        "#FF0000", "#EF0000", "#DF0000", "#CF0000", "#BF0000",
        "#AF0000", "#9F0000", "#8F0000", "#800000"))
palette1=colorRampPalette(c("white","orange","darkred"))
palette2=colorRampPalette(c("blue","white","red"))
palette3=colorRampPalette(c("darkblue","blue","dodgerblue","white","orange","red","darkred"))
palette_giorgi2011=colorRampPalette(c("white","khaki1","darkseagreen2","mediumseagreen","lightskyblue1",                
                      "lightskyblue","deepskyblue2","dodgerblue2","dodgerblue3","royalblue4"))

