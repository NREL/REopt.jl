# *********************************************************************************
# REopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************
"""
    Financial

Financial data struct with inner constructor:
```julia
function Financial(;
    om_cost_escalation_pct::Float64 = 0.025,
    elec_cost_escalation_pct::Float64 = 0.023,
    boiler_fuel_cost_escalation_pct::Float64
    chp_fuel_cost_escalation_pct::Float64    
    offtaker_tax_pct::Float64 = 0.26,
    offtaker_discount_pct = 0.083,
    third_party_ownership::Bool = false,
    owner_tax_pct::Float64 = 0.26,
    owner_discount_pct::Float64 = 0.083,
    analysis_years::Int = 25,
    value_of_lost_load_per_kwh::Union{Array{R,1}, R} where R<:Real = 1.00,
    microgrid_upgrade_cost_pct::Float64 = 0.3,
    macrs_five_year::Array{Float64,1} = [0.2, 0.32, 0.192, 0.1152, 0.1152, 0.0576],  # IRS pub 946
    macrs_seven_year::Array{Float64,1} = [0.1429, 0.2449, 0.1749, 0.1249, 0.0893, 0.0892, 0.0893, 0.0446],
    co2_cost_per_tonne::Union{Missing,Float64} = 51.0,
    co2_cost_escalation_pct::Union{Missing,Float64} = 0.042173,
    nox_grid_cost_per_tonne::Union{Missing,Float64} = missing,
    so2_grid_cost_per_tonne::Union{Missing,Float64} = missing,
    pm25_grid_cost_per_tonne::Union{Missing,Float64} = missing,
    nox_onsite_fuelburn_cost_per_tonne::Union{Missing,Float64} = missing,
    so2_onsite_fuelburn_cost_per_tonne::Union{Missing,Float64} = missing,
    pm25_onsite_fuelburn_cost_per_tonne::Union{Missing,Float64} = missing,
    nox_cost_escalation_pct::Union{Missing,Float64} = missing,
    so2_cost_escalation_pct::Union{Missing,Float64} = missing,
    pm25_cost_escalation_pct::Union{Missing,Float64} = missing,
    latitude::Real,
    longitude::Real
)
```

!!! note
    When `third_party_ownership` is `false` the offtaker's discount and tax percentages are used throughout the model:
    ```julia
        if !third_party_ownership
            owner_tax_pct = offtaker_tax_pct
            owner_discount_pct = offtaker_discount_pct
        end
    ```
"""
struct Financial
    om_cost_escalation_pct::Float64
    elec_cost_escalation_pct::Float64
    boiler_fuel_cost_escalation_pct::Float64
    chp_fuel_cost_escalation_pct::Float64
    offtaker_tax_pct::Float64
    offtaker_discount_pct
    third_party_ownership::Bool
    owner_tax_pct::Float64
    owner_discount_pct::Float64
    analysis_years::Int
    value_of_lost_load_per_kwh::Union{Array{R,1}, R} where R<:Real
    microgrid_upgrade_cost_pct::Float64
    macrs_five_year::Array{Float64,1}
    macrs_seven_year::Array{Float64,1}
    co2_cost_per_tonne::Union{Missing,Float64}
    co2_cost_escalation_pct::Union{Missing,Float64}
    nox_grid_cost_per_tonne::Union{Missing,Float64}
    so2_grid_cost_per_tonne::Union{Missing,Float64}
    pm25_grid_cost_per_tonne::Union{Missing,Float64}
    nox_onsite_fuelburn_cost_per_tonne::Union{Missing,Float64}
    so2_onsite_fuelburn_cost_per_tonne::Union{Missing,Float64}
    pm25_onsite_fuelburn_cost_per_tonne::Union{Missing,Float64}
    nox_cost_escalation_pct::Union{Missing,Float64}
    so2_cost_escalation_pct::Union{Missing,Float64}
    pm25_cost_escalation_pct::Union{Missing,Float64}

    function Financial(;
        om_cost_escalation_pct::Float64 = 0.025,
        elec_cost_escalation_pct::Float64 = 0.023,
        boiler_fuel_cost_escalation_pct::Float64 = 0.034,
        chp_fuel_cost_escalation_pct::Float64 = 0.034,
        offtaker_tax_pct::Float64 = 0.26,
        offtaker_discount_pct = 0.083,
        third_party_ownership::Bool = false,
        owner_tax_pct::Float64 = 0.26,
        owner_discount_pct::Float64 = 0.083,
        analysis_years::Int = 25,
        value_of_lost_load_per_kwh::Union{Array{R,1}, R} where R<:Real = 1.00,
        microgrid_upgrade_cost_pct::Float64 = 0.3,
        macrs_five_year::Array{Float64,1} = [0.2, 0.32, 0.192, 0.1152, 0.1152, 0.0576],  # IRS pub 946
        macrs_seven_year::Array{Float64,1} = [0.1429, 0.2449, 0.1749, 0.1249, 0.0893, 0.0892, 0.0893, 0.0446],
        co2_cost_per_tonne::Float64 = 51.0,
        co2_cost_escalation_pct::Float64 = 0.042173,
        nox_grid_cost_per_tonne::Union{Missing,Float64} = missing,
        so2_grid_cost_per_tonne::Union{Missing,Float64} = missing,
        pm25_grid_cost_per_tonne::Union{Missing,Float64} = missing,
        nox_onsite_fuelburn_cost_per_tonne::Union{Missing,Float64} = missing,
        so2_onsite_fuelburn_cost_per_tonne::Union{Missing,Float64} = missing,
        pm25_onsite_fuelburn_cost_per_tonne::Union{Missing,Float64} = missing,
        nox_cost_escalation_pct::Union{Missing,Float64} = missing,
        so2_cost_escalation_pct::Union{Missing,Float64} = missing,
        pm25_cost_escalation_pct::Union{Missing,Float64} = missing,
        latitude::Real,
        longitude::Real
    )
        if !third_party_ownership
            owner_tax_pct = offtaker_tax_pct
            owner_discount_pct = offtaker_discount_pct
        end

        grid_costs = easiur_costs(latitude, longitude, "grid")
        onsite_costs = easiur_costs(latitude, longitude, "onsite")
        escalation_rates = easiur_escalation_rates(latitude, longitude, om_cost_escalation_pct)
        if isnothing(nox_grid_cost_per_tonne)
            nox_grid_cost_per_tonne = grid_costs["NOx"]
        end
        if isnothing(so2_grid_cost_per_tonne)
            so2_grid_cost_per_tonne = grid_costs["SO2"]
        end
        if isnothing(pm25_grid_cost_per_tonne)
            pm25_grid_cost_per_tonne = grid_costs["PM25"]
        end
        if isnothing(nox_onsite_fuelburn_cost_per_tonne)
            nox_onsite_fuelburn_cost_per_tonne = onsite_costs["NOx"]
        end
        if isnothing(so2_onsite_fuelburn_cost_per_tonne)
            so2_onsite_fuelburn_cost_per_tonne = onsite_costs["SO2"]
        end
        if isnothing(pm25_onsite_fuelburn_cost_per_tonne)
            pm25_onsite_fuelburn_cost_per_tonne = onsite_costs["PM25"]
        end
        if isnothing(nox_cost_escalation_pct)
            nox_cost_escalation_pct = escalation_rates["NOx"]
        end
        if isnothing(so2_cost_escalation_pct)
            so2_cost_escalation_pct = escalation_rates["SO2"]
        end
        if isnothing(pm25_cost_escalation_pct)
            pm25_cost_escalation_pct = escalation_rates["PM25"]
        end
        #TODO factor above code by pollutant (attempt below gave UndefVarError on eval() calls)
        # for pollutant in ["NOx", "SO2", "PM25"]
        #     grid_field_name = "$(lowercase(pollutant))_grid_cost_per_tonne"
        #     if isnothing(Symbol(grid_field_name))
        #         Symbol(grid_field_name) = grid_costs[pollutant]
        #     end
        #     # if eval(Meta.parse("isnothing($(grid_field_name))"))
        #     #     eval(Meta.parse("$(grid_field_name) = grid_costs[pollutant]"))
        #     # end
        #     onsite_field_name = "$(lowercase(pollutant))_onsite_fuelburn_cost_per_tonne"
        #     if eval(Meta.parse("isnothing($(onsite_field_name))"))
        #         eval(Meta.parse("$(onsite_field_name) = onsite_costs[pollutant]"))
        #     end
        #     escalation_field_name = "$(lowercase(pollutant))_cost_escalation_pct"
        #     if eval(Meta.parse("isnothing($(escalation_field_name))"))
        #         eval(Meta.parse("$(escalation_field_name) = escalation_rates[pollutant]"))
        #     end
        # end

        return new(
            om_cost_escalation_pct,
            elec_cost_escalation_pct,
            boiler_fuel_cost_escalation_pct,
            chp_fuel_cost_escalation_pct,
            offtaker_tax_pct,
            offtaker_discount_pct,
            third_party_ownership,
            owner_tax_pct,
            owner_discount_pct,
            analysis_years,
            value_of_lost_load_per_kwh,
            microgrid_upgrade_cost_pct,
            macrs_five_year,
            macrs_seven_year,
            co2_cost_per_tonne,
            co2_cost_escalation_pct,
            nox_grid_cost_per_tonne,
            so2_grid_cost_per_tonne,
            pm25_grid_cost_per_tonne,
            nox_onsite_fuelburn_cost_per_tonne,
            so2_onsite_fuelburn_cost_per_tonne,
            pm25_onsite_fuelburn_cost_per_tonne,
            nox_cost_escalation_pct,
            so2_cost_escalation_pct,
            pm25_cost_escalation_pct
        )
    end
