; #############################################################################
; carbon_cycle/main.ncl
; #############################################################################
; DIAGNOSTIC SCRIPT FOR ERRORBAR AND SEASONAL CYCLE PLOTS
; Author: Alessandro Anav (University of Exeter, UK)
; EMBRACE project
; #############################################################################
;
; Description
;     Calculates temporal and spatial averages and plots the variable as
;     error-bar and seasonal cycle plots.
;
; Required recipe attributes:
;     region: the region to be averaged.
;     legend_outside: plot legend in a separate page (not for errorbar plot).
;     seasonal_cycle_plot: draw seasonal cycle plot [False/True].
;     errorbar_plot: draw errorbar plot [False/True].
;     mean_IAV_plot: draw Mean (x-axis), IAV (y-axis) plot [False/True].
;
; Optional recipe attributes:
;     sort: sort dataset in alphabetical order.
;     anav_month : Conversion of y-axis to PgC/month instead of /year,
;         following Anav2013 fig 7, 9 (cycle plot).
;     evolution_plot: time evolution of a variable comparing obs to
;         multi-dataset mean; requires ref_dataset in recipe and at least one
;         dataset and one observation.
;     fignum: Reference to figure in Anav paper for evolution plot. "1 top"
;         as default.
;     evolution_plot_ref_dataset: reference dataset for evolution_plot.
;     evolution_plot_anomaly: makes evolution_plot an anomaly plot.
;     evolution_plot_ignore: Datasets to ignore, obs are excluded
;         automatically.
;     evolution_plot_volcanoes: Turns on/off lines of volcano eruptions.
;     evolution_plot_color: Hue of the contours; default: red = 0.
;     dst_grid: Destination grid for regridding
;
;     For external dataset input:
;     diag_script_info@obsname : Name of ext dataset to read in
;     diag_script_info@ref_varname: Varname in attributes of ext file
;     diag_script_info@obsfile : Filename of external obs to read in
;
; Caveats:
;     Regridding is not required since spatial averages are calculated for all
;     plots. Performance metrics calculated with perfmetrics_main could be
;     inconsistent with the plots produced by this script, since a consistent
;     missing value mask is not applied here. However, for variable such NBP,
;     GPP, LAI, FGCO2 for which this script is designed, there should be no
;     inconsistencies as the missing value mask is similar for all datasets
;     and observations and coincides with the land-sea mask.
;     Modifies input_file_info@dataset and input_file_info@project.
;
; Modification history:
;   * 20180816_A-schl_ma: continued porting to v2.0
;   * 20180619_A-wenz_sa: adopted script to v2
;   * 20170330_A-gier_be: added external data-read in (e.g. GCP)
;   * 20170316_A-gier_be: added cdo regridding, landmask for CRU obs
;   * 20170308_A-gier_be: added "evolution_plot"
;   * 20151130_A-laue_ax: corrected passing of file type from namelist to
;                         plotting functions; moved call to write_references
;                         to beginning of code
;   * 20151105_A-righ_ma: graphic part moved to external plot_scripts
;   * 20151030_A-righ_ma: regridding not working on ocean grids, removed since
;                         it is not necessary for these diagnostics
;   * 20151029_A-righ_ma: replacing area functions with ESMValTool functions
;   * 20151021_A-righ_ma: pep8 and header standardization
;   * 201510??_A-wenz_sa: adapted to ESMValTool structure
;   * 201505??_A-anav_al: written
;
; #############################################################################

load "./interface_scripts/interface.ncl"

load "./diag_scripts/shared/latlon.ncl"
load "./diag_scripts/shared/scaling.ncl"
load "./diag_scripts/shared/statistics.ncl"
load "./diag_scripts/shared/regridding.ncl"
load "./diag_scripts/shared/set_operators.ncl"

load "./diag_scripts/shared/plot/scatterplot.ncl"
load "./diag_scripts/shared/plot/style.ncl"
load "./diag_scripts/shared/plot/xy_line.ncl"

; load "./diag_scripts/shared/watermark.ncl"

begin

  enter_msg(diag_script, "")
  log_info("++++++++++++++++++++++++++++++++++++++++++")
  log_info(diag_script + " (var: " + variables(0) + ")")
  log_info("++++++++++++++++++++++++++++++++++++++++++")

  ; Variable
  var0 = variables(0)
  field_type0 = field_types(0)

  ; Check field type
  plot_fields = (/"T2Ms"/)
  ind_f = any(field_type0 .eq. plot_fields)
  if (all(ismissing(ind_f))) then
    error_msg("f", diag_script, "", "cannot use field " + field_type0)
  end if
  delete([/plot_fields, ind_f/])

  ; Write references (TODO)
  ; write_references(diag_script, \
  ;                  (/"A-anav_al"/), \
  ;                  (/"A-wenz_sa", "A-righ_ma", "A-schl_ma"/), \
  ;                  (/"D_anav13jclim"/), \
  ;                  (/""/), \
  ;                  (/"P_embrace"/))

