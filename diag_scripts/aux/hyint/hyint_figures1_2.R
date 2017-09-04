######################################################
#-----------Plotting froutine for HyInt--------------#
#-------------E. Arnone (June 2017)------------------#
######################################################

#DECLARING THE FUNCTION: EXECUTION IS AT THE BOTTOM OF THE SCRIPT
hyint.figures<-function(exp,year1,year2,dataset_ref,year1_ref,year2_ref,season,rgrid,rlonlatplot,ryearplot,ryearplot_ref,
                        label,plot_type,plot_dir,work_dir,ref_dir,diag_script_cfg) {

diag_base = "HyInt"
var0 <- variables[1]
field_type0 <- field_types[1]

# load configuration files
source(diag_script_cfg)

# set main paths
work_dir_exp=file.path(work_dir,exp,paste0(year1,"_",year2),season)
plot_dir_exp=file.path(plot_dir,exp,paste0(year1,"_",year2),season)
dir.create(plot_dir_exp,recursive=T)

# check path for reference dataset
if (ref_dir!=work_dir) {
  ref_dir=file.path(ref_dir,diag_base)
} else {
  ref_dir=file.path(work_dir,dataset_ref,paste0(year1_ref,"_",year2_ref),season)
}

# define fieds to load/plot
fieldlist=c("int","int_norm","dsl","dsl_norm","hyint")
fieldlist_short=c("int_norm","dsl_norm","hyint")
sfieldlist_short=c("INT","DSL","HY-INT")


# define region to be plotted
lon_lim=rlonlatplot[1:2] 
lat_lim=rlonlatplot[3:4] 

# Loop over years defined in cfg_file

# Set useful parameters and arrays based on cfg_file
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


if (plot_type == 3) { # multiple fields/years in one figure
  # define figure name (one figure per field) 
  figname=paste(plot_dir_exp,"/","dsl-int-hyint_",exp,"_",rgrid,"_",year1,"_",year2,"_",
                season,"_multiyear_",label,"_map.",output_file_type,sep="")
  # choose output format for figure - by JvH
  if (tolower(output_file_type) == "png") {
      png(filename = figname, width=png_width, height=png_height)
  } else if (tolower(output_file_type) == "pdf") {
      pdf(file=figname,width=pdf_width,height=pdf_height,onefile=T)
  } else if (tolower(output_file_type) == "eps") {
      setEPS(width=pdf_width,height=pdf_height,onefile=T,paper="special")
      postscript(figname)
  }
  # panels layout
  par(mfrow=c(nyears,3),cex.main=1.3,cex.axis=1.2,cex.lab=1.2,mar=c(2,2,2,2),oma=c(1,1,1,1))
}

for (iyear in 1:nyears) {
  if (ryearplot_ref[1] == "EXP") {iyear_ref=iyear} else {iyear_ref<-match(ryearplot_ref,years_ref)}
  #-----------------Loading data-----------------------#
  #open experiment field
  for (field in fieldlist) {
        nomefile=paste0(work_dir_exp,"/Hyint_",exp,"_",rgrid,"_",year1,"_",year2,"_",season,".nc")
        field_exp=ncdf.opener(nomefile,field,"Lon","Lat",rotate="no")
        assign(paste(field,"_exp",sep=""),field_exp)
  }
  #open reference field
  for (field in fieldlist) {
     	nomefile=paste0(ref_dir,"/Hyint_",dataset_ref,"_",rgrid,"_",year1_ref,"_",year2_ref,"_",season,".nc")
     	field_ref=ncdf.opener(nomefile,field,"Lon","Lat",rotate="no")
     	assign(paste(field,"_ref",sep=""),field_ref)
  }

  #-----------------Producing figures------------------------#
  print(paste0(diag_base, ": plotting maps for year ",years[iyear]))

  #standard properties
  legend_distance=3
  info_exp=paste(exp,years[iyear],season)
  info_ref=paste(dataset_ref,years_ref[iyear_ref],season)

  if (plot_type == 2) { # multiple fields/quantities in one figure
    # define figure name (one figure per field) 
    figname=paste(plot_dir_exp,"/","dls-int-hyint_",exp,"_",rgrid,"_",year1,"_",year2,"_",
                  season,"_",years[iyear],"_",label,"_map.",output_file_type,sep="")
    # choose output format for figure - by JvH
    if (tolower(output_file_type) == "png") {
        png(filename = figname, width=png_width, height=png_height)
    } else if (tolower(output_file_type) == "pdf") {
        pdf(file=figname,width=pdf_width,height=pdf_height,onefile=T)
    } else if (tolower(output_file_type) == "eps") {
        setEPS(width=pdf_width,height=pdf_height,onefile=T,paper="special")
        postscript(figname)
    }
    # panels layout for plot_type=2
    par(mfrow=c(5,3),cex.main=1.3,cex.axis=1.2,cex.lab=1.2,mar=c(2,2,2,2),oma=c(1,1,1,1))
  }
 
  #loop on fields to assign useful parameters
  for (field in fieldlist) {
    ifield<-which(field == fieldlist)
    ifield3<-which(field == fieldlist_short) 
    #define field-dependent properties
    if (field == "dsl") {
      lev_field=seq(0,24,0.6); lev_diff=seq(-10,10,1)
      legend_unit="Annual mean DSL (days)"; title_name="Annual mean dry spell length:"
    } else if (field == "dsl_norm") {
      lev_field=seq(0.4,1.6,0.02); lev_diff=seq(-1.2,1.2,0.1)
      legend_unit="Norm. annual mean DSL"; title_name="Norm. annual mean dry spell length:"
    } else if (field == "int") {
      lev_field=seq(0,10,0.5); lev_diff=seq(-10,10,1)
      legend_unit="Annual mean INT (mm/day)"; title_name="Annual mean precipitation intensity:"
    } else if (field == "int_norm") {
      lev_field=seq(0.4,1.6,0.1); lev_diff=seq(-1.2,1.2,0.1)
      legend_unit="Norm. annual mean INT"; title_name="Norm. annual mean precipitation intensity:"
    } else if (field == "hyint") {
       lev_field=seq(0.4,1.6,0.1); lev_diff=seq(-1.2,1.2,0.1)
       legend_unit="HY-INT"; title_name="Hydroclimatic intensity:"
    }

    # get fields
    field_ref=get(paste(field,"_ref",sep=""))
    field_exp=get(paste(field,"_exp",sep=""))

    # select required year 
    field_ref=field_ref[,,iyear] 
    field_exp=field_exp[,,iyear_ref] 

    # define quantity-dependent properties
    tmp.colorbar<-c(F,T,T)
    tmp.palette<-palette1
    tmp.levels<-lev_field
    tmp.field<-field_exp
    if (plot_type==3) { 
      tmp.palette<-palette_giorgi2011 
      title_name<-c(sfieldlist_short[ifield3])
    }
    tmp.titles<-paste(title_name,c(info_exp,info_ref,"Difference"))
    
    if (plot_type == 1) {
      # define figure name (one figure per field) 
      figname=paste(plot_dir_exp,"/",field,"_",exp,"_",rgrid,"_",year1,"_",year2,"_",
                    season,"_",years[iyear],"_",label,"_map.",output_file_type,sep="") 
      # choose output format for figure - by JvH
      if (tolower(output_file_type) == "png") {
          png(filename = figname, width=png_width, height=png_height)
      } else if (tolower(output_file_type) == "pdf") {
          pdf(file=figname,width=pdf_width,height=pdf_height,onefile=T)
      } else if (tolower(output_file_type) == "eps") {
          setEPS(width=pdf_width,height=pdf_height,onefile=T,paper="special")
          postscript(figname)
      }
      # panels layout for plot_type=1
      par(mfrow=c(3,1),cex.main=2,cex.axis=1.5,cex.lab=1.5,mar=c(5,5,4,8),oma=c(1,1,1,1))
    }  
    # Loop through quantity (exp,ref,exp-ref) to be plotted 
    for (iquantity in 1:3) {
      if (iquantity == 2) {
        tmp.field<-field_ref
      }
      if (iquantity == 3) { 
        tmp.palette<-palette2 
        tmp.levels<-lev_diff
        tmp.field<-field_ref-field_exp
      }            

      # actual plotting
      if (!((plot_type==3)&(field=="dsl"|field=="int"))&
          !((plot_type==3)&(iquantity>1))) { # plot_type=3: skip dsl/int, keep only exp
      
        # set active panel
        if (plot_type == 2) { par(mfg=c(ifield,iquantity,5,3)) }
        if (plot_type == 3) { par(mfg=c(iyear,ifield3,nyears,3)) } # only dsl_norm, int_norm, hyint
        # contours
        filled.contour3(ics,ipsilon,tmp.field,xlab="Longitude",ylab="Latitude",
             main=tmp.titles[iquantity],levels=tmp.levels,color.palette=tmp.palette,
             ylim=lat_lim, xlim=lon_lim, axes=F)
        map("world",regions=".",interior=F,exact=F,boundary=T,add=T)
        box(col="grey60")
        # axis
        if (plot_type == 1) {
          axis(1,col="grey40",col_axis="grey20")
          axis(2,col="grey40",col_axis="grey20") 
        } else if (plot_type == 2) {
          if (iquantity == 1) { axis(2,col="grey40",col_axis="grey20") }
          if (field == "hyint") { axis(1,col="grey40",col_axis="grey20") }
        } else if (plot_type == 3) {
          if (iyear == nyears) { axis(1,col="grey40") }
          if (field == "int_norm") { axis(2,col="grey40") }
        }
        #colorbar
        if ((tmp.colorbar[iquantity]) & (plot_type == 1)) { 
           image.scale3(volcano,levels=tmp.levels,color.palette=tmp.palette,colorbar.label=legend_unit,
                        cex.colorbar=1.0,cex.label=1.0,colorbar.width=1,line.label=legend_distance,line.colorbar=1.0)
        }
      }
    }
    if (plot_type == 1) {
      print(figname)	
      dev.off()
    }    
  } # close loop on field 
  if (plot_type == 2) { 
    print(figname)
    dev.off()
  }
} # close loop on years
if (plot_type == 3) { 
  print(figname)
  dev.off()
}

} # close function

# REAL EXECUTION OF THE SCRIPT 
# read command line
args <- commandArgs(TRUE)

# number of required arguments from command line
name_args=c("exp","year1","year2","dataset_ref","year1_ref","year2_ref","season","rgrid","rlonlatplot","ryearplot", 
            "ryearplot_ref","label","plot_type","plot_dir","work_dir","ref_dir","diag_script_cfg","PROGDIR")
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
	hyint.figures(exp,year1,year2,dataset_ref,year1_ref,year2_ref,season,rgrid,rlonlatplot,ryearplot,ryearplot_ref,label,plot_type,plot_dir,work_dir,ref_dir,diag_script_cfg) 
    }
}

