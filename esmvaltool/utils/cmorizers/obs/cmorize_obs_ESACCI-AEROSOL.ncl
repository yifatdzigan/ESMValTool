; #############################################################################
; ESMValTool CMORizer for ESACCI-AEROSOL data
; #############################################################################
;
; Tier
;    Tier 2: other freely-available dataset.
;
; Source
;    ftp://anon-ftp.ceda.ac.uk/neodc/esacci/aerosol/data/
;
; Last access
;    20190124
;
; Download and processing instructions
;    Download the data from:
;      ATSR2_SU/L3/v4.21/MONTHLY/ (1997-2002)
;      AATSR_SU/L3/v4.21/MONTHLY/ (2003-2011)
;    Other years are not considered since they are not complete.
;    Put all files in input_dir_path (no subdirectories with years).
;
; Modification history
;    20190124-A_righ_ma: adapted to v2.
;    20160718-A_laue_ax: added AOD550 + AOD870 uncertainties.
;    20160525-A_righ_ma: updated to v4.21 and adding more variables.
;    20150126-A_righ_ma: adding AOD at other wavelengths.
;    20151124-A_righ_ma: switched to monthly raw data (now available).
;    20150424-A_righ_ma: written.
;
; #############################################################################
loadscript(getenv("esmvaltool_root") + "/utils/cmorizers/obs/interface.ncl")

begin

  ; Script name (for logger)
  DIAG_SCRIPT = "cmorize_obs_ESACCI-AEROSOL.ncl"

  ; Source name
  OBSNAME = "ESACCI-AEROSOL"

  ; Tier
  TIER = 2

  ; Period
  YEAR1 = 1997
  YEAR2 = 2011

  ; MIP
  MIP = "aero"

  ; Selected variable (standard name)
  VARS = (/"od550aer", "od870aer", "od550lt1aer", "abs550aer", \
           "od550aerStderr", "od870aerStderr"/)

  ; Name in the raw data
  NAME = (/"AOD550_mean", "AOD870_mean", "FM_AOD550_mean", "AAOD550_mean", \
           "AOD550_uncertainty", "AOD870_uncertainty"/)

  ; CMOR table
  CMOR_TABLE = getenv("esmvaltool_root") + "/cmor/tables/" + \
    (/"cmip5/Tables/CMIP5_aero", \
      "cmip5/Tables/CMIP5_aero", \
      "cmip5/Tables/CMIP5_aero", \
      "cmip5/Tables/CMIP5_aero", \
      "custom/CMOR_od550aerStderr.dat", \
      "custom/CMOR_od870aerStderr.dat"/)

end

begin

  do vID = 0, dimsizes(VARS) - 1

    log_info("Processing " + VARS(vID))

    time = create_timec(YEAR1, YEAR2)
    date = cd_calendar(time, 1)

    ; Create timeseries
    do yy = YEAR1, YEAR2
      do mm = 1, 12

        ldate = yy + sprinti("%0.2i", mm)

        ; Read file
        fname = systemfunc("ls " + input_dir_path + ldate + "*.nc")

        ; No files found
        if (all(ismissing(fname))) then
          continue
        end if

        ; Extract data
        f = addfile(fname, "r")
        xx = f->$NAME(vID)$

        ; Assign to global array
        if (.not.isdefined("output")) then
          dims = array_append_record(dimsizes(time), dimsizes(xx), 0)
          output = new(dims, float)
          output!0 = "time"
          output&time = time
          output!1 = "lat"
          output&lat = f->latitude
          output!2 = "lon"
          output&lon = f->longitude
        end if
        output(ind(toint(ldate).eq.date), :, :) = (/xx/)
        delete(fname)

      end do
    end do

    ; Set fill value
    output = where(output.eq.-999, output@_FillValue, output)

    ; Format time coordinate
    ctime = time_attrib(output&time, YEAR1, YEAR2, "M")
    delete(output&time)
    output&time = ctime
    delete(ctime)

    ; Format latitude coordinate
    output!1 = "lat"
    if (isMonotonic(output&lat) .eq. 0) then
      error_msg("f", DIAG_SCRIPT, "", "non-monotonic latitude coordinate")
    end if
    if (isMonotonic(output&lat) .eq. -1) then
      output = output(:, ::-1, :)
    end if
    clat = lat_attrib(output&lat)
    delete(output&lat)
    output&lat = clat
    delete(clat)

    ; Format longitude coordinate
    output!2 = "lon"
    if (isMonotonic(output&lon) .eq. 0) then
      error_msg("f", DIAG_SCRIPT, "", "non-monotonic longitude coordinate")
    end if
    if (any(output&lon.lt.0.)) then
      output = lonFlip(output)
    end if
    clon = lon_attrib(output&lon)
    delete(output&lon)
    output&lon = clon
    delete(clon)

    ; Set variable attributes
    tmp = var_attrib(output, VARS(vID), CMOR_TABLE(vID))
    delete(output)
    output = tmp
    delete(tmp)

    ; Set global attributes
    gAtt = set_global_atts( \
      OBSNAME, TIER, \
      "ftp://anon-ftp.ceda.ac.uk/neodc/esacci/aerosol/data/", \
      "Popp et al., ESA Aerosol Climate Change Initiative " + \
      "(ESA Aerosol_cci) data: AOD v4.21 via Centre for Environmental " + \
      "Data Analysis, 2016", \
      "Combined dataset ERS2-ATSR2 (1997-2002) and ENVISAT-AATSR " + \
      "(2003-2011), based on the University of Swansea algorithm " + \
      "(monthly mean L3 data)")

    ; Outfile
    fout = output_dir_path + "OBS_" + OBSNAME + "_sat_SU-v4.21_" + MIP + \
      "_" + VARS(vID) + "_" + YEAR1 + "01-" + YEAR2 + "12.nc"

    ; Write variable
    write_nc(fout, VARS(vID), output, gAtt)
    delete(gAtt)
    delete(output)

  end do

end