end

begin

  ; ---------------------------------------------------------------------------
  ; Read recipe and config data
  ; ---------------------------------------------------------------------------

  ; Plot file type
  file_type = config_user_info@output_file_type
  if (ismissing(file_type)) then
    file_type = "ps"
  end if

  ; Output plot directory
  plot_dir = config_user_info@plot_dir
  system("mkdir -p " + plot_dir)

  ; Check required diag_script_info attributes
  req_atts = (/"region", "legend_outside", "seasonal_cycle_plot", \
              "errorbar_plot", "mean_IAV_plot"/)
  exit_if_missing_atts(diag_script_info, req_atts)

  ; Set region - supports 2D array for lat and strings
  if isstring(diag_script_info@region) then
    region = select_region(diag_script_info@region)
  else if dimsizes(diag_script_info@region) .eq. 2 then
    region = (/diag_script_info@region(0), diag_script_info@region(1), \
              0.0, 360.0/)
    region@name = flt2string(diag_script_info@region(0)) + "_-_" + \
      flt2string(diag_script_info@region(1))
    region@DM_tag = "DM_reg"
  else
    error_msg("f", diag_script, "", diag_script_info@region + \
              " is an invalid region type")
  end if
  end if

  ; Set time range
  start_year = min(stringtoint(input_file_info@start_year))
  end_year = max(stringtoint(input_file_info@end_year))
  all_years = ispan(start_year, end_year, 1)

  ; Only evolution plot utilizes time ranges greater then 1986-2005
  mean_minyear = 1986
  mean_maxyear = 2005
  minyear_ind = ind(ispan(start_year, end_year, 1) .eq. mean_minyear)
  maxyear_ind = ind(ispan(start_year, end_year, 1) .eq. mean_maxyear)

  ; Array sizes
  DIM_DAT = dimsizes(input_file_info@dataset)
  DIM_DAT_ORIG = DIM_DAT
  DIM_TIME = dimsizes(all_years)

  ; Global arrays for collecting all data
  all_data_yearly = new((/DIM_DAT, DIM_TIME, 2/), float)
  all_data_yearly!0 = "dataset"
  all_data_yearly!1 = "year"
  all_data_yearly!2 = "statistic"
  all_data_yearly&dataset = input_file_info@dataset
  all_data_yearly&year = all_years
  all_data_yearly&statistic = (/"mean", "stddev"/)

  all_data_monthly = new((/DIM_DAT, 12, 2/), float)
  all_data_monthly!0 = "dataset"
  all_data_monthly!1 = "month"
  all_data_monthly!2 = "statistic"
  all_data_monthly&dataset = input_file_info@dataset
  all_data_monthly&month = ispan(1, 12, 1)
  all_data_monthly&statistic = (/"mean", "stddev"/)

  ; ---------------------------------------------------------------------------
  ; Read and preprocess data
  ; ---------------------------------------------------------------------------

  ; Iterate over datasets and calculate averages
  do idat = 0, DIM_DAT - 1
    dataset_name = input_file_info@dataset(idat)
    log_debug("Processing " + dataset_name)

    ; Read data
    data_var := read_data(idat, var0, field_type0)

    ; Set type of area operation (flux vs. non-flux variables)
    if (data_var@units .eq. "kg m-2 s-1" .and. var0 .ne. "pr") then
      sp_opt = "sum"
    else
      sp_opt = "average"
    end if

    ; CRU is only land based - Need landmask and also cut off Antarctica
    if (isatt(diag_script_info, "ref_dataset") .and. \
        variable_info@reference_dataset .eq."CRU") then
      aux_vars = read_fx_data(idat, "sftlf")
      sftlf = where(aux_vars .gt. 1.0, 1.0, aux_vars)

      ; Mask Antarctica
      sftlf({:-60}, :) = sftlf@_FillValue

      ; Apply mask
      data_var = data_var * conform(data_var, sftlf, (/1, 2/))
      delete([/aux_vars, sftlf/])

      ; f = addfile("$NCARG_ROOT/lib/ncarg/data/cdf/landsea.nc", "r")
      ; a = f->LSMASK
      ; sftlf = byte2flt(landsea_mask(a, data_var&lat, data_var&lon))
      ; sftlf = where(sftlf.gt.1., 1., sftlf)
      ; ;; Mask out Antarctica (below 60degS)
      ; sftlf({:-60}, :) = sftlf@_FillValue
      ; ;; Apply mask
      ; data_var = data_var * conform(data_var, sftlf, (/1, 2/))
      ; delete([/sftlf, a, f/])
    end if

    ; Calculate annual mean
    data_yearly = time_operations(data_var, \
                                  toint(input_file_info@start_year(idat)), \
                                  toint(input_file_info@end_year(idat)), \
                                  "average", "yearly", True)

    ; Calculate mean annual cycle
    data_monthly = time_operations( \
      data_var, \
      max((/mean_minyear, toint(input_file_info@start_year(idat))/)), \
      min((/mean_maxyear, toint(input_file_info@end_year(idat))/)), \
      "average", "monthlyclim", True)

    ; Special case for LAI:
    ; Since datasets have different land covers, all sparse vegetated points
    ;  must be masked
    if (var0 .eq. "lai") then
      data_yearly = where(data_yearly .ge. 0.025, data_yearly, \
                          data_yearly@_FillValue)
      data_monthly = where(data_monthly .ge. 0.025, data_monthly, \
                           data_monthly@_FillValue)
    end if

    ; Calculate spatial means and total global area
    y_mean = area_operations(data_yearly, region(0), region(1), \
                             region(2), region(3), sp_opt, True)
    m_mean = area_operations(data_monthly, region(0), region(1), \
                             region(2), region(3), sp_opt, True)
    area = map_area(data_var&lat, data_var&lon)

    ; Calculate standard deviations
    ; FIXME: results to be checked
    ; tmp = data_yearly * conform(data_yearly, area, (/1, 2/))
    ; subr = area_operations(tmp, region(0), region(1), \
    ;                        region(2), region(3), "extract", True)
    ; y_std = dim_stddev_n_Wrap(subr, (/1, 2/))
    ; tmp := data_monthly * conform(data_monthly, area, (/1, 2/))
    ; subr := area_operations(tmp, region(0), region(1), \
    ;                        region(2), region(3), "extract", True)
    ; m_std = dim_stddev_n_Wrap(subr, (/1, 2/))
    ; delete([/subr, tmp/])

    ; Assign to global arrays
    idx_1 = ind(min(y_mean&year).eq.all_data_yearly&year)
    idx_2 = ind(max(y_mean&year).eq.all_data_yearly&year)
    all_data_yearly(idat, idx_1:idx_2, 0) = (/y_mean/)
    all_data_yearly(idat, idx_1:idx_2, 1) = 0.0
    ; FIXME: all_data_yearly(idat, idx_1:idx_2, 1) = (/y_std/)
    copy_VarAtts(y_mean, all_data_yearly)
    all_data_monthly(idat, :, 0) = (/m_mean/)
    all_data_monthly(idat, :, 1) = 0.0
    ; FIXME: all_data_monthly(idat, :, 1) = (/m_std/)
    copy_VarAtts(m_mean, all_data_monthly)
    delete([/y_mean, idx_1, idx_2, m_mean, data_var, data_yearly, \
            data_monthly, area/])
    ; FIXME: delete([/m_std, y_std/])
  end do

  ; Read in external observational data if necessary
  if (isatt(diag_script_info, "obsfile")) then
    log_info("Reading in additional data from: " + diag_script_info@obsfile)
    data_dum = addfile(diag_script_info@obsfile, "r")
    data_dum2 = data_dum->$diag_script_info@ref_varname$

    ; Get the overlap of the temporal frames
    obs_time = cd_calendar(data_dum2&time, 0)
    min_obs_year = toint(min(obs_time(:, 0)))
    max_obs_year = toint(max(obs_time(:, 0)))
    obs_years = ispan(min_obs_year, max_obs_year, 1)
    if (start_year .lt. min_obs_year) then
      l_idx_1 = ind(all_data_yearly&year .eq. min_obs_year)
      l_idx_2 = 0
    else
      l_idx_1 = 0
      l_idx_2 = ind(start_year .eq. obs_years)
    end if
    if end_year .lt. max_obs_year then
      u_idx_1 = dimsizes(all_data_yearly&year) - 1
      u_idx_2 = ind(end_year .eq. obs_years)
    else
      u_idx_1 = ind(all_data_yearly&year.eq.max_obs_year)
      u_idx_2 = dimsizes(obs_years)-1
    end if

    ; Make an array like all_data_yearly to easily append data
    all_data_yearly_add = new((/1, DIM_TIME, 2/), float)
    all_data_yearly_add!0 = "dataset"
    all_data_yearly_add!1 = "year"
    all_data_yearly_add!2 = "statistic"
    all_data_yearly_add&dataset = diag_script_info@obsname
    all_data_yearly_add&year = all_years
    all_data_yearly_add&statistic = (/"mean", "stddev"/)

    ; Data saved in one month per year, also put it in right time range
    obs_ind = ind(.not. ismissing(data_dum2))
    all_data_yearly_add(0, l_idx_1:u_idx_1, 0) = \
      (/data_dum2(obs_ind(l_idx_2:u_idx_2))/)
    all_data_yearly_add(0, l_idx_1:u_idx_1, 1) = 0.0  ; (/y_std/)
    ; FIXME: all_data_yearly_add(0, l_idx_1:u_idx_1, 1) = (/y_std/)

    ; Add data to existing arrays, add project, name to datasets attributes
    all_data_yearly_new = array_append_record(all_data_yearly, \
                                              all_data_yearly_add, 0)
    delete([/data_dum, data_dum2, min_obs_year, max_obs_year, obs_time, \
            all_data_yearly_add, obs_years, obs_ind/])
    input_file_info@dataset_new = \
      array_append_record(input_file_info@dataset, diag_script_info@obsname, 0)
    input_file_info@project_new = \
      array_append_record(input_file_info@project, "OBS", 0)
    input_file_info@project := input_file_info@project_new
    input_file_info@dataset := input_file_info@dataset_new
    all_data_yearly := all_data_yearly_new
    delete([/input_file_info@project_new, input_file_info@dataset_new, \
            all_data_yearly_new/])
    DIM_DAT = dims
  end if

