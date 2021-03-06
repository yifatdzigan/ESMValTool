; #############################################################################
; FUNCTIONS FOR THE reformat_obs_*.ncl SCRIPTS
; #############################################################################
; General purpose functions called by the reformat_obs_*.ncl scripts.
;
; Contents
;    function check_time_range
;    function time_attrib
;    function plev_attrib
;    function lev_attrib
;    function lat_attrib
;    function lon_attrib
;    function read_cmor
;    function var_attrib
;    function set_size_array
;    function yyyyfrac_to_ut --> FIX-ME: only used by GLOBALVIEW (remove?)
;    function create_timec
;    function set_global_atts
;    procedure write_nc
;    procedure write_nc_profile
;    function process_EBAS_data
;
; #############################################################################

; Time units
TUNITS = "days since 1950-01-01 00:00:00"

; CMOR FillValue
FILL = 1.e+20

; #############################################################################
undef("check_time_range")
function check_time_range(time:numeric,
                          year1:numeric,
                          year2:numeric,
                          frequency:string)
;
; Arguments
;    time: input time coordinate.
;    year1: start year.
;    year2: end year.
;    frequency: time frequency ("M" for monthly, "D" for daily)
;
; Return value
;    An array of the same dimensionality of time.
;
; Description
;    Checks the consistency of time coordinate and sets the day to 15th of the
;    month (for monthly means) and the time to 00:00:00 (for monthly means) and
;    to 12:00:00 (for daily means).
;
; Caveats
;
; References
;
; Modification history
;    20190108-A_righ_ma: rewritten for v2.
;
local funcname, verbosity, date, ntime, exp_ntime, tt, yy, mm, calendar, y1, \
  y2, opt, out
