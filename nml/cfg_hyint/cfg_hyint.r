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

# Temporarily copying here global values that are not read from namelist_hyint.xml -> need to check WHY.
write_plots=T
write_ncdf=T
run_regridding=T
run_diagnostic=T
force_calc=F
force_processing=F

# Pre-processing options
seasons <- c("ALL")   # seasons to be analysed: "ALL", "DJF", ...
rgrid   <-  "r320x160" # "r320x160"   # resolution of analysed data (NOTE: regridding is needed when comparing model/obs data to reference data)  
rlonlatdata <- c(0,360,-90,90) # region where the pre-processing and diagnostic calculation is to be performed. NOTE: lon(0/360) 
                           # (keep global coverage to allow re-use of same data set for plots over different regions)

# Diagnostic options
removedesert=T      # T to remove (flag as NA) grid points with mean annual pr < 0.5 mm/day (desertic areas, Giorgi et al. 2014)
norm_year_cutoff=2000  # use years < norm_year_cutoff to normalize dsl and int
external_norm=F       # a) F=use internal data to normalize b) list of names of normalization files (one per input data file or one for all) 
#c("/home/arnone/work/esmtest/work/HyInt/EC-Earth/1950_2005/ALL/Hyint_EC-Earth_historical_r8i1p1_r320x160_1950_2005_ALL.nc")

# Plotting options
plot_type <- 7  # 1) lon/lat maps per individual field/exp/single year, 2) lon/lat maps per individual field exp-ref-diff/single year, 
                # 3) lon/lat maps dsl-int-hyint/exp-ref-diff/single year,  4) lon/lat maps dsl-int-hyint/exp/multiyear,  
                # 5) timeseries over required individual region/exp, 6) timeseries over multiple regions/exp
                # 7) summary trend coefficients multiple regions  
ryearplot <- c(1997) #c(1989,1997,2002,2003) # c(1997,2002,2003) # years to be plotted for experiments (maps over individual years): options a) actual years, b) "FIRST" = first year in dataset or c) "ALL"  = all years in dataset. E.g., c(1998,2000,2005)   
ryearplot_ref <- c("EXP") # year to be plotted for reference dataset: options a) "EXP" == same as experiments, b) one year only, e.g. c(1998)    
force_ref <- T # set TRUE to force plotting of reference data as any other experiment
label= "" # user defined extra label for figure file name

# colorbar
add_colorbar=F # T to add colorbar
legend_distance=3

# timeseries options
add_sd=F       # T to add stdev range to timeserie
no_lines=T     # F to plot lines of timeseries over points
add_zeroline=T # T to plot a dashed line at y=0 
lm_trend=T     # T to calculate linear trend
add_trend=T    # T to add linera trend to plot
trend_years=c(1997,1999) # a) F=all; 
                        # b) c(year1,year2) to apply trend calculation and plotting only to a limited time interval (year1<=years<=year2) 
                        # c) c(year1,year2,year3,year4) to apply trend to two separate time intervals (year1<=years<=year2) and (year3<=years<=year4)
trend_years_only=F # T to limit timeseries plotting to trend_years[1:2] time interval
scale100years=T    # T to plot trends as 1/100 years

# region box matrix (predefined following Giorgi et al. 2011,2014): add here further regions and select those needed through iregion
region_names=c("World","World60","Tropics","South America","Africa","North America","India","Europe","East Asia","Australia")
region_tags=c("Globe","GL","TR","SA","AF","NA","IN","EU","EA","AU")
selregions=c(1:10) # Select one or more index values to define regions to be used. Default c(1) == global. 
boxregion=F  # T=plot region boxes over maps. This automatically works on global maps only.

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

# define fields for plotting
field_names=c("int_norm","dsl_norm","wsl_norm","hyint","int","dsl","wsl","pa_norm")
selfields=c(7,4,5,1,2,3) # c(1,2,3,4) # Select one or more fields to be plotted with the required order  

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

# define levels for contour/yrange for abs. values: (minlev,maxlev,minlev_diff,maxlev_diff) and nlev
nlev=24
levels_m=matrix(nrow=length(field_names),ncol=4)
levels_m[1,]=c(0.4,1.6,-1.2,1.2)
levels_m[2,]=c(0.4,1.6,-1.2,1.2)
levels_m[3,]=c(0.4,1.6,-1.2,1.2)
levels_m[4,]=c(0.4,1.6,-1.2,1.2)
levels_m[5,]=c(0,10,-10,10)
levels_m[6,]=c(0,24,-10,10)
levels_m[7,]=c(0,24,-10,10)
levels_m[8,]=c(0.4,1.6,-1.2,1.2)

# define levels for contour/yrange for trends (minlev,maxlev)
ntlev=24
tlevels_m=matrix(nrow=length(field_names),ncol=2)
tlevels_m[1,]=c(-0.05,0.2)
tlevels_m[2,]=c(-0.1,0.4)
tlevels_m[3,]=c(-0.1,0.4)
tlevels_m[4,]=c(0,0.4)
tlevels_m[5,]=c(0,1.2)
tlevels_m[6,]=c(-1,8)
tlevels_m[7,]=c(-1,8)
tlevels_m[8,]=c(-0.1,0.4)

# Specific settings for PNG output
png_width=720#960
png_height=720
png_units="px"
png_pointsize=12
png_bg="white"

# Specific settings for PDF and EPS output (in inches)
pdf_width=12
pdf_height=12

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