;     ;; Convert units if appropriate [kg m-2 s-1] --> [PgC y-1]
;     if (isatt(variable_info, "plot_units")) then
;         all_data_yearly = convert_units(all_data_yearly, variable_info@plot_units)
;         all_data_monthly = convert_units(all_data_monthly, variable_info@plot_units)
;     end if
;     ;; Don't know how to do this in var_defs without losing irreg grid info
;     if (var0.eq."tos") then
;         all_data_yearly = all_data_yearly - 273.15
;         all_data_yearly@units = "degC"
;         all_data_monthly = all_data_monthly - 273.15
;         all_data_monthly@units = "degC"
;     end if

;     ;; Optional output to NetCDF
;     if (config_user_info@write_netcdf.eq."True") then

;       ;; Set path for saving processed data
;       if (.not.isfilepresent(config_user_info@work_dir)) then
;         system("mkdir -p " + config_user_info@work_dir)
;       end if

;         ;; Yearly data
;         new_path = config_user_info@work_dir + \
;                    basename(diag_script) + "_yearly_" + var0 + "_" + \
;             region@name + ".nc"
;         all_data_yearly@var = var0
;         all_data_yearly@diag_script = diag_script
;         all_data_yearly@ncdf = new_path
;         ncdf_outfile = ncdf_write(all_data_yearly, new_path)

