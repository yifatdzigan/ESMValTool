#####################################################
#-----------Plotting froutine for HyInt--------------#
#-------------E. Arnone (June 2017)------------------#
######################################################

# DECLARING THE FUNCTION: EXECUTION IS AT THE BOTTOM OF THE SCRIPT

# Figure functions
getname.figure<-function(splot_dir,svar,exp,model_exp,model_ens,rgrid,year1,year2,season,syears,sregion,label,map,output_file_type) {
  # Example: "int_EC-Earth_r320x160_1997_2010_ALL_2002_global_???_map.png"
  figname=paste0(splot_dir,"/",paste(svar,exp,model_exp,model_ens,rgrid,year1,year2,season,syears,sregion,map,sep="_"),".",output_file_type)
  if (!(label == "")&!(label == F)) { 
    figname=paste0(splot_dir,"/",paste(svar,exp,model_exp,model_ens,rgrid,year1,year2,season,syears,sregion,label,map,sep="_"),".",output_file_type)
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
hyint.figures<-function(exp,model_exp,model_ens,year1,year2,dataset_ref,model_exp_ref,model_ens_ref,year1_ref,year2_ref,season,plot_dir,work_dir,ref_dir,diag_script_cfg,iregion) {

diag_base = "HyInt"


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
if (selfields[1]!=F) {
  field_names=field_names[selfields]
  levels_m=levels_m[selfields,]
  tlevels_m=tlevels_m[selfields,]
  title_unit_m=title_unit_m[selfields,]

}

# Define fields to be used
if (plot_type == 4) { field_names=field_names[1:3] } # keep only int_norm, dsl_norm and hyint

# Define quantity (exp, ref, exp-ref) to be plotted depending on plot_type 
nquantity=c(1,3,3,1,1,1,1) # 3=exp/ref/exp-ref, 1=exp

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
if (plot_type == 5) { nyears<-1 }    # drop loop over years if working on timeseries
if (plot_type == 7) { add_trend<-F } # do not plot trend line for plot 7

#-----------------Loading data-----------------------#
# open experiment field
for (field in field_names) {
#  filename=paste0(work_dir_exp,"/Hyint_",exp,"_",rgrid,"_",year1,"_",year2,"_",season,".nc")
  filename<-paste0(work_dir_exp,"/Hyint_",exp,"_",model_exp,"_",model_ens,"_",rgrid,"_",toString(year1),"_",toString(year2),"_",season,".nc")
  field_exp=ncdf.opener(filename,field,"Lon","Lat",rotate="no")
  assign(paste(field,"_exp",sep=""),field_exp)        
} 
# open reference field
for (field in field_names) {
#   filename=paste0(ref_dir,"/Hyint_",dataset_ref,"_",rgrid,"_",year1_ref,"_",year2_ref,"_",season,".nc")
   filename<-paste0(ref_dir,"/Hyint_",dataset_ref,"_",model_exp_ref,"_",model_ens_ref,"_",rgrid,"_",toString(year1_ref),"_",toString(year2_ref),"_",season,".nc")
   field_ref=ncdf.opener(filename,field,"Lon","Lat",rotate="no")
   assign(paste(field,"_ref",sep=""),field_ref)
}
# store size of time array
ntime_exp<-length(field_exp[1,1,])  
ntime_ref<-length(field_ref[1,1,])  

#-----------------Producing figures------------------------#

print(paste0(diag_base,": starting figures"))
# LOOP over selected regions (only global by default) NOTE: not manageble by R. Moving region loop to  hyint call.
#for (iregion in c(1:nregions)) {
  print(paste("region: ",region_names[iregion]))
  
  # Startup graphics for multiple years in one figure
  if (plot_type == 4) { 
    figname=getname.figure(plot_dir_exp,"dsl-int-hyint",exp,model_exp,model_ens,rgrid,year1,year2,season,"multiyear",region_tags[iregion],label,"map",output_file_type) 
    graphics.startup(figname,output_file_type,diag_script_cfg)
    par(mfrow=c(nyears,3),cex.main=1.3,cex.axis=1.2,cex.lab=1.2,mar=c(2,2,2,2),oma=c(1,1,1,1))
  }
  # Startup graphics for timeseries
  if (plot_type == 6) { 
    figname=getname.figure(plot_dir_exp,"dsl-int-hyint",exp,model_exp,model_ens,rgrid,year1,year2,season,"","regions",label,"timeseries",output_file_type) 
    graphics.startup(figname,output_file_type,diag_script_cfg)
    par(mfrow=c(3,2),cex.main=1.3,cex.axis=1.2,cex.lab=1.2,mar=c(5,5,5,5),oma=c(1,1,1,1))
  }
  # Startup graphics for bar plot of trend coefficients 
  if (plot_type == 7) {
    figname=getname.figure(plot_dir_exp,"dsl-int-hyint",exp,model_exp,model_ens,rgrid,year1,year2,season,"","regions",label,"trend_summary",output_file_type)
    graphics.startup(figname,output_file_type,diag_script_cfg)
    par(mfrow=c(3,2),cex.main=1.3,cex.axis=1.2,cex.lab=1.2,mar=c(8,8,2,2),oma=c(1,1,1,1))
  }

  # LOOP over years defined in namelist and cfg_file
  for (iyear in c(1:nyears)) {
    if (ryearplot_ref[1] == "EXP") {iyear_ref=iyear} else {iyear_ref<-match(ryearplot_ref,years_ref)}
    print(paste0(diag_base, ": plotting data for  ",region_names[iregion]," ",years[iyear]))
  
    #standard properties
    info_exp=paste(exp,years[iyear])#,season)
    info_ref=paste(dataset_ref,years_ref[iyear_ref])#,season)

    # Startup graphics for multiple fields/quantities in one figure 
    if (plot_type == 3) {
      figname=getname.figure(plot_dir_exp,"dsl-int-hyint",exp,model_exp,model_ens,rgrid,year1,year2,season,years[iyear],region_tags[iregion],label,"map",output_file_type)
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
      if (plot_type > 4 & iyear == 1) {
        tfield_exp<-matrix(nrow=nregions,ncol=ntime_exp)
        tfield_exp_sd<-matrix(nrow=nregions,ncol=ntime_exp)
        trend_exp<-matrix(nrow=nregions,ncol=4) # to store trends if required
        trend_exp_stat<-matrix(nrow=nregions,ncol=4)
        for (ireg in 1:nregions) {
          iselreg=selregions[ireg]
          # extract data and perform averages           
          tfield_exp[ireg,]<-calc.region.timeseries(ics,ipsilon,field_exp,regions[iselreg,])
          tfield_exp_sd[ireg,]<-calc.region.timeseries(ics,ipsilon,field_exp,regions[iselreg,],calc_sd=T)
          #print(str(tfield_exp_sd))
        }
      }

      # MAPS: select required year 
      field_ref<-field_ref[,,iyear]
      field_exp<-field_exp[,,iyear_ref] 
      tmp.field<-field_exp
 
      # define quantity-dependent properties (exp, ref, exp-ref)
      tmp.colorbar<-c(F,T,T)
      if (plot_type == 1) { tmp.colorbar<-T }
      tmp.palette<-palette_giorgi2011
      tmp.levels<-seq(levels_m[ifield,1],levels_m[ifield,2],len=nlev)
      tmp.titles<-paste0(title_unit_m[ifield,2],": ",c(info_exp,info_ref,"Difference"))
      if (plot_type == 4) { tmp.titles<-paste(title_unit_m[ifield,1],years[iyear]) }

      # Startup graphics for individual fields and multi quantities in each figure
      if (plot_type == 2) {
        figname=getname.figure(plot_dir_exp,field,exp,model_exp,model_ens,rgrid,year1,year2,season,years[iyear],region_tags[iregion],label,"comp_map",output_file_type)
        graphics.startup(figname,output_file_type,diag_script_cfg)
        par(mfrow=c(3,1),cex.main=2,cex.axis=1.5,cex.lab=1.5,mar=c(5,5,4,8),oma=c(1,1,1,1))
      }

      # --- MAPS ----
      # LOOP over quantity (exp,ref,exp-ref difference) to be plotted 
      for (iquantity in c(1:nquantity[plot_type])) {
        print(paste(iregion,iyear,ifield,iquantity))
        if (iquantity == 2) { tmp.field<-field_ref }
        if (iquantity == 3) { tmp.palette<-palette2; tmp.levels<-seq(levels_m[ifield,3],levels_m[ifield,4],len=nlev); tmp.field<-field_exp-field_ref }            

        # Startup graphics for individual field in each figure
        if (plot_type == 1) {
          figname=getname.figure(plot_dir_exp,field,exp,model_exp,model_ens,rgrid,year1,year2,season,years[iyear],region_tags[iregion],label,"map",output_file_type)
          graphics.startup(figname,output_file_type,diag_script_cfg)
          par(cex.main=2,cex.axis=1.5,cex.lab=1.5,mar=c(5,5,4,8),oma=c(1,1,1,1))
        }

        # set active panel
        if (plot_type == 3) { par(mfg=c(ifield,iquantity,5,3)) }
        if (plot_type == 4) { par(mfg=c(iyear,ifield,nyears,3)) } # only dsl_norm, int_norm, hyint 

        if (plot_type < 5) {
          # contours
          filled.contour3(ics,ipsilon,tmp.field,xlab="Longitude",ylab="Latitude",
               main=tmp.titles[iquantity],levels=tmp.levels,color.palette=tmp.palette,
               xlim=c(regions[iregion,1],regions[iregion,2]), ylim=c(regions[iregion,3],regions[iregion,4]), axes=F)
          map("world",regions=".",interior=F,exact=F,boundary=T,add=T,col="white",lwd=1.5)
          # boxes
          box(col="grey60") 
          if (boxregion) {
            for (ireg in 2:length(selregions)) {  
               iselreg=selregions[ireg] 
               rect(regions[iselreg,1],regions[iselreg,3],regions[iselreg,2],regions[iselreg,4],border="grey40",lwd=2)
               text(regions[iselreg,1],regions[iselreg,3],paste0("         ",region_tags[iselreg]),col="grey40",pos=3,offset=0.5)
            }
          }
          # axis
          if (plot_type <= 2) {
            axis(1,col="grey40",col_axis="grey20") 
            axis(2,col="grey40",col_axis="grey20") 
          } else if (plot_type == 3) {
            if (iquantity == 1) { axis(2,col="grey40",col_axis="grey20") }
            if (field == "dsl") { axis(1,col="grey40",col_axis="grey20") }
          } else if (plot_type == 4) {
            if (iyear == nyears) { axis(1,col="grey40") }
            if (field == "int_norm") { axis(2,col="grey40") }
          }
          #colorbar
          if ((tmp.colorbar[iquantity]) & (plot_type <= 2) & add_colorbar) { 
           image.scale3(volcano,levels=tmp.levels,color.palette=tmp.palette,colorbar.label=paste(title_unit_m[ifield,1],title_unit_m[ifield,4]),
                          cex.colorbar=1.0,cex.label=1.0,colorbar.width=1,line.label=legend_distance,line.colorbar=1.0)
          }
        }
      } # close loop over quantity
      if (plot_type <= 2) { graphics.close(figname) }
   
      # ---- TIMESERIES ----
      if (plot_type >= 5 & iyear == 1) {
        # setup time array 
        times=as.numeric(year1)+1:ntime_exp-1
        rettimes = 1:length(times)
        print(rettimes)
        if (trend_years[1] != F) { # apply trend to limited time interval if required
          rettimes = which((times >= trend_years[1]) & times <= trend_years[2])
          if (length(trend_years) == 4) { # apply trend also to second time interval if required
            rettimes2 = which((times >= trend_years[3]) & times <= trend_years[4])
          } 
        }
        xlim=c(min(times),max(times))
        if (trend_years_only&(trend_years[1] != F)) { xlim=trend_years[1:2] }
 
        # Startup graphics for one timeseries in one figure 
        if (plot_type == 5) {
           figname=getname.figure(plot_dir_exp,field,exp,rgrid,year1,year2,season,"",
                   region_tags[iregion],label,"timeseries_single",output_file_type)
           graphics.startup(figname,output_file_type,diag_script_cfg)
           par(cex.main=1.3,cex.axis=1.2,cex.lab=1.2,mar=c(4,4,2,2),oma=c(1,1,1,1))
        }

        # Actual plotting
        if ((plot_type == 5)|(plot_type == 6)) { # base plot
         plot(times,tfield_exp[1,],ylim=c(tmp.levels[1],tmp.levels[length(tmp.levels)]),xlim=xlim,
               xlab="Year",ylab=paste(title_unit_m[ifield,2],title_unit_m[ifield,4]),main=title_unit_m[ifield,3]) 
        }
    
        # LOOP over regions to plot timeseries and calculate/plot trends as required 
        for (ireg in 1:nregions) { 
          iselreg=selregions[ireg] 
          if ((plot_type == 5)|(plot_type == 6)) {
            if (!no_lines) { lines(times,tfield_exp[ireg,],col=ireg) }          
            points(times,tfield_exp[ireg,],col=ireg)
            text((xlim[1]+(xlim[2]-xlim[1])*ireg/nregions)
                 ,tmp.levels[1],region_tags[iselreg],col=ireg,offset=0.5)
            if (add_sd) {
              lines(times,tfield_exp[ireg,]+tfield_exp_sd[ireg,],lty=3,col=ireg)
              lines(times,tfield_exp[ireg,]-tfield_exp_sd[ireg,],lty=3,col=ireg)       
            }
          }
          if (lm_trend) { # linear regression model 
            lm_fit<-lm(tfield_exp[ireg,rettimes] ~ times[rettimes])
            lm_sum<-summary(lm_fit)
            trend_exp[ireg,1:2]=lm_fit$coefficients # store trend coefficients (intercept and linear coef.) 
            trend_exp_stat[ireg,]=lm_sum$coefficients[2,] # store trend coef., standard error, t value, Pr(>|t|) 
            print("-----------------------------------------------------")
            print(paste(field,region_names[iselreg]))
            print(lm_sum$coefficients[2,])
            if (add_trend) { lines(times[rettimes],predict(lm_fit),col=ireg,lwd=2) } 
            if (length(trend_years) == 4) { # apply trend also to second time interval if required
              lm_fit2<-lm(tfield_exp[ireg,rettimes2] ~ times[rettimes2])
              trend_exp[ireg,3:4]=lm_fit2$coefficients # store 2nd interval trend coefficients
              if (add_trend) { lines(times[rettimes2],predict(lm_fit2),col=ireg,lwd=2) } 
            }
          } 
        }
        if (plot_type == 5) { graphics.close(figname) }
        if (plot_type == 7) { # plot trend coefficients for different regions, one panel per field
          if (trend_years[1]!=F) { xlim=trend_years[1:2] }
          # scale to 100 years          
          trend_exp=trend_exp*100                   # trend coefficients 
          trend_exp_stat[,2]=trend_exp_stat[,2]*100 # standard error
          #ylim=c(min(trend_exp[,2]-trend_exp_stat[,2]),max(trend_exp[,2]+trend_exp_stat[,2])) 
          ylim=tlevels_m[ifield,]
          xregions=1:nregions
          plot(xregions,trend_exp[,2],type="n",pch=22,axes=F,xlab="regions",ylab=paste0("Avg trend (1/100 years)"),
                  ylim=ylim, main=(paste0(title_unit_m[ifield,1]," trend (",xlim[1],"-",xlim[2],")")))          
          box()          
          # add errorbar (standard error) 
          arrows(xregions, trend_exp[,2]-trend_exp_stat[,2], xregions, trend_exp[,2]+trend_exp_stat[,2], length=0.05, angle=90, code=3)
          points(xregions, trend_exp[,2], pch=22, col="grey40", bg="white",cex=2)
          # add filled points for significant (95% level)
          retsig90=which(trend_exp_stat[,4]<0.1)
          if (!is.na(retsig90[1])) { points(xregions[retsig90], trend_exp[retsig90,2], pch=22, col="grey40", bg="grey40",cex=2) }
          retsig95=which(trend_exp_stat[,4]<0.05)
          if (!is.na(retsig95[1])) { points(xregions[retsig95], trend_exp[retsig95,2], pch=22, col="dodgerblue3", bg="dodgerblue3",cex=2) }
          axis(1,labels=region_tags[selregions],at=xregions)
          axis(2)                  
       } 
      }
    } # close loop over field 
    if (plot_type == 3) { graphics.close(figname) }
  } # close loop over years
  if ((plot_type == 4)|(plot_type == 6)|(plot_type == 7)) { graphics.close(figname) }
#} # close loop over regions
} # close function


# REAL EXECUTION OF THE SCRIPT 
# read command line
args <- commandArgs(TRUE)

# number of required arguments from command line
name_args=c("exp","model_exp","model_ens","year1","year2","dataset_ref","model_exp_ref","model_ens_ref","year1_ref","year2_ref","season","plot_dir","work_dir","ref_dir","diag_script_cfg","iregion","PROGDIR")
req_args=length(name_args)

# print error message if uncorrect number of command 
if (length(args)!=0) {
    if (length(args)!=req_args) {
        print(paste("Not enough or too many arguments received: please specify the following",req_args,"arguments:"))
	print(name_args)
    } else {
# when the number of arguments is ok run the function()
	for (k in 1:req_args) {assign(name_args[k],args[k])}
	source(paste0(PROGDIR,"/script/hyint_functions.R"))
	hyint.figures(exp,model_exp,model_ens,year1,year2,dataset_ref,model_exp_ref,model_ens_ref,year1_ref,year2_ref,season,plot_dir,work_dir,ref_dir,diag_script_cfg,iregion) 
    }
}

