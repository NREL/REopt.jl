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
    add_hot_storage_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")

Adds the Storage results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
Note: the node number is an empty string if evaluating a single `Site`.

Storage results:
- `size_gal` Optimal TES capacity, by volume [gal]
- `year_one_soc_series_pct` Vector of normalized (0-1) state of charge values over the first year [-]
- `year_one_to_load_series_mmbtu_per_hour` Vector of power used to meet load over the first year [MMBTU/hr]
"""
function add_hot_storage_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict, b::String; _n="")
    delta_T_degF = p.s.storage.attr["HotThermalStorage"].hot_water_temp_degF - p.s.storage.attr["HotThermalStorage"].cool_water_temp_degF
    avg_cp_kj_per_kgK = 998.2 
    avg_rho_kg_per_m3 = 4.184 #TODO: add CoolProp reference or perform analogous calculations for water and build lookup tables
    kwh_per_gal = convert_gal_to_kwh(delta_T_degF, avg_rho_kg_per_m3, avg_cp_kj_per_kgK)
    
    r = Dict{String, Any}()
    size_kwh = round(value(m[Symbol("dvStorageEnergy"*_n)][b]), digits=2)
    r["size_gal"] = size_kwh / kwh_per_gal

    if size_kwh != 0
    	soc = (m[Symbol("dvStoredEnergy"*_n)][b, ts] for ts in p.time_steps)
        r["year_one_soc_series_pct"] = round.(value.(soc) ./ size_kwh, digits=3)

        discharge = (m[Symbol("dvDischargeFromStorage"*_n)][b, ts] for ts in p.time_steps)
        r["year_one_to_load_series_mmbtu_per_hour"] = round.(value.(discharge) / MMBTU_TO_KWH, digits=7)
    else
        r["year_one_soc_series_pct"] = []
        r["year_one_to_load_series_mmbtu_per_hour"] = []
    end

    d[b] = r
    nothing
end

"""
    add_cold_storage_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")

Adds the Storage results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
Note: the node number is an empty string if evaluating a single `Site`.

Storage results:
- `size_gal` Optimal TES capacity, by volume [gal]
- `year_one_soc_series_pct` Vector of normalized (0-1) state of charge values over the first year [-]
- `year_one_to_load_series_ton` Vector of power used to meet load over the first year [ton]
"""
function add_cold_storage_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict, b::String; _n="")
    delta_T_degF = p.s.storage.attr["ColdThermalStorage"].hot_water_temp_degF - p.s.storage.attr["ColdThermalStorage"].cool_water_temp_degF
    avg_cp_kj_per_kgK = 998.2 
    avg_rho_kg_per_m3 = 4.184 #TODO: add CoolProp reference or perform analogous calculations for water and build lookup tables
    kwh_per_gal = convert_gal_to_kwh(delta_T_degF, avg_rho_kg_per_m3, avg_cp_kj_per_kgK)
    
    r = Dict{String, Any}()
    size_kwh = round(value(m[Symbol("dvStorageEnergy"*_n)][b]), digits=2)
    r["size_gal"] = size_kwh / kwh_per_gal

    if size_kwh != 0
    	soc = (m[Symbol("dvStoredEnergy"*_n)][b, ts] for ts in p.time_steps)
        r["year_one_soc_series_pct"] = round.(value.(soc) ./ size_kwh, digits=3)

        discharge = (m[Symbol("dvDischargeFromStorage"*_n)][b, ts] for ts in p.time_steps)
        r["year_one_to_load_series_ton"] = round.(value.(discharge) / TONHOUR_TO_KWH_THERMAL, digits=7)
    else
        r["year_one_soc_series_pct"] = []
        r["year_one_to_load_series_ton"] = []
    end

    d[b] = r
    nothing
end