;         ;; Monthly data
;         new_path = config_user_info@work_dir + \
;                    basename(diag_script) + "_monthly_" + var0 + "_" + \
;             region@name + ".nc"
;         all_data_monthly@var = var0
;         all_data_monthly@diag_script = diag_script
;         all_data_monthly@ncdf = new_path
;         ncdf_outfile = ncdf_write(all_data_monthly, new_path)

;     end if

;     ;; Seasonal cycle plot
;     if (diag_script_info@seasonal_cycle_plot) then

;         ;; Collect data
;         data_arr = all_data_monthly
;         data_arr@legend_outside = diag_script_info@legend_outside

;         ;; Add option for PgC/month y-axis that is used in Anav2013 plots 7, 9
;         if (isatt(diag_script_info, "anav_month")).and. \
;                           diag_script_info@anav_month then
;             data_arr = data_arr/12.
;             data_arr@units = "PgC/month"
;         end if

;         ;; Draw plot
;         outfile = plot_dir + diag_script + "_" + var0 + "_cycle_" + \
;             region@name
;         wks = gsn_open_wks(file_type, outfile)
;         wks@legendfile = outfile + "_legend"
;         data_arr@res_tiYAxisString = var0 + " [" + \
;             format_units(data_arr@units) + "]"
;         data_arr@res_tiMainString = region@name
;         plot = cycle_plot(wks, data_arr, var0)
;         draw(plot)
;         frame(wks)

;         ;; Attach Metadata to plot