end


# Convert from 2010$ to 2020$ (source: https://www.in2013dollars.com/us/inflation/2010?amount=100)
const USD_2010_to_2020 = 1.246

function easiur_costs(latitude::Float64, longitude::Float64, grid_or_onsite::String)
    # Assumption: grid emissions occur at site at 150m above ground
    # and on-site fuelburn emissions occur at site at 0m above ground
    if grid_or_onsite=="grid"
        type = "p150"
    elseif grid_or_onsite=="onsite"
        type = "area"
    else
        @error "Error in easiur_costs: grid_or_onsite must equal either 'grid' or 'onsite'"
    end
    EASIUR_data = get_EASIUR2005(type, pop_year=2020, income_year=2020, dollar_year=2010)

    # convert lon, lat to CAMx grid (x, y), specify datum. default is NAD83
    # Note: x, y returned from g2l follows the CAMx grid convention.
    # x and y start from 1, not zero. (x) ranges (1, ..., 148) and (y) ranges (1, ..., 112)
    coords = g2l(longitude, latitude, datum="NAD83")
    x = Int(round(coords[1]))
    y = Int(round(coords[2]))

    try
        costs_per_tonne = Dict(
            "NOx" => EASIUR_data["NOX_Annual"][x - 1, y - 1] .* USD_2010_to_2020,
            "SO2" => EASIUR_data["SO2_Annual"][x - 1, y - 1] .* USD_2010_to_2020,
            "PM25" => EASIUR_data["PEC_Annual"][x - 1, y - 1] .* USD_2010_to_2020
        )
        return costs_per_tonne
    catch
        @error "Could not look up EASIUR health costs from point ($latitude,$longitude). Location is likely invalid or outside the CAMx grid."
    end