begin

  funcname = "check_time_range"
  scriptname = "esmvaltool/utils/cmorizers/obs/utilities.ncl"
  enter_msg(scriptname, funcname)

  date = cd_calendar(time, 0)
  ntime = dimsizes(time)

  ; Check monotonicity
  if (isMonotonic(time).ne.1) then
    error_msg("f", scriptname, funcname, \
              "non-monotonically-increasing time coordinate in input data")
  end if

  ; Boundaries
  if (date(0, 0).gt.year1) then
    error_msg("f", scriptname, funcname, \
              "selected period outside range (" + year1 + \
              "<" + date(0, 0) + ")")
  end if
  if (date(ntime - 1, 0).lt.year2) then
    error_msg("f", scriptname, funcname, \
              "selected period outside range (" + year2 + \
              ">" + date(ntime - 1, 0) + ")")
  end if

  ; Monthly mean case
  if (frequency.eq."M") then

    ; Check number of timesteps
    exp_ntime = 12 * (year2 - year1 + 1)
    if (ntime.ne.exp_ntime) then
      error_msg("f", scriptname, funcname, \
                "incorrect number of timesteps in input data (" + \
                ntime + " != " + exp_ntime + "). Possibly due to " + \
                "incomplete years in input.")
    end if

    ; Set time coordinate to 15th of each month at 00:00:00
    do tt = 0, ntime - 1
      yy = year1 + tt / 12
      mm = mod(tt, 12) + 1
      if (date(tt, 0).ne.yy .or. date(tt, 1).ne.mm) then
        error_msg("f", scriptname, funcname, \
                  "inconsistent time coordinate in input data" + \
                  yy + sprinti("%0.2i", mm))
      end if
    end do
    date(:, 2) = 15   ; 15th of the month
    date(:, 3:5) = 0  ; midnight
  end if

  ; Daily mean case
  if (frequency.eq."D") then
    calendar = time@calendar

    ; Special treatment for proleptic_gregorian calendars
    ; (not supported by 'days_in_month(...)'
    if (calendar .eq. "proleptic_gregorian") then
      if (year1 .lt. 1582) then
        error_msg("w", scriptname, funcname, \
                  "changing calendar from proleptic_gregorian " + \
                  "to gregorian prior to 1582")
      end if
      calendar = "gregorian"
    end if

    ; Check number of timesteps
    y1 = year1
    y1@calendar = calendar
    y2 = year2
    y2@calendar = calendar
    opt = 0
    opt@calendar = calendar

    exp_ntime = \
      cd_inv_calendar(y2, 12, days_in_month(y2, 12), 0, 0, 0, TUNITS, opt) - \
      cd_inv_calendar(y1, 1, 1, 0, 0, 0, TUNITS, opt) + 1

    if (ntime.ne.exp_ntime) then
      error_msg("f", scriptname, funcname, \
                "incorrect number of timesteps in input data (" + ntime + \
                " != " + exp_ntime + "). Possibly due to incomplete " + \
                "years in input.")
    end if

    ; Set time coordinate to 12:00:00
    date(:, 3) = 12
    date(:, 4:5) = 0

  end if

  ; 3-hourly case
  ; Nothing to check

  ; Set calendar
  opt = 0
  if (isatt(time, "calendar")) then
    opt@calendar = time@calendar
  end if

  out = cd_inv_calendar(toint(date(:, 0)), toint(date(:, 1)), \
                        toint(date(:, 2)), toint(date(:, 3)), \
                        toint(date(:, 4)), toint(date(:, 5)), \
                        TUNITS, opt)

  leave_msg(scriptname, funcname)
  return(out)

end

; #############################################################################
undef("time_attrib")
function time_attrib(coord:numeric,
                     year1:numeric,
                     year2:numeric,
                     frequency:string)
;
; Arguments
;    coord: input time coordinate.
;    year1: start year.
;    year2: end year.
;    frequency: time frequency ("M" for monthly, "D" for daily, other
;               arguments are ignored)
;
; Return value
;    An array of the same dimensionality of coord.
;
; Description
;    Assigns attributes to the time coordinate (including range check).
;
; Caveats
;
; References
;
; Modification history
;    20130528-A_righ_ma: written.
;
local funcname, scriptname, tmp, cal, outcoord
begin

  funcname = "time_attrib"
  scriptname = "esmvaltool/utils/cmorizers/obs/utilities.ncl"
  enter_msg(scriptname, funcname)

  if (isatt(coord, "calendar")) then
    cal = coord@calendar
  else
    cal = "standard"
  end if

  tmp = check_time_range(coord, year1, year2, frequency)

  out_coord = todouble(tmp)  ; this also removes attributes
  copy_VarCoords(coord, out_coord)
  out_coord@calendar = cal
  out_coord@long_name = "time"
  out_coord@axis = "T"
  out_coord@units = TUNITS
  out_coord@standard_name = "time"
  if (isatt(out_coord, "_FillValue")) then
    delete(out_coord@_FillValue)
  end if

  leave_msg(scriptname, funcname)
  return(out_coord)

end

; #############################################################################
undef("plev_attrib")
function plev_attrib(coord:numeric)
;
; Arguments
;    coord: input pressure level coordinate.
;
; Return value
;    An array of the same dimensionality of coord.
;
; Description
;    Assigns attributes to the pressure level coordinate.
;
; Caveats
;
; References
;
; Modification history
;    20130528-A_righ_ma: written.
;
local funcname, scriptname, out_coord
begin

  funcname = "plev_attrib"
  scriptname = "esmvaltool/utils/cmorizers/obs/utilities.ncl"
  enter_msg(scriptname, funcname)

  out_coord = todouble(coord)  ; this also removes attributes
  copy_VarCoords(coord, out_coord)
  out_coord@positive = "down"
  out_coord@axis     = "Z"
  out_coord@long_name     = "pressure"
  out_coord@units         = "Pa"
  out_coord@standard_name = "air_pressure"
  if (isatt(out_coord, "_FillValue")) then
    delete(out_coord@_FillValue)
  end if

  leave_msg(scriptname, funcname)
  return(out_coord)

end

; #############################################################################
undef("lev_attrib")
function lev_attrib(coord:numeric)
;
; Arguments
;    coord: input ocean level coordinate.
;
; Return value
;    An array of the same dimensionality of coord.
;
; Description
;    Assigns attributes to the ocean level coordinate.
;
; Caveats
;
; References
;
; Modification history
;    20150415-A_righ_ma: written.
;
local funcname, scriptname, out_coord
begin

  funcname = "lev_attrib"
  scriptname = "esmvaltool/utils/cmorizers/obs/utilities.ncl"
  enter_msg(scriptname, funcname)

  out_coord = todouble(coord)  ; this also removes attributes
  copy_VarCoords(coord, out_coord)
  out_coord@long_name = "ocean depth coordinate"
  out_coord@positive = "down"
  out_coord@axis = "Z"
  out_coord@units = "m "
  out_coord@standard_name = "depth"
  if (isatt(out_coord, "_FillValue")) then
    delete(out_coord@_FillValue)
  end if

  leave_msg(scriptname, funcname)
  return(out_coord)

end

; #############################################################################
undef("lat_attrib")
function lat_attrib(coord)
;
; Arguments
;    coord: input latitude coordinate.
;
; Return value
;    An array of the same dimensionality of coord.
;
; Description
;    Assigns attributes to the latitude coordinate.
;
; Caveats
;
; References
;
; Modification history
;    20130528-A_righ_ma: written.
;
local funcname, scriptname, out_coord
begin

  funcname = "lat_attrib"
  scriptname = "esmvaltool/utils/cmorizers/obs/utilities.ncl"
  enter_msg(scriptname, funcname)

  out_coord = todouble(coord)  ; this also removes attributes
  copy_VarCoords(coord, out_coord)
  out_coord@long_name = "latitude"
  out_coord@axis = "Y"
  out_coord@units = "degrees_north"
  out_coord@standard_name = "latitude"
  if (isatt(out_coord, "_FillValue")) then
    delete(out_coord@_FillValue)
  end if

  leave_msg(scriptname, funcname)
  return(out_coord)

end

; #############################################################################
undef("lon_attrib")
function lon_attrib(coord)
;
; Arguments
;    coord: input longitude coordinate.
;
; Return value
;    An array of the same dimensionality of coord.
;
; Description
;    Assigns attributes to the longitude coordinate.
;
; Caveats
;
; References
;
; Modification history
;    20130528-A_righ_ma: written.
;
local funcname, scriptname, out_coord
begin

  funcname = "lon_attrib"
  scriptname = "esmvaltool/utils/cmorizers/obs/utilities.ncl"
  enter_msg(scriptname, funcname)

  out_coord = todouble(coord)  ; this also removes attributes
  copy_VarCoords(coord, out_coord)
  out_coord@long_name = "longitude"
  out_coord@axis = "X"
  out_coord@units = "degrees_east"
  out_coord@standard_name = "longitude"
  if (isatt(out_coord, "_FillValue")) then
    delete(out_coord@_FillValue)
  end if

  leave_msg(scriptname, funcname)
  return(out_coord)

end

; #############################################################################
undef("read_cmor")
function read_cmor(name:string,
                   table:string)
;
; Arguments
;    name: standard variable name.
;    string: full path to the CMOR table of the variable.
;
; Return value
;    A logical variable with the CMOR table attached as attributes.
;
; Description
;    Read variable attributes from the CMOR tables (cmor/<name>.cmor).
;
; Caveats
;
; References
;
; Modification history
;    20190107-A_righ_ma: modify to read standard CMIP5 tables
;    20130528-A_righ_ma: written.
;
local funcname, scriptname, data, idxu, idxd, attn, attv, out
begin

  funcname = "read_cmor"
  scriptname = "esmvaltool/utils/cmorizers/obs/utilities.ncl"
  enter_msg(scriptname, funcname)

  ; Read attributes from cmor table
  if (.not.fileexists(table)) then
    error_msg("f", scriptname, funcname, \
              "cannot find CMOR table " + table)
  end if

  if (isStrSubset(table, ".json")) then  ; CMIP6 tables

    error_msg("f", scriptname, funcname, \
              "use of CMIP6 CMOR tables not supported")

  else  ; CMIP5 and custom tables

    data = readAsciiTable(table, 1, "string", 0)

    ; Extract variable block
    idxu = ind(data(:, 0).eq."variable_entry:    " + name)
    if (any(ismissing(idxu))) then
      error_msg("f", scriptname, funcname, \
                "table for variable " + name + " not found in table " + \
                table)
    end if
    tmp = ind(str_get_field(data(:, 0), 1, ":").eq."variable_entry")
    if (dimsizes(tmp).gt.1) then
      next = min(ind(tmp.gt.idxu))
      if (.not.ismissing(next))
        idxd = tmp(min(ind(tmp.gt.idxu))) - 2
      else
        idxd = dimsizes(data(:, 0)) - 1
      end if
      data := data(idxu:idxd, 0)
      delete(idxd)
    else
      data := data(:, 0)  ; just 1 variable in this table
    end if
    delete(idxu)
    delete(tmp)

    ; Extract attributes
    idxu = ind(str_get_field(data, 1, ":").eq."! Variable attributes") + 2
    idxd = ind(str_get_field(data, 1, ":").eq. \
               "! Additional variable information") - 2
    attn = str_squeeze(str_get_field(data(idxu:idxd), 1, ":"))
    attv = str_squeeze(str_get_field(data(idxu:idxd), 2, ":"))

  end if

  out = True
  do ii = 0, dimsizes(attn) - 1
    out@$attn(ii)$ = attv(ii)
  end do

  leave_msg(scriptname, funcname)
  return(out)

end

; #############################################################################
undef("var_attrib")
function var_attrib(var:numeric,
                    name:string,
                    table:string)
;
; Arguments
;    var: the variable's field.
;    name: the variable's standard name.
;    string: full path to the CMOR table of the variable.
;
; Return value
;    An array of the same dimensionality of var.
;
; Description
;    Sets standard variable attributes.
;
; Caveats
;
; References
;
; Modification history
;    20190107-A_righ_ma: add extra argument for CMOR table
;    20161202-A_laue_ax: preserve attribute "coordinates" if present
;    20130528-A_righ_ma: written.
;
local funcname, scriptname, coordattr, out, tmp, att, ii
begin

  funcname = "var_attrib"
  scriptname = "esmvaltool/utils/cmorizers/obs/utilities.ncl"
  enter_msg(scriptname, funcname)

  ; Set fill value first
  if(isatt(var, "_FillValue")) then
    var = where(var.eq.var@_FillValue, FILL, var)
  end if
  var@_FillValue = FILL

  if (isatt(var, "coordinates")) then
    coordattr = var@coordinates
  end if

  ; Remove attributes
  delete_VarAtts(var, -1)

  ; Convert to float
  if (typeof(var).ne."float") then
    out = tofloat(var)
    copy_VarCoords(var, out)
  else
    out = var
  end if

  ; Append attributes
  out@_FillValue = FILL
  tmp = read_cmor(name, table)
  att = getvaratts(tmp)
  do ii = 0, dimsizes(att) - 1
    out@$att(dimsizes(att) - 1 - ii)$ = tmp@$att(dimsizes(att) - 1 - ii)$
  end do

  if (isvar("coordattr")) then
    out@coordinates = coordattr
  end if

  leave_msg(scriptname, funcname)
  return(out)

end

; #############################################################################
undef("set_size_array")
function set_size_array()
;
; Arguments
;
; Return value
;    An array of type double.
;
; Description
;    Sets a logarithmic array of sizes to be used for particle size
;    distribution calculations.
;
; Caveats
;
; References
;
; Modification history
;    20130528-A_righ_ma: written.
;
local funcname, scriptname, minsize, maxsize, nbins, bin, out
begin

  funcname = "set_size_array"
  scriptname = "esmvaltool/utils/cmorizers/obs/utilities.ncl"
  enter_msg(scriptname, funcname)

  ; Size range (0.5 nm - 10 um)
  minsize = 0.5e-9
  maxsize = 10.e-6
  nbins = 100

  ; Generate array
  out = new(nbins, double)
  bin = 10. ^ (log10(maxsize / minsize) / (nbins - 1))
  out(0) = minsize
  do ii = 1, nbins - 1
    out(ii) = out(ii - 1) * bin
  end do

  leave_msg(scriptname, funcname)
  return(out)

end

; #############################################################################
undef("yyyyfrac_to_ut")
function yyyyfrac_to_ut(frac:numeric,
                        option:integer,
                        flag)
;
; Arguments
;    frac: a one dimensional array of UTC decimal dates of the form yyyy.frac,
;          i.e., year plus fraction of the year
;    option: determines output format (see "option" of cd_calendar function)
;    flag: not yet used
;
; Return value
;    The format of the output is dependent upon the value of flag.
;    In all cases the first dimension is the same size as frac.
;    See http://www.ncl.ucar.edu/Document/Functions/Built-in/cd_calendar.shtml
;
; Description
;    Converts UTC decimal dates to a form suitable for NCL calendar functions
;
; Caveats
;    Considers leap years, but no leap seconds
;    -> Not sure, how this is treated in the raw data ...
;
; Modification history
;    20140624-A_gott_kl: written.
;

local funcname, scriptname, years, YEAR, units, offset, sorted, spy, ileap, \
    iyears, iy, f, f_sec, time, ut
begin

  funcname = "yyyyfrac_to_ut"
  scriptname = "esmvaltool/utils/cmorizers/obs/utilities.ncl"
  enter_msg(scriptname, funcname)

  ; Seconds per year
  years = toint(frac)
  spy = todouble(years)  ; just to create array
  spy(:) = 365. * 24. * 3600.
  ileap = ind(isleapyear(years))
  if(.not.all(ismissing(ileap))) then
    spy(ileap) = 366. * 24. * 3600.
  end if

  ; Offset (i.e. previous years) in seconds
  offset = spy  ; just to create array
  iyears = UNIQ(years)
  sorted = new((/3, dimsizes(iyears)/), double)
  sorted(2, :) = todouble(years(iyears))
  sorted(1, :) = todouble(spy(iyears))
  isorted = dim_pqsort(sorted(2, :), 1)
  sorted(2, :) = sorted(2, isorted)
  sorted(1, :) = sorted(1, isorted)
  sorted(0, :) = 0.

  ; Calculate one offset per year
  sorted(0, 0) = 0.
  do i = 1, dimsizes(iyears) - 1
    sorted(0, i) = sorted(0, i - 1) + sorted(1, i - 1)
  end do

  ; Offsets for all time steps (independent of order)
  do i = 0, dimsizes(iyears) - 1
    iy = ind(years.eq.toint(sorted(2, i)))
    offset(iy) = sorted(0, i)
    delete(iy)
  end do

  ; Determine units
  YEAR = tostring(sorted(2, 0))
  units = "seconds since " + YEAR + "-01-01 00:00:0.0"

  ; Fractions
  f = todouble(frac) - todouble(years)  ; decimal fraction
  f_sec = todouble(spy) * f  ; fraction in seconds
  time = offset + f_sec

  ; Add attributes
  time@units = units
  time@calendar = "standard"

  ; Convert to UT
  ut = cd_calendar(time, flag)

  leave_msg(scriptname, funcname)
  return(ut)

end

; #############################################################################
undef("create_timec")
function create_timec(y1:integer,
                      y2:integer)
;
; Arguments
;    y1: start year of the time range.
;    y2: end year of the time range.
;
; Return value
;    A one-dimensional array of size 12*(y2-y1+1).
;
; Description
;    Create a monthly time coordinate for the given time range.
;
; Modification history
;    20140124-A_righ_ma: written.
;
local funcname, scriptname, yy, mm, out
begin

  funcname = "create_timec"
  scriptname = "esmvaltool/utils/cmorizers/obs/utilities.ncl"
  enter_msg(scriptname, funcname)

  out = new(12 * (y2 - y1 + 1), double)
  do yy = y1, y2
    do mm = 1, 12
      out(12 * (yy - y1) + mm - 1) = \
        cd_inv_calendar(yy, mm, 15, 0, 0, 0, TUNITS, 0)
    end do
  end do

  leave_msg(scriptname, funcname)
  return(out)

end

; #############################################################################
undef("set_global_atts")
function set_global_atts(obsname:string,
                         tier:integer,
                         source:string,
                         reference:string,
                         comment:string)
;
; Argument
;    obsname: name of the observational dataset.
;    reference: reference for the dataset, or leave empty if not available.
;    source: link to the data source.
;    tier: tier number (2 or 3).
;    comment: additional information if required, or leave empty.
;
; Return value
;    A logical containing the arguments as attributes.
;
; Description
;    Generate the global attribute for the output file by combining user
;    provided information with default ones (author, host, date, etc.).
;
; Modification history
;    20190202-A_righ_ma: written.
;
local funcname, scriptname,
    dim_unlim, ii
begin

  funcname = "set_global_atts"
  scriptname = "esmvaltool/utils/cmorizers/obs/utilities.ncl"
  enter_msg(scriptname, funcname)

  global = True
  global@title = obsname + " data reformatted for the ESMValTool v2.0"
  global@tier = tier
  global@source = source
  if (strlen(str_squeeze(reference)).ne.0) then
    global@reference = reference
  else
    global@reference = "not available"
  end if
  if (strlen(str_squeeze(comment)).ne.0) then
    global@comment = comment
  end if
  global@user = systemfunc("echo $USER")
  global@host = systemfunc("hostname -f")
  global@history = "Created on " + systemfunc("date")
  global@conventions = "CF/CMOR"

  return(global)

  leave_msg(scriptname, funcname)

end


; #############################################################################
undef("write_nc")
procedure write_nc(outfile:string,
                   name:string,
                   var:numeric,
                   gAtt:logical)
;
; Arguments
;    outfile: the name of the file to be written, including its path.
;    name: the variable name.
;    var: the variable field.
;    gAtt: a logical variable, whose attributes are appended as file
;          attributes.
;
; Description
;    Writes the given variable to the given NetCDF file, appending also the
;    provided global attributes.
;
; Modification history
;    20140123-A_righ_ma: written.
;
local funcname, scriptname, w, gAtt, dim_names, ndims, dim_sizes, dim_types, \
    dim_unlim, ii
begin

  funcname = "write_nc"
  scriptname = "esmvaltool/utils/cmorizers/obs/utilities.ncl"
  enter_msg(scriptname, funcname)

  ; Open file
  if (fileexists(outfile)) then
    system("rm -f " + outfile)
  end if
  w = addfile(outfile, "c")
  setfileoption(w, "DefineMode", True)

  ; Get coordinates
  dim_names = getvardims(var)
  ndims = dimsizes(dim_names)
  dim_sizes = new(ndims, integer)
  dim_types = new(ndims, string)
  dim_unlim = new(ndims, logical)
  do ii = 0, ndims - 1
    dim_sizes(ii) = dimsizes(var&$dim_names(ii)$)
    dim_types(ii) = typeof(var&$dim_names(ii)$)
    dim_unlim(ii) = False
  end do

  ; Time coordinate must be unlimited
  if (any(dim_names.eq."time")) then
    dim_sizes(ind(dim_names.eq."time")) = -1
    dim_unlim(ind(dim_names.eq."time")) = True
  end if

  ; Define dimensions
  filedimdef(w, dim_names, dim_sizes, dim_unlim)
  do ii = 0, ndims - 1
    filevardef(w, dim_names(ii), dim_types(ii), dim_names(ii))
  end do
  filevardef(w, name, "float", dim_names)
  do ii = 0, ndims - 1
    filevarattdef(w, dim_names(ii), var&$dim_names(ii)$)
  end do
  filevarattdef(w, name, var)

  ; Append global attributes
  fileattdef(w, gAtt)

  ; Write
  setfileoption(w, "DefineMode", False)
  do ii = 0, ndims - 1
    w->$dim_names(ii)$ = (/var&$dim_names(ii)$/)
  end do
  w->$name$ = (/var/)

  leave_msg(scriptname, funcname)

end

; #############################################################################
undef("write_nc_profile")
procedure write_nc_profile(outfile:string,
                           name:string,
                           var:numeric,
                           gAtt:logical)
;
; Arguments
;    outfile: the name of the file to be written, including its path.
;    name: the variable name.
;    var: the variable field.
;    gAtt: a logical variable, whose attributes are appended as file
;          attributes.
;
; Description
;    Writes the given variable to the given NetCDF file, appending also the
;    provided global attributes.
;    Designed to write multiple variables for the vertical profiles data.
;
; Modification history
;    20140422-A_righ_ma: written.
;
local funcname, scriptname, w, coords, cc, jj, locname, locvar, cname
begin

  funcname = "write_nc_profile"
  scriptname = "esmvaltool/utils/cmorizers/obs/utilities.ncl"
  enter_msg(scriptname, funcname)

  ; Open file
  if (fileexists(outfile)) then
    system("rm -f " + outfile)
  end if
  w = addfile(outfile, "c")
  setfileoption(w, "DefineMode", True)

  ; Attach global attributes
  fileattdef(w, gAtt)

  ; Write dimensions
  coords = getvardims(var)
  do cc = 0, dimsizes(coords) - 2  ; skip column
    cname = coords(cc)
    filedimdef(w, cname, dimsizes(var&$cname$), False)
    filevardef(w, cname, typeof(var&$cname$), cname)
  end do

  ; Write variable
  do jj = 0, dimsizes(var&column) - 1

    ; Extract given column
    locname = str_sub_str(name + "_" + var&column(jj), "%", "")
    if (isdim(var, "case")) then
      locvar = var(:, :, jj)
    else
      locvar = var(:, jj)
    end if
    if (var&column(jj).eq."N") then
      locvar@units = "1"
    end if

    ; Define dimensions
    filevardef(w, locname, "float", coords(0: dimsizes(coords) - 2))
    do cc = 0, dimsizes(coords) - 2
      cname = coords(cc)
      filevarattdef(w, cname, locvar&$cname$)
    end do
    filevarattdef(w, locname, locvar)

    ; Write
    setfileoption(w, "DefineMode", False)
    do cc = 0, dimsizes(coords) - 2
      cname = coords(cc)
      w->$cname$ = (/locvar&$cname$/)
    end do
    w->$locname$ = (/locvar/)
    delete(locvar)
    delete(locname)

  end do

  leave_msg(scriptname, funcname)

end

; #############################################################################
undef("process_EBAS_data")
function process_EBAS_data(in_vars[*]:string,
                           in_units[*]: string,
                           in_matrix[*]:string,
                           in_compon[*]:string,
                           in_column[*]:string,
                           indir[1]:string,
                           st_code:string,
                           y1:integer,
                           y2:integer)
;
; Arguments
;    in_vars: variables standard name.
;    in_units: variables units in the raw data.
;    in_matrix: variables matrix in the raw data.
;    in_compon: variables name in the raw data.
;    in_column: variables name in the header.
;    indir: the input directory for raw data.
;    stcode: the code of the station to be processed (used for
;            cross-checking)
;    y1: start year of the considered time interval.
;    y2: end year of the considered time interval.
;
; Return value
;    A two-dimensional array (time, variable) with the monthly mean time
;    series of for each of the processed variables.
;
; Description
;    This function is used to process the data from the EBAS database (e.g.,
;    EANET, EMEP).
;
; Caveats
;    For the time coordinate in the input data, only units of days are
;    currently accepted.
;
; Modification history
;    20150413-A_righ_ma: improved time selection.
;    20140124-A_righ_ma: written.
;
local timec, datec, vID, fID, bn, en, head, hh, cline, syear, smonth, sday, \
  scode, comp, matr, unit, scale, fills, lline, cols, data_col, flag_col, \
  start_col, end_col, data, value, flag, start_time, end_time, mm, sidx, \
  monthind, stday, enday, nd, pt1, pt2, data_arr
begin

  funcname = "process_EBAS_data"
  scriptname = "esmvaltool/utils/cmorizers/obs/utilities.ncl"
  enter_msg(scriptname, funcname)

  ; EBAS flags for valid measurements
  ; (see http://www.nilu.no/projects/ccc/flags/index.html)
  validflags = (/798, 797, 782, 781, 780, 771, 770, 741, 740, 680, 679, \
                678, 676, 675, 668, 665, 662, 660, 657, 656, 655, 654, \
                653, 652, 651, 650, 649, 648, 644, 640, 559, 558, 557, \
                556, 555, 532, 531, 521, 499, 498, 476, 475, 470, 458, \
                457, 450, 440, 420, 410, 394, 392, 390, 382, 380, 370, \
                299, 298, 276, 275, 258, 257, 250, 249, 248, 247, 220, \
                211, 210, 191, 190, 189, 188, 187, 186, 185, 147, 120, \
                111, 110, 103, 102, 101, 100, 000/)

  ; Create time coordinate
  timec = create_timec(y1, y2)
  datec = cd_calendar(timec, -1)

  ; Create output array
  data_arr = new((/dimsizes(timec), dimsizes(in_vars)/), float)
  data_arr!0 = "time"
  data_arr&time = timec
  data_arr@_FillValue = FILL

  ; Create a temporary arrays for time averages and weights
  temp_arr = new(dimsizes(timec), float)
  temp_arr!0 = "time"
  temp_arr&time = timec
  temp_arr@_FillValue = FILL
  ndays_arr = new(dimsizes(timec), float)
  ndays_arr!0 = "time"
  ndays_arr&time = timec
  ndays_arr@_FillValue = FILL

  ; Loop over variables
  do vID = 0, dimsizes(in_vars) - 1

    log_info("  Processing variable " + in_compon(vID))

    ; Initialize
    temp_arr = 0.
    ndays_arr = 0.

    ; Read file list
    cstr = "find " + indir + " -type f -name '" + \
      st_code + ".*." + in_compon(vID) + "." + in_matrix(vID) + "*.nas'"
    in_files = systemfunc(cstr)
    if (all(ismissing(in_files))) then
      delete(in_files)
      continue
    end if
    in_bnames = systemfunc(cstr + " -exec basename {} " + inttochar(92) + ";")
    sy = str_get_cols(str_get_field(in_bnames, 2, "."), 0, 5)
    delete(cstr)

    sqsort(in_files)
    sqsort(in_bnames)

    ; Check for duplicates
    if (dimsizes(UNIQ(sy)).ne.dimsizes(sy)) then
      log_info("Duplicated data in input files")
      do fID = 0, dimsizes(in_files) - 1
        log_info("  " + in_files(fID))
      end do
      log_info("Remove duplicated files considering the following criteria")
      log_info("  most recent revision date")
      log_info("  most complete time coverage")
      log_info("  same instrument in different years")
      error_msg("f", scriptname, funcname, \
                "rerun this station after removing duplicates")
    end if
    delete(sy)

    ; Loop over input files
    do fID = 0, dimsizes(in_files) - 1

      log_info("   Reading file " + in_bnames(fID))

      ; Read header
      head = readAsciiHead(in_files(fID), "starttime")

      ; Extract and check starting date
      syear = toint(str_get_field(head(6), 1, " "))
      smonth = toint(str_get_field(head(6), 2, " "))
      sday = toint(str_get_field(head(6), 3, " "))

      ; Get time units
      utime = str_sub_str(head(8), "file reference point", "")
      if (.not.isStrSubset(utime, "days")) then
        error_msg("f", scriptname, funcname, "unexpected time units")
      end if
      utime = utime + syear + "-" + smonth + "-" + sday
      delete(syear)
      delete(smonth)
      delete(sday)

      ; Use first file units as reference
      if (fID.eq.0) then
        ref_utime = utime
      end if

      ; Check units consistency
      do hh = 0, dimsizes(head) - 1
        if (isStrSubset(head(hh), "Unit:")) then
          unit = str_squeeze(str_get_field(head(hh), 2, ":"))
          if (unit .ne. in_units(vID) .and. unit.ne."ug/m3") then
            error_msg("f", scriptname, funcname, \
                      "units in the file not as expected " + \
                      "(" + unit + " vs. " + in_units(vID) + ")")
          end if
          delete(unit)
        end if
      end do

      ; Get specific fill values and scale factors
      scale = tofloat(str_get_field(head(10), 2, " "))
      fills = tofloat(str_get_field(head(11), 2, " "))

      ; Get column names
      lline = head(dimsizes(head) - 1)
      ncols = str_fields_count(lline, " ")
      cols = new(ncols, string)
      do cc = 0, ncols - 1
        cols(cc) = str_get_field(lline, cc + 1, " ")
      end do
      data_col = min(ind(cols.eq.in_column(vID))) + 1
      flag_col = (ind(cols.eq."flag_" + in_column(vID).or.cols.eq."flag")) + 1
      start_col = ind(cols.eq."starttime") + 1
      end_col = ind(cols.eq."endtime") + 1
      delete(cols)
      delete(ncols)

      ; Read data
      data = readAsciiTable(in_files(fID), 1, "string", dimsizes(head))
      delete(head)

      ; Read data (for the given month)
      value = tofloat(str_get_field(data(:, 0), data_col, " "))
      value@_FillValue = -999.

      ; Read flag
      flag = toint(1000 * tofloat(str_get_field(data(:, 0), flag_col, " ")))

      ; Filter for valid values
      value = where(value.eq.fills, value@_FillValue, value)
      value = where(value.lt.0, value@_FillValue, value)
      do jj = 0, dimsizes(value) - 1
        if (all(flag(jj).ne.validflags)) then
          value(jj) = value@_FillValue
        end if
      end do
      delete(flag)
      delete(fills)

      ; Apply scaling
      if (scale.ne.1) then
        value = value * scale
      end if
      delete(scale)

      ; Get start and end time
      stt = todouble(str_get_field(data(:, 0), start_col, " "))
      stt@units = utime
      ent = todouble(str_get_field(data(:, 0), end_col, " "))
      ent@units = utime
      delete(data)

      ; Convert to reference time units
      stt = cd_convert(stt, ref_utime)
      ent = cd_convert(ent, ref_utime)

      ; Create time series
      if (fID.eq.0) then
        start_time = stt
        end_time = ent
        var = value
      else
        tmp = array_append_record(start_time, stt, 0)
        delete(start_time)
        start_time = tmp
        delete(tmp)
        tmp = array_append_record(end_time, ent, 0)
        delete(end_time)
        end_time = tmp
        delete(tmp)
        tmp = array_append_record(var, value, 0)
        delete(var)
        var = tmp
        delete(tmp)
      end if
      delete(stt)
      delete(ent)
      delete(value)

    end do
    delete(in_files)
    delete(in_bnames)

    ; Check monotonicity
    if (isMonotonic(start_time).ne.1) then
      error_msg("f", scriptname, funcname, \
                "non-monotonically increasing time-series, possible " + \
                "duplicated data in input")
    end if

    ; Calculate monthly mean from the time series
    do vv = 0, dimsizes(var) - 1

      if (ismissing(var(vv))) then
        continue
      end if

      pstart = start_time(vv)
      pend = -1000.d0

      do while (pend.lt.end_time(vv))

        wdate = cd_calendar(pstart, -5)
        wdatec = cd_calendar(pstart, -1)

        ; Find beginning of next month
        if (wdate(0, 1).eq.12) then
          wyear = wdate(0, 0) + 1
          wmonth = 1
        else
          wyear = wdate(0, 0)
          wmonth = wdate(0, 1) + 1
        end if
        pend = cd_inv_calendar(wyear, wmonth, 1, 0, 0, 0, ref_utime, 0)

        if (pend.gt.end_time(vv)) then
          pend = (/end_time(vv)/)
        end if

        didx = ind(wdatec.eq.datec)
        if (wdate(0, 0).lt.y1 .or. wdate(0, 0).gt.y2) then
          pstart = pend
          continue
        end if
        nd = tofloat(pend - pstart)
        temp_arr(didx) = temp_arr(didx) + var(vv) * nd
        ndays_arr(didx) = ndays_arr(didx) + nd

        ; DEBUG+++
        ; print(start_time(vv) +"  "+end_time(vv) + "  " + "(" + \
        ;       cd_calendar(start_time(vv), -2) + "-" + \
        ;       cd_calendar(end_time(vv), -2)+") " + datec(didx) + \
        ;       " nd="+nd)
        ; DEBUG---

        pstart = pend

      end do
      delete(pstart)
      delete(pend)

    end do

    delete(var)
    delete(start_time)
    delete(end_time)

    ; Calculate monthly mean
    temp_arr = where(temp_arr.eq.0, temp_arr@_FillValue, temp_arr)
    ndays_arr = where(ndays_arr.eq.0, ndays_arr@_FillValue, ndays_arr)
    temp_arr = temp_arr / ndays_arr

    ; Assign to global data array
    idx_nm = ind(.not.ismissing(temp_arr))
    if (all(ismissing(idx_nm))) then
      delete(idx_nm)
      continue
    end if
    do ii = 0, dimsizes(idx_nm) - 1
      data_arr(idx_nm(ii), vID) = temp_arr(idx_nm(ii))
    end do
    delete(idx_nm)

  end do  ; variables

  leave_msg(scriptname, funcname)
  return(data_arr)

end