;         ;alltags = array_append_record(tags, region@DM_tag, 0)
;         ;alltags := array_append_record(alltags,\
;         ;       (/"PT_seas", "ST_mean"/), 0)
;         ;caption = "Seasonal Cycle plot for " + variables(0) + \
;        ;           " over the period " + start_year + \
;        ;           "-" + end_year + ", similar to Anav et al., 2013, Fig. 9."
;       ;  id = diag_script
;      ;   isize = DIM_DAT_ORIG * dimsizes(variables)
;       ;  if (isatt(diag_script_info, "obsfile")) then
;       ;      isize = isize + 1
;       ;;  end if
;        ; climofiles = new(isize, string)
;        ; do n_var = 0, dimsizes(variables) - 1
;        ;     do idat = 0, DIM_DAT_ORIG - 1
;        ;         climofiles(n_var * DIM_DAT_ORIG + idat) = \
;        ;                     interface_get_inpaths(idat) + "/" + \
;        ;                     interface_get_infile(variables(n_var), field_types(n_var), idat)
;        ;     end do
;        ; end do
;        ; if (isatt(diag_script_info, "obsfile")) then
;        ;     climofiles(isize - 1) = diag_script_info@obsfile
;        ; end if
;       ;  contrib_authors = (/"A_anav_al", "A_wenz_sa", "A_righ_ma"/)

;         ;;NOTE: not implemented in v2 yet
;     ;ESMValMD(outfile+"."+file_type, alltags, caption, id, variables, input_file_info@dataset, climofiles, diag_script, contrib_authors)

;         ;delete([/alltags, caption, id, climofiles/])

;         delete(plot)
;         delete(wks)
;         delete(data_arr)
;     end if

;     ;; Error-bar plot
;     if (diag_script_info@errorbar_plot) then

;         annual_mean = dim_avg_Wrap(all_data_yearly(:, minyear_ind:maxyear_ind, 0))
;         annual_std = dim_stddev_Wrap(all_data_yearly(:, minyear_ind:maxyear_ind, 0))

;         ;; Sort dataset in alphabetical order (observations at the beginning)
;         if (isatt(diag_script_info, "sort")) then
;             if (diag_script_info@sort) then
;                 pid = sort_alphabetically(annual_mean&dataset, \
;                                           ind(input_file_info@project.eq."OBS"), \
;                                           "begin")
;                 annual_mean_s = annual_mean(pid)
;                 annual_mean_s&dataset = annual_mean&dataset(pid)
;                 annual_mean = annual_mean_s
;                 annual_std_s = annual_std(pid)
;                 annual_std_s&dataset = annual_std&dataset(pid)
;                 annual_std = annual_std_s
;                 delete([/annual_mean_s, annual_std_s, pid/])
;             end if
;         end if

;         ;; Collect data
;         data_arr = new((/2, dimsizes(annual_mean)/), float)
;         data_arr!0 = "statistic"
;         data_arr!1 = "dataset"
;         data_arr&statistic = (/"mean", "standard deviation"/)
;         data_arr&dataset = annual_mean&dataset
;         data_arr(0, :) = (/annual_mean/)
;         data_arr(1, :) = (/annual_std/)
;         data_arr@units = annual_mean@units
;         delete(annual_mean)
;         delete(annual_std)

;         ;; Draw plot
;         outfile = plot_dir + diag_script + "_" + var0 + "_errorbar_" + \
;             region@name
;         wks = gsn_open_wks(file_type, outfile)
;         data_arr@res_tiMainString = var0 + " - " + region@name
;         plot = errorbar_plot(wks, data_arr, var0)
;         draw(plot)
;         frame(wks)

;         ;; Attach Metadata to plot

;         ;alltags = array_append_record(tags, region@DM_tag, 0)
;         ;alltags := array_append_record(alltags,\
;         ;       (/"PT_errorbar", "ST_stddev", "ST_mean"/), 0)
;         ;caption = "Errorbar plot for " + variables(0) + \
;         ;          " over the period " + start_year + \
;         ;          "-" + end_year + ", similar to Anav et al., 2013, Fig. 6."
;         ;id = diag_script

;         ;isize = DIM_DAT_ORIG * dimsizes(variables)
;         ;if (isatt(diag_script_info, "obsfile")) then
;         ;    isize = isize + 1
;         ;end if
;         ;climofiles = new(isize, string)
;         ;do n_var = 0, dimsizes(variables) - 1
;        ;     do idat = 0, DIM_DAT_ORIG - 1
;         ;        climofiles(n_var * DIM_DAT_ORIG + idat) = \
;         ;                    interface_get_inpaths(idat) + "/" + \
;         ;                    interface_get_infile(variables(n_var), field_types(n_var), idat)
;         ;    end do
;         ;end do
;         ;if (isatt(diag_script_info, "obsfile")) then
;         ;;    climofiles(isize - 1) = diag_script_info@obsfile
;         ;end if