end

function easiur_escalation_rates(latitude::Float64, longitude::Float64, inflation::Float64)
    EASIUR_150m_yr2020 = get_EASIUR2005("p150", pop_year=2020, income_year=2020, dollar_year=2010) 
    EASIUR_150m_yr2024 = get_EASIUR2005("p150", pop_year=2024, income_year=2024, dollar_year=2010) 

    # convert lon, lat to CAMx grid (x, y), specify datum. default is NAD83
    coords = g2l(longitude, latitude, datum="NAD83")
    x = Int(round(coords[1]))
    y = Int(round(coords[2]))

    try
        # nominal compound annual growth rate (real + inflation)
        escalation_rates = Dict(
            "NOx" => ((EASIUR_150m_yr2024["NOX_Annual"][x - 1, y - 1]/EASIUR_150m_yr2020["NOX_Annual"][x - 1, y - 1])^(1/4)-1) + inflation,
            "SO2" => ((EASIUR_150m_yr2024["SO2_Annual"][x - 1, y - 1]/EASIUR_150m_yr2020["SO2_Annual"][x - 1, y - 1])^(1/4)-1) + inflation,
            "PM25" => ((EASIUR_150m_yr2024["PEC_Annual"][x - 1, y - 1]/EASIUR_150m_yr2020["PEC_Annual"][x - 1, y - 1])^(1/4)-1) + inflation
        )
        return escalation_rates
    catch
        @error "Could not look up EASIUR health costs from point ($latitude,$longitude). Location is likely invalid or outside the CAMx grid"
    end
