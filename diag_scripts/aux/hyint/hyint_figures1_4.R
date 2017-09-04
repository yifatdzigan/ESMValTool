#####################################################
#-----------Plotting froutine for HyInt--------------#
#-------------E. Arnone (June 2017)------------------#
######################################################

# DECLARING THE FUNCTION: EXECUTION IS AT THE BOTTOM OF THE SCRIPT

# Figure functions
getname.figure<-function(splot_dir,svar,exp,rgrid,year1,year2,season,syears,sregion,label,map,output_file_type) {
  # Example: "int_EC-Earth_r320x160_1997_2010_ALL_2002_global_???_map.png"
  figname=paste0(splot_dir,"/",paste(svar,exp,rgrid,year1,year2,season,syears,sregion,map,sep="_"),".",output_file_type)
  if (!(label == "")&!(label == F)) { 
    figname=paste0(splot_dir,"/",paste(svar,exp,rgrid,year1,year2,season,syears,sregion,label,map,sep="_"),".",output_file_type)
  }
return(figname)
}

graphics.startup<-function(figname,output_file_type,diag_script_cfg) {
source(diag_script_cfg)
  # choose output format for figure - by JvH
  if (tolower(output_file_type) == "png") {
      png(filename = figname, width=png_width, height=png_height)
  } else if (tolower(output_file_type) == "pdf") {
      pdf(file=figname,width=pdf_width,height=pdf_height,onefile=T)
  } else if (tolower(output_file_type) == "eps") {
      setEPS(width=pdf_width,height=pdf_height,onefile=T,paper="special")
      postscript(figname)
  }
return()
}

graphics.close<-function(figname) {
  print(figname)
  dev.off()
return()
}