;         ;contrib_authors = (/"A_anav_al", "A_wenz_sa", "A_righ_ma"/)

;         ;;NOTE: not implemented in v2 yet
;     ;ESMValMD(outfile+"."+file_type, alltags, caption, id, variables, input_file_info@dataset, climofiles, diag_script, contrib_authors)

;         ;delete([/alltags, caption, id, climofiles/])

;         delete(plot)
;         delete(wks)
;         delete(data_arr)

;     end if

;     ;; Mean, IAV plot
;     if (diag_script_info@mean_IAV_plot) then

;         ;; Prepare data
;         annual_mean            = new((/DIM_DAT/), float)
;         annual_std             = new((/DIM_DAT/), float)
;         annual_mean@_FillValue = all_data_yearly@_FillValue
;         annual_std@_FillValue  = all_data_yearly@_FillValue
;         annual_mean@units      = all_data_yearly@units
;         annual_std@units       = all_data_yearly@units

;         ;; Loop over datasets
;         do idat = 0, DIM_DAT - 1
;             ;; Compute the spatial mean over time
;             annual_mean(idat) = dim_avg(all_data_yearly(idat, minyear_ind:maxyear_ind, 0))
;             ;; Compute the std over time for the region
;             annual_std(idat) = dim_stddev(all_data_yearly(idat, minyear_ind:maxyear_ind, 0))
;         end do

;         ;; Collect data
;         data_arr = new((/2, DIM_DAT/), float)
;         data_arr!0 = "statistic"
;         data_arr!1 = "dataset"
;         data_arr&statistic = (/"mean", "interannual variability"/)
;         data_arr&dataset = input_file_info@dataset
;         data_arr(0, :) = (/annual_mean/)
;         data_arr(1, :) = (/annual_std/)
;         data_arr@units = (/annual_mean@units, annual_std@units/)
;         data_arr@legend_outside = diag_script_info@legend_outside
;         delete(annual_mean)
;         delete(annual_std)

;         ;; Draw plot
;         outfile = plot_dir + diag_script + "_" + var0 + "_scatter_" + \
;             region@name
;         wks = gsn_open_wks(file_type, outfile)
;         wks@legendfile = outfile + "_legend"
;         data_arr@res_tiMainString = var0 + " - " + region@name
;         plot = scatterplot_markers(wks, data_arr, var0)
;         draw(plot)
;         frame(wks)
;         delete(plot)
;         delete(wks)
;         delete(data_arr)

;         ;; Attach Metadata to plot

;         ;alltags = array_append_record(tags, region@DM_tag, 0)
;         ;alltags := array_append_record(alltags,\
;         ;       (/"PT_scatter", "ST_mean"/), 0)
;         ;caption = "Scatterplot for " + variables(0) + \
;         ;          " over the period " + start_year + \
;         ;          "-" + end_year + ", similar to Anav et al., 2013, Fig. 17."
;         ;id = diag_script

;         ;isize = DIM_DAT_ORIG * dimsizes(variables)
;         ;if (isatt(diag_script_info, "obsfile")) then
;         ;    isize = isize + 1
;         ;end if
;         ;climofiles = new(isize, string)
;         ;do n_var = 0, dimsizes(variables) - 1
;         ;    do idat = 0, DIM_DAT_ORIG - 1
;         ;        climofiles(n_var * DIM_DAT_ORIG + idat) = \
;         ;                    interface_get_inpaths(idat) + "/" + \
;         ;                    interface_get_infile(variables(n_var), field_types(n_var), idat)
;         ;    end do
;         ;end do
;         ;if (isatt(diag_script_info, "obsfile")) then
;         ;    climofiles(isize - 1) = diag_script_info@obsfile
;         ;;end if

;         ;contrib_authors = (/"A_anav_al", "A_wenz_sa", "A_righ_ma"/)

;         ;;NOTE: not implemented in v2 yet
;     ;ESMValMD(outfile+"."+file_type, alltags, caption, id, variables, input_file_info@dataset, climofiles, diag_script, contrib_authors)

;         ;delete([/alltags, caption, id, climofiles/])

;     end if

;     ;; Time evolution plot

;     if (isatt(diag_script_info, "evolution_plot")).and. \
;                                  diag_script_info@evolution_plot then
;         ;; Check if it's supposed to be an anomaly plot
;         if (isatt(diag_script_info, "evolution_plot_anomaly")).and. \
;                          diag_script_info@evolution_plot_anomaly then
;             anomaly = True
;         else
;             anomaly = False
;         end if

;         outfile = plot_dir + diag_script + "_" + var0 + "_evolution_" + \
;            region@name