end

# function grid_costs(latitude, longitude)
#     # Assumption: grid emissions occur at site at 150m above ground
#     EASIUR_150m = get_EASIUR2005("p150", pop_year=2020, income_year=2020, dollar_year=2010)  # For keys in EASIUR: EASIUR_150m_pop2020_inc2020_dol2010.keys()

#     # convert lon, lat to CAMx grid (x, y), specify datum. default is NAD83
#     # Note: x, y returned from g2l follows the CAMx grid convention.
#     # x and y start from 1, not zero. (x) ranges (1, ..., 148) and (y) ranges (1, ..., 112)
#     coords = g2l(longitude, latitude, datum="NAD83")
#     x = int(round(coords[1]))
#     y = int(round(coords[2]))

#     try
#         grid_costs_per_tonne = {
#             "NOx" => EASIUR_150m["NOX_Annual"][x - 1, y - 1] .* USD_2010_to_2020,
#             "SO2" => EASIUR_150m["SO2_Annual"][x - 1, y - 1] .* USD_2010_to_2020,
#             "PM25" => EASIUR_150m["PEC_Annual"][x - 1, y - 1] .* USD_2010_to_2020,
#         }
#         return grid_costs_per_tonne
#     catch
#         @error "Could not look up EASIUR health costs from point ($latitude,$longitude). Location is likely invalid or outside the CAMx grid."
#     end
# end

# function onsite_costs(latitude, longitude)
#     # Assumption: on-site fuelburn emissions occur at site at 0m above ground;
#     EASIUR_0m = get_EASIUR2005("area", pop_year=2020, income_year=2020, dollar_year=2010)  # For keys in EASIUR: EASIUR_area_pop2020_inc2020_dol2010.keys()

#     # convert lon, lat to CAMx grid (x, y), specify datum. default is NAD83
#     # Note: x, y returned from g2l follows the CAMx grid convention.
#     # x and y start from 1, not zero. (x) ranges (1, ..., 148) and (y) ranges (1, ..., 112)
#     coords = g2l(longitude, latitude, datum="NAD83")
#     x = int(round(coords[1]))
#     y = int(round(coords[2]))

#     try
#         onsite_costs_per_tonne = {
#             "NOx" => EASIUR_0m["NOX_Annual"][x - 1, y - 1] .* USD_2010_to_2020,
#             "SO2" => EASIUR_0m["SO2_Annual"][x - 1, y - 1] .* USD_2010_to_2020,
#             "PM25" => EASIUR_0m["PEC_Annual"][x - 1, y - 1] .* USD_2010_to_2020,
#         }
#         return onsite_costs_per_tonne
#     catch
#         @error "Could not look up EASIUR health costs from point ($latitude,$longitude). Location is likely invalid or outside the CAMx grid"
#     end
# end