# MAIN FIGURE FUNCTION
hyint.figures<-function(exp,year1,year2,dataset_ref,year1_ref,year2_ref,season,plot_dir,work_dir,ref_dir,diag_script_cfg,iregion) {

diag_base = "HyInt"
var0 <- variables[1]
field_type0 <- field_types[1]

# load configuration files
source(diag_script_cfg)

# set main paths
work_dir_exp=file.path(work_dir,exp,paste0(year1,"_",year2),season)
plot_dir_exp=file.path(plot_dir,exp,paste0(year1,"_",year2),season)
dir.create(plot_dir_exp,recursive=T)

# check path to reference dataset
if (ref_dir!=work_dir) {
  ref_dir=file.path(ref_dir,diag_base)
} else {
  ref_dir=file.path(work_dir,dataset_ref,paste0(year1_ref,"_",year2_ref),season)
}

# Define regions to be used
nregions=length(selregions)

# Define fields to be used
if (plot_type == 3) { field_names=field_names[1:3] } # keep only int_norm, dsl_norm and hyint

# Define quantity (exp, ref, exp-ref) to be plotted depending on plot_type 
nquantity=c(3,3,1,1) # 3=exp/ref/exp-ref, 1=exp

# Years to be considered based on namelist and fg_file
years <- year1:year2
years_ref <- year1_ref:year2_ref
if (ryearplot[1] == "ALL") {
  years <- year1:year2
} else if (ryearplot[1] == "FIRST") {
  years <- year1
} else {
  years <- years[match(ryearplot,years)] ; years <- years[!is.na(years)] 
}
nyears <- length(years)
if (plot_type == 4) { nyears<-1 }# drop loop over years if working on timeseries


#-----------------Loading data-----------------------#
# open experiment field
for (field in field_names) {
  filename=paste0(work_dir_exp,"/Hyint_",exp,"_",rgrid,"_",year1,"_",year2,"_",season,".nc")
  field_exp=ncdf.opener(filename,field,"Lon","Lat",rotate="no")
  assign(paste(field,"_exp",sep=""),field_exp)        
} 
# open reference field
for (field in field_names) {
   filename=paste0(ref_dir,"/Hyint_",dataset_ref,"_",rgrid,"_",year1_ref,"_",year2_ref,"_",season,".nc")
   field_ref=ncdf.opener(filename,field,"Lon","Lat",rotate="no")
   assign(paste(field,"_ref",sep=""),field_ref)
}
# store size of time array
ntime_exp<-length(field_exp[1,1,])  
ntime_ref<-length(field_ref[1,1,])  

#-----------------Producing figures------------------------#

# LOOP over selected regions (only global by default)
print("starting figures")

#for (iregion in c(1:nregions)) {
  print(paste("region: ",region_names[iregion]))
  
  # Startup graphics for multiple years in one figure
  if (plot_type == 3) { 
    figname=getname.figure(plot_dir_exp,"dsl-int-hyint",exp,rgrid,year1,year2,season,"multiyear",region_tags[iregion],label,"map",output_file_type) 
    graphics.startup(figname,output_file_type,diag_script_cfg)
    par(mfrow=c(nyears,3),cex.main=1.3,cex.axis=1.2,cex.lab=1.2,mar=c(2,2,2,2),oma=c(1,1,1,1))
  }
  # Startup graphics for timeseries
  if (plot_type == 4) { 
    figname=getname.figure(plot_dir_exp,"dsl-int-hyint",exp,rgrid,year1,year2,season,"","regions",label,"timeseries",output_file_type) 
    graphics.startup(figname,output_file_type,diag_script_cfg)
    par(mfrow=c(3,2),cex.main=1.3,cex.axis=1.2,cex.lab=1.2,mar=c(5,5,5,5),oma=c(1,1,1,1))
  }

  # LOOP over years defined in namelist and cfg_file
  for (iyear in c(1:nyears)) {
    if (ryearplot_ref[1] == "EXP") {iyear_ref=iyear} else {iyear_ref<-match(ryearplot_ref,years_ref)}
    print(paste0(diag_base, ": plotting data for  ",region_names[iregion]," ",years[iyear]))
  
    #standard properties
    info_exp=paste(exp,years[iyear])#,season)
    info_ref=paste(dataset_ref,years_ref[iyear_ref])#,season)

    # Startup graphics for multiple fields/quantities in one figure 
    if (plot_type == 2) {
      figname=getname.figure(plot_dir_exp,"dsl-int-hyint",exp,rgrid,year1,year2,season,years[iyear],region_tags[iregion],label,"map",output_file_type)
      graphics.startup(figname,output_file_type,diag_script_cfg)
      par(mfrow=c(5,3),cex.main=1.3,cex.axis=1.2,cex.lab=1.2,mar=c(2,2,2,2),oma=c(1,1,1,1))
    }
 
    # LOOP over fields
    for (field in field_names) {
      ifield<-which(field == field_names)
 
      # get fields
      field_ref=get(paste(field,"_ref",sep=""))
      field_exp=get(paste(field,"_exp",sep=""))
 
      # Select data from fields: 
      # TIMESERIES: select required region and calculate timeseries     
      if (plot_type > 3 & iyear == 1) {
        tfield_exp<-matrix(nrow=nregions,ncol=ntime_exp)
        tfield_exp_sd<-matrix(nrow=nregions,ncol=ntime_exp)
        tfield_ref<-matrix(nrow=nregions,ncol=ntime_ref)    
        tfield_ref_sd<-matrix(nrow=nregions,ncol=ntime_ref)    
        print(str(tfield_exp)) 
        for (ireg in 1:nregions) {
          iselreg=selregions[ireg]
          # extract data and perform averages           
          tfield_exp[ireg,]<-calc.region.timeseries(ics,ipsilon,field_exp,regions[iselreg,],tfield_exp_sd)
          tfield_ref[ireg,]<-calc.region.timeseries(ics,ipsilon,field_ref,regions[iselreg,],tfield_ref_sd)
        }
      }

      # MAPS: select required year 
      field_ref<-field_ref[,,iyear]
      field_exp<-field_exp[,,iyear_ref] 
      tmp.field<-field_exp
 
      # define quantity-dependent properties (exp, ref, exp-ref)
      tmp.colorbar<-c(F,T,T)
      tmp.palette<-palette_giorgi2011
      tmp.levels<-seq(levels_m[ifield,1],levels_m[ifield,2],len=nlev)
      tmp.titles<-paste0(title_unit_m[ifield,2],": ",c(info_exp,info_ref,"Difference"))
      if (plot_type == 3) {
        tmp.palette<-palette_giorgi2011
        tmp.titles<-paste(title_unit_m[ifield,1],years[iyear])
      }
   
      # Startup graphics for individual fields in each figure
      if (plot_type == 1) {
        figname=getname.figure(plot_dir_exp,field,exp,rgrid,year1,year2,season,years[iyear],region_tags[iregion],label,"map",output_file_type)
        graphics.startup(figname,output_file_type,diag_script_cfg)
        par(mfrow=c(3,1),cex.main=2,cex.axis=1.5,cex.lab=1.5,mar=c(5,5,4,8),oma=c(1,1,1,1))
      }

      # LOOP through quantity (exp,ref,exp-ref difference) to be plotted 
      for (iquantity in c(1:nquantity[plot_type])) {
        print(paste(iregion,iyear,ifield,iquantity))
        if (iquantity == 2) { tmp.field<-field_ref }
        if (iquantity == 3) { tmp.palette<-palette2; tmp.levels<-seq(levels_m[ifield,3],levels_m[ifield,4],len=nlev); tmp.field<-field_exp-field_ref }            
        # actual plotting
        if (!((plot_type==3)&(iquantity>1))) { # keep only exp
       
          # set active panel
          if (plot_type == 2) { par(mfg=c(ifield,iquantity,5,3)) }
          if (plot_type == 3) { par(mfg=c(iyear,ifield,nyears,3)) } # only dsl_norm, int_norm, hyint
 
          if (plot_type < 4) {
            # contours
            filled.contour3(ics,ipsilon,tmp.field,xlab="Longitude",ylab="Latitude",
                 main=tmp.titles[iquantity],levels=tmp.levels,color.palette=tmp.palette,
                 xlim=c(regions[iregion,1],regions[iregion,2]), ylim=c(regions[iregion,3],regions[iregion,4]), axes=F)
            map("world",regions=".",interior=F,exact=F,boundary=T,add=T,col="white")
            # boxes
            box(col="grey60") 
            if (boxregion) {
              for (ireg in 2:nregions) {  
                 iselreg=selregions[ireg] 
                 rect(regions[iselreg,1],regions[iselreg,3],regions[iselreg,2],regions[iselreg,4],border="grey40",lwd=2)
                 text(regions[iselreg,1],regions[iselreg,3],paste0("         ",region_tags[iselreg]),col="grey40",pos=3,offset=0.5)
              }
            }
            # axis
            if (plot_type == 1) {
              axis(1,col="grey40",col_axis="grey20") 
              axis(2,col="grey40",col_axis="grey20") 
            } else if (plot_type == 2) {
              if (iquantity == 1) { axis(2,col="grey40",col_axis="grey20") }
              if (field == "dsl") { axis(1,col="grey40",col_axis="grey20") }
            } else if (plot_type == 3) {
              if (iyear == nyears) { axis(1,col="grey40") }
              if (field == "int_norm") { axis(2,col="grey40") }
            }
            #colorbar
            if ((tmp.colorbar[iquantity]) & (plot_type == 1)) { 
               image.scale3(volcano,levels=tmp.levels,color.palette=tmp.palette,colorbar.label=paste(title_unit_m[ifield,1],title_unit_m[ifield,4]),
                            cex.colorbar=1.0,cex.label=1.0,colorbar.width=1,line.label=legend_distance,line.colorbar=1.0)
            }
          } else if (plot_type == 4 & iyear == 1 & iquantity == 1) {
            # timseries
            times=as.numeric(year1)+1:ntime_exp-1
            plot(times,tfield_exp[1,],ylim=c(tmp.levels[1],tmp.levels[length(tmp.levels)]),
                 xlab="Year",ylab=paste(title_unit_m[ifield,2],title_unit_m[ifield,4]),main=title_unit_m[ifield,3]) 
             
            for (ireg in 1:nregions) { 
               iselreg=selregions[ireg] 
               lines(times,tfield_exp[ireg,],col=ireg)          
               points(times,tfield_exp[ireg,],col=ireg)
               text((times[1]+ireg/nregions*nyears*4),tmp.levels[1],region_tags[iselreg],col=ireg,offset=0.5)
            }
          }      
        }
      } # close loop over quantity
      if (plot_type == 1) { graphics.close(figname) }
    } # close loop over field 
    if (plot_type == 2) { graphics.close(figname) }
  } # close loop over years
  if (plot_type >= 3) { graphics.close(figname) }
#} # close loop over regions
} # close function


# REAL EXECUTION OF THE SCRIPT 
# read command line
args <- commandArgs(TRUE)

# number of required arguments from command line
name_args=c("exp","year1","year2","dataset_ref","year1_ref","year2_ref","season","plot_dir","work_dir","ref_dir","diag_script_cfg","iregion","PROGDIR")
req_args=length(name_args)

# print error message if uncorrect number of command 
if (length(args)!=0) {
    if (length(args)!=req_args) {
        print(paste("Not enough or too many arguments received: please specify the following",req_args,"arguments:"))
	print(name_args)
    } else {
# when the number of arguments is ok run the function()
	for (k in 1:req_args) {assign(name_args[k],args[k])}
	source(paste0(PROGDIR,"/script/basis_functions.R"))
	hyint.figures(exp,year1,year2,dataset_ref,year1_ref,year2_ref,season,plot_dir,work_dir,ref_dir,diag_script_cfg,iregion) 
    }
}