;         ;; Find out ref dataset index
;         obs_ind = ind(input_file_info@dataset.eq.diag_script_info@evolution_plot_ref_dataset)

;         ;; Set list of observations/input_file_info to exclude in the statistics
;         ex_mod = ind(input_file_info@project.eq."OBS")
;         if (isatt(diag_script_info, "evolution_plot_ignore")) then
;             ex_mod1 = array_append_record(ex_mod, ind(input_file_info@dataset.eq. \
;                                  diag_script_info@evolution_plot_ignore), 0)
;             delete(ex_mod)
;             ex_mod = ex_mod1
;             delete(ex_mod1)
;         end if
;         ;; To not get a warning about fillvalues from get1Dindex_Exclude
;         ind_mods = ispan(0, dimsizes(input_file_info@dataset) -1, 1)
;         ind_mods@_FillValue = default_fillvalue("integer")
;         mod_ind = get1Dindex_Exclude(ind_mods, ex_mod)
;         delete([/ex_mod, ind_mods/])

;         ;;data_arr = all_data_yearly                   ;; all_data_yearly:  dataset, year, std = 0
;         data_arr = new((/6, dimsizes(all_data_yearly&year)/), float)
;         dataset_mean = dim_avg_n(all_data_yearly(mod_ind,:,0), 0)
;         dataset_std = new((/dimsizes(dataset_mean)/), float)

;         data_arr@ref_name = diag_script_info@evolution_plot_ref_dataset
;         data_arr@units = all_data_yearly@units
;         data_arr@dim_Mod = dimsizes(mod_ind)

;         ;; Subtract mean 1901-1930 (coded as till 1930) if anomaly plot
;         ind_1930 = ind(all_data_yearly&year.eq.1930)

;         if anomaly then
;             data_arr(0, :) = (/all_data_yearly(obs_ind, :, 0)/) - \
;                               avg(all_data_yearly(obs_ind, :ind_1930, 0))
;             mod_means = dim_avg_n(all_data_yearly(mod_ind, :ind_1930, 0), 1)
;             data_arr(1, :) =(/dataset_mean/) - avg(mod_means)
;             do time_i = 0, dimsizes(all_data_yearly&year)-1
;                 data_arr(2, time_i) = dim_min_n(all_data_yearly(mod_ind,time_i,0) - mod_means, 0)
;                 data_arr(3, time_i) = dim_max_n(all_data_yearly(mod_ind,time_i,0) - mod_means, 0)
;                 dataset_std(time_i)  = dim_stddev_n(all_data_yearly(mod_ind,time_i,0) - mod_means, 0)
;             end do
;         else
;             data_arr(1, :) = (/dataset_mean/)
;             data_arr(2, :) = dim_min_n(all_data_yearly(mod_ind,:,0), 0)
;             data_arr(3, :) = dim_max_n(all_data_yearly(mod_ind,:,0), 0)
;             data_arr(0, :) = (/all_data_yearly(obs_ind, :, 0)/)
;             dataset_std  = dim_stddev_n(all_data_yearly(mod_ind,:,0), 0)

;         end if

;         data_arr(4, :) = (/all_data_yearly&year/)
;         data_arr(5, :) = (/dataset_std/)

;         ;; Pass on contour color
;         if (isatt(diag_script_info, "evolution_plot_color")) then
;             data_arr@contour_color = diag_script_info@evolution_plot_color
;         end if

;         wks = gsn_open_wks(file_type, outfile)
;         wks@legendfile = outfile + "_legend"
;         plot1 = evolution_base_plot(wks, data_arr, var0, anomaly)

;         res = True
;         ; After overlaying the plots, add titles and legend manually
;         res_text                    = True                  ; text mods desired
;         res_text@txFontHeightF      = 0.01                 ; change text size
;         res_text@txJust             = "CenterLeft"          ; text justification

;         res_lines                   = True                  ; polyline mods desired
;         res_lines@gsLineDashPattern = 0.                    ; solid line
;         res_lines@gsLineThicknessF  = 5.                    ; line thicker
;         res_lines@gsLineColor       = "gray60"               ; line color
;         wks_out = get_wks(wks, diag_script, var0)

;         ;; Create lines for Volcanic eruptions

;         if (isatt(diag_script_info, "evolution_plot_volcanoes")).and. \
;             diag_script_info@evolution_plot_volcanoes then
;             ymax = max((/max(data_arr(3,:)), max(data_arr(0, :))/))
;             ymin = min((/min(data_arr(2,:)), min(data_arr(0, :))/))
;             ytop = ymax + 0.1*(ymax-ymin)
;             xx = (/1963., 1963./)
;             yy = (/(ymin - 0.05 * (ymax - ymin)),(ymax + 0.15*(ymax-ymin))/)