# class EASIURCalculator:

#     def __init__(self, latitude=None, longitude=None, **kwargs):
#         """
#         :param latitude: float
#         :param longitude: float
#         :param kwargs:
#         """
#         self.library_path = os.path.join('reo', 'src', 'data')
#         self.latitude = float(latitude) if latitude is not None else None
#         self.longitude = float(longitude) if longitude is not None else None
#         self.inflation = kwargs.get('inflation') or None
#         self._grid_costs_per_tonne = None
#         self._onsite_costs_per_tonne = None
#         self._escalation_rates = None 
        

#     @property
#     def onsite_costs(self):
#         if self._onsite_costs_per_tonne is None:
#             # Assumption: on-site fuelburn emissions occur at site at 0m above ground;
#             EASIUR_0m = get_EASIUR2005('area', pop_year=2020, income_year=2020, dollar_year=2010)  # For keys in EASIUR: EASIUR_150m_pop2020_inc2020_dol2010.keys()

#             # convert lon, lat to CAMx grid (x, y), specify datum. default is NAD83
#             # Note: x, y returned from g2l follows the CAMx grid convention.
#             # x and y start from 1, not zero. (x) ranges (1, ..., 148) and (y) ranges (1, ..., 112)
#             x, y = g2l(self.longitude, self.latitude, datum='NAD83')
#             x = int(round(x))
#             y = int(round(y))

#             # Convert from 2010$ to 2020$ (source: https://www.in2013dollars.com/us/inflation/2010?amount=100)
#             convert_2010_2020_usd = 1.246
#             try:
#                 self._onsite_costs_per_tonne = {
#                     'NOx' => EASIUR_0m['NOX_Annual'][x - 1, y - 1] * convert_2010_2020_usd,
#                     'SO2' => EASIUR_0m['SO2_Annual'][x - 1, y - 1] * convert_2010_2020_usd,
#                     'PM25' => EASIUR_0m['PEC_Annual'][x - 1, y - 1] * convert_2010_2020_usd,
#                 }
#             except:
#                 raise AttributeError("Could not look up EASIUR health costs from point ({},{}). Location is \
#                     likely invalid or outside the CAMx grid".format(self.latitude, self.longitude))
#         return self._onsite_costs_per_tonne

#     @property
#     def escalation_rates(self):
#         if self._escalation_rates is None:
#             EASIUR_150m_yr2020 = get_EASIUR2005('p150', pop_year=2020, income_year=2020, dollar_year=2010) 
#             EASIUR_150m_yr2024 = get_EASIUR2005('p150', pop_year=2024, income_year=2024, dollar_year=2010) 

#             # convert lon, lat to CAMx grid (x, y), specify datum. default is NAD83
#             x, y = g2l(self.longitude, self.latitude, datum='NAD83')
#             x = int(round(x))
#             y = int(round(y))

#             try:
#                 # real compound annual growth rate
#                 cagr_real = { 
#                     'NOx' => (EASIUR_150m_yr2024['NOX_Annual'][x - 1, y - 1]/EASIUR_150m_yr2020['NOX_Annual'][x - 1, y - 1])**(1/4)-1,
#                     'SO2' => (EASIUR_150m_yr2024['SO2_Annual'][x - 1, y - 1]/EASIUR_150m_yr2020['SO2_Annual'][x - 1, y - 1])**(1/4)-1,
#                     'PM25' => (EASIUR_150m_yr2024['PEC_Annual'][x - 1, y - 1]/EASIUR_150m_yr2020['PEC_Annual'][x - 1, y - 1])**(1/4)-1,
#                 }
#                 # nominal compound annual growth rate (real + inflation)
#                 self._escalation_rates = {
#                     'NOx' => cagr_real['NOx'] + self.inflation,
#                     'SO2' => cagr_real['SO2'] + self.inflation,
#                     'PM25' => cagr_real['PM25'] + self.inflation,
#                 }
#             except:
#                 raise AttributeError("Could not look up EASIUR health costs from point ({},{}). Location is \
#                     likely invalid or outside the CAMx grid".format(self.latitude, self.longitude))
#         return self._escalation_rates