;             plot1@$unique_string("dum")$ = gsn_add_polyline(wks_out,plot1,xx,yy,res_lines)
;             plot1@$unique_string("dum")$ = gsn_add_text(wks_out,plot1,"Agung",\
;                                       (xx(1)+0.5),(ytop),res_text)

;             xx = (/1982., 1982./)
;             plot1@$unique_string("dum")$ = gsn_add_polyline(wks_out,plot1,xx,yy,res_lines)
;             plot1@$unique_string("dum")$ = gsn_add_text(wks_out,plot1,"El Chichon",\
;                                       (xx(1)),(ytop),res_text)

;             xx = (/1991., 1991./)
;             plot1@$unique_string("dum")$ = gsn_add_polyline(wks_out,plot1,xx,yy,res_lines)
;             plot1@$unique_string("dum")$ = gsn_add_text(wks_out,plot1,"Pinatubo",\
;                                       (xx(1)),(ytop),res_text)

;             res_lines@gsLineColor = "orange"
;             xx = (/1998, 1998./)
;             plot1@$unique_string("dum")$ = gsn_add_polyline(wks_out,plot1,xx,yy,res_lines)
;             plot1@$unique_string("dum")$ = gsn_add_text(wks_out,plot1,"El Nino",\
;                                       (xx(1)+0.5),(ytop),res_text)

;         end if
;         res_lines@gsLineColor = "black"
;         res_lines@gsLineDashPattern = 16
;         res_lines@gsLineThicknessF = 3.
;         if .not.anomaly then
;             plot1@$unique_string("dum")$ = gsn_add_polyline(wks_out, plot1, \
;                    (/start_year, end_year/), \
;                    (/0., 0./), res_lines)
;         end if

;         res@gsnDraw          = False
;         res@gsnFrame         = False
;         res@gsnMaximize      = True
;         res@gsnPaperOrientation = "landscape"
;         res@xyLineThicknesses = (/2,2/)
;         res@xyLineColors      = (/"black","white"/)
;         res@xyDashPatterns	 = (/0.,0./)      ; make all lines solid

;         plot3 = gsn_csm_xy(wks_out, data_arr(4, :), data_arr(:1, :), res)

;         NhlAddOverlay(plot1, plot3, plot1)

;         draw(plot1)
;         frame(wks)

;         ;; Attach Metadata to plot

;         ;alltags = array_append_record(tags, region@DM_tag, 0)
;         ;alltags := array_append_record(alltags,\
;         ;       (/"PT_times"/), 0)
;         ;if (anomaly) then
;         ;    alltags := array_append_record(alltags,\
;         ;           (/"ST_anomaly"/), 0)
;         ;    tagstr = " (anomalies) "
;         ;else
;         ;    alltags := array_append_record(alltags,\
;         ;           (/"ST_mean"/), 0)
;         ;    tagstr = " "
;         ;end if
;         ;if isatt(diag_script_info, "fignum") then
;         ;    fignum = diag_script_info@fignum
;         ;else
;         ;    fignum = "1 top"
;         ;end if
;         ;caption = "Time series of " + variables(0) + tagstr + \
;         ;          ", similar to Anav et al., 2013, Fig." + fignum
;         ;id = diag_script

;         ;isize = DIM_DAT_ORIG * dimsizes(variables)
;         ;if (isatt(diag_script_info, "obsfile")) then
;         ;    isize = isize + 1
;         ;end if
;         ;climofiles = new(isize, string)
;         ;do n_var = 0, dimsizes(variables) - 1
;         ;    do idat = 0, DIM_DAT_ORIG - 1
;         ;        climofiles(n_var * DIM_DAT_ORIG + idat) = \
;         ;                    interface_get_inpaths(idat) + "/" + \
;         ;                    interface_get_infile(variables(n_var), field_types(n_var), idat)
;         ;    end do
;         ;end do
;         ;if (isatt(diag_script_info, "obsfile")) then
;         ;    climofiles(isize - 1) = diag_script_info@obsfile
;         ;end if

;         ;contrib_authors = (/"A_anav_al", "A_wenz_sa", "A_righ_ma"/)

;         ;;NOTE: not implemented in v2 yet
;         ;ESMValMD(outfile+"."+file_type, alltags, caption, id, variables, input_file_info@dataset, climofiles, diag_script, contrib_authors)

;         ;delete([/alltags, caption, id, climofiles/])

;         delete([/data_arr, anomaly/])

;     end if

  leave_msg(diag_script, "")

end