"""
Adapted to Julia from example Python code for EASIUR found at https://barney.ce.cmu.edu/~jinhyok/apsca/#getting
"""

# import csv
# import deepdish
# import h5py
# import numpy as np
# import pyproj
# import os


# library_path = os.path.join('reo', 'src', 'data')

# # Income Growth Adjustment factors from BenMAP
# MorIncomeGrowthAdj = {
#     1990 => 1.000000,
#     1991 => 0.992025,
#     1992 => 0.998182,
#     1993 => 1.003087,
#     1994 => 1.012843,
#     1995 => 1.016989,
#     1996 => 1.024362,
#     1997 => 1.034171,
#     1998 => 1.038842,
#     1999 => 1.042804,
#     2000 => 1.038542,
#     2001 => 1.043834,
#     2002 => 1.049992,
#     2003 => 1.056232,
#     2004 => 1.062572,
#     2005 => 1.068587,
#     2006 => 1.074681,
#     2007 => 1.080843,
#     2008 => 1.087068,
#     2009 => 1.093349,
#     2010 => 1.099688,
#     2011 => 1.111515,
#     2012 => 1.122895,
#     2013 => 1.133857,
#     2014 => 1.144425,
#     2015 => 1.154627,
#     2016 => 1.164482,
#     2017 => 1.174010,
#     2018 => 1.183233,
#     2019 => 1.192168,
#     2020 => 1.200834,
#     2021 => 1.209226,
#     2022 => 1.217341,
#     2023 => 1.225191,
#     2024 => 1.232790,
# }

# # GDP deflator from BenMAP
# GDP_deflator = {
#     1980 => 0.478513,
#     1981 => 0.527875,
#     1982 => 0.560395,
#     1983 => 0.578397,
#     1984 => 0.603368,
#     1985 => 0.624855,
#     1986 => 0.636469,
#     1987 => 0.659698,
#     1988 => 0.686992,
#     1989 => 0.720093,
#     1990 => 0.759001,
#     1991 => 0.790941,
#     1992 => 0.814750,
#     1993 => 0.839141,
#     1994 => 0.860627,
#     1995 => 0.885017,
#     1996 => 0.911150,
#     1997 => 0.932056,
#     1998 => 0.946574,
#     1999 => 0.967480,
#     2000 => 1.000000,
#     2001 => 1.028455,
#     2002 => 1.044715,
#     2003 => 1.068525,
#     2004 => 1.096980,
#     2005 => 1.134146,
#     2006 => 1.170732,
#     2007 => 1.204077,
#     2008 => 1.250308,
#     2009 => 1.245860,
#     2010 => 1.266295,
# }

# # pyproj constant
# # LCP_US = pyproj.Proj("+proj=lcc +no_defs +a=6370000.0m +b=6370000.0m \
# #                    +lon_0=97w +lat_0=40n +lat_1=33n +lat_2=45n \
# #                    +x_0=2736000.0m +y_0=2088000.0m +towgs84=0,0,0")
# # GEO_SPHEROID = pyproj.Proj("+proj=lonlat +towgs84=0,0,0 +a=6370000.0m +no_defs")
# LCP_US = pyproj.Proj(
#     "+proj=lcc +no_defs +a=6370000.0 +b=6370000.0 "
#     "+lon_0=97w +lat_0=40n +lat_1=33n +lat_2=45n "
#     "+x_0=2736000.0 +y_0=2088000.0 +to_wgs=0,0,0 +units=m"
# )
# # GEO_SPHEROID = pyproj.Proj("+proj=lonlat +towgs84=0,0,0 +a=6370000.0 +no_defs")
# DATUM_NAD83 = pyproj.Proj("epsg:4269 +proj=longlat +ellps=GRS80 +datum=NAD83 +no_defs +towgs84=0,0,0")
# DATUM_WGS84 = pyproj.Proj("epsg:4326 +proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs +towgs84=0,0,0")


"""
    get_EASIUR2005(
        stack::String, # area, p150, or p300
        pop_year::Int64=2005, # population year
        income_year::Int64=2005, # income level (1990 to 2024)
        dollar_year::Int64=2010 # dollar year (1980 to 2010)
    )

Returns EASIUR for a given `stack` height in a dict.
"""
function get_EASIUR2005(stack::String; pop_year::Int64=2005, income_year::Int64=2005, dollar_year::Int64=2010)
    EASIUR_data_lib = joinpath(@__DIR__,"..","..","data","emissions","EASIUR_Data")
    # Income Growth Adjustment factors from BenMAP
    MorIncomeGrowthAdj = Dict(
        1990 => 1.000000,
        1991 => 0.992025,
        1992 => 0.998182,
        1993 => 1.003087,
        1994 => 1.012843,
        1995 => 1.016989,
        1996 => 1.024362,
        1997 => 1.034171,
        1998 => 1.038842,
        1999 => 1.042804,
        2000 => 1.038542,
        2001 => 1.043834,
        2002 => 1.049992,
        2003 => 1.056232,
        2004 => 1.062572,
        2005 => 1.068587,
        2006 => 1.074681,
        2007 => 1.080843,
        2008 => 1.087068,
        2009 => 1.093349,
        2010 => 1.099688,
        2011 => 1.111515,
        2012 => 1.122895,
        2013 => 1.133857,
        2014 => 1.144425,
        2015 => 1.154627,
        2016 => 1.164482,
        2017 => 1.174010,
        2018 => 1.183233,
        2019 => 1.192168,
        2020 => 1.200834,
        2021 => 1.209226,
        2022 => 1.217341,
        2023 => 1.225191,
        2024 => 1.232790,
    )
    # GDP deflator from BenMAP
    GDP_deflator = Dict(
        1980 => 0.478513,
        1981 => 0.527875,
        1982 => 0.560395,
        1983 => 0.578397,
        1984 => 0.603368,
        1985 => 0.624855,
        1986 => 0.636469,
        1987 => 0.659698,
        1988 => 0.686992,
        1989 => 0.720093,
        1990 => 0.759001,
        1991 => 0.790941,
        1992 => 0.814750,
        1993 => 0.839141,
        1994 => 0.860627,
        1995 => 0.885017,
        1996 => 0.911150,
        1997 => 0.932056,
        1998 => 0.946574,
        1999 => 0.967480,
        2000 => 1.000000,
        2001 => 1.028455,
        2002 => 1.044715,
        2003 => 1.068525,
        2004 => 1.096980,
        2005 => 1.134146,
        2006 => 1.170732,
        2007 => 1.204077,
        2008 => 1.250308,
        2009 => 1.245860,
        2010 => 1.266295,
    )

    if !(stack in ["area", "p150", "p300"])
        @warn "stack should be one of 'area', 'p150', 'p300'"
        return false
    end

    fn_2005 = joinpath(EASIUR_data_lib,"sc_8.6MVSL_$(stack)_pop2005.hdf5")
    ret_map = load(fn_2005)
    if pop_year != 2005
        fn_growth = joinpath(EASIUR_data_lib,"sc_growth_rate_pop2005_pop2040_$(stack).hdf5")
        map_rate = load(fn_growth)
        for (k,v) in map_rate
            setindex!(ret_map, v .* (v.^(pop_year - 2005)), k)
        end
    end
    if income_year != 2005
        try
            adj = get(MorIncomeGrowthAdj, income_year, nothing) / get(MorIncomeGrowthAdj, 2005, nothing)
            for (k, v) in ret_map
                setindex!(ret_map, v .* adj, k)
            end
        catch e
            @error e
            @warn "income year is $(income_year) but must be between 1990 to 2024"
            return false
        end
    end
    if dollar_year != 2010
        try
            adj = get(GDP_deflator, dollar_year, nothing) / get(GDP_deflator, 2010, nothing)
            for (k, v) in ret_map
                setindex!(ret_map, v .* adj, k)
            end
        catch e
            @warn "Dollar year must be between 1980 to 2010"
            return false
        end
    end

    return ret_map

    # ret_map = Dict()
    # h5open(file_2005, "r") do file_2005
    #     #ret_map = deepdish.io.load(file_2005)
    #     for k in names(file_2005)
    #         ret_map[k] = read(file_2005, k)
    #     end
    #     if pop_year != 2005
    #         filename = joinpath(EASIUR_data_lib,"sc_growth_rate_pop2005_pop2040_$(stack).hdf5"
    #         h5open(filename, "r") do file
    #             for k in names(file)
    #                 ret_map[k] = ret_map[k] * (read(file,k)^(pop_year - 2005))
    #             end
    #         end
    #     end
    #     if income_year != 2005
    #         try
    #             adj = MorIncomeGrowthAdj[income_year] / MorIncomeGrowthAdj[2005]
    #             for k, v in ret_map.items()
    #                 ret_map[k] = v * adj
    #             end
    #         catch e
    #             @warn "income year must be between 1990 to 2024"
    #             return false
    #         end
    #     end
    #     if dollar_year != 2010
    #         try:
    #             adj = GDP_deflator[dollar_year] / GDP_deflator[2010]
    #             for k, v in ret_map.items()
    #                 ret_map[k] = v * adj
    #             end
    #         catch e
    #             @warn "Dollar year must be between 1980 to 2010"
    #             return false
    #         end
    #     end
    # end

end

"""
    l2g(x::Float64, y::Float64, inverse::Bool=false, datum::String="NAD83")

Convert LCP (x, y) in CAMx 148x112 grid to Geodetic (lon, lat)
"""
function l2g(x::Float64, y::Float64; inverse::Bool=false, datum::String="NAD83")
    LCP_US = "+proj=lcc +no_defs +a=6370000.0 +b=6370000.0 +lon_0=97w +lat_0=40n +lat_1=33n +lat_2=45n +x_0=2736000.0 +y_0=2088000.0 +to_wgs=0,0,0 +units=m"
    if datum == "NAD83"
        datum = "+proj=longlat +ellps=GRS80 +datum=NAD83 +no_defs +towgs84=0,0,0"
        # datum = "epsg:4269 +proj=longlat +ellps=GRS80 +datum=NAD83 +no_defs +towgs84=0,0,0"
    elseif datum == "WGS84"
        datum = "+proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs +towgs84=0,0,0"
        # datum = "epsg:4326 +proj=longlat +ellps=WGS84 +datum=WGS84 +no_defs +towgs84=0,0,0"
    end
    if inverse
        trans = Proj4.Transformation(datum, LCP_US, always_xy=true)
        return (trans([x y]) ./ 36000.0) .+ [1 1]
    else
        trans = Proj4.Transformation(LCP_US, datum, always_xy=true)
        return trans([(x-1)*36e3 (y-1)*36e3])
    end
end

"""
    g2l(lon::Float64, lat::Float64, datum::String="NAD83")

Convert Geodetic (lon, lat) to LCP (x, y) in CAMx 148x112 grid
"""
function g2l(lon::Float64, lat::Float64; datum::String="NAD83")
    return l2g(lon, lat, inverse=true, datum=datum)
end
