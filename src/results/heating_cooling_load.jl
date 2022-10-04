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
`CoolingLoad` results keys:
- `load_series_ton` vector of site cooling load in every time step
- `annual_calculated_tonhr` sum of the `load_series_ton`
"""
function add_cooling_load_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    # Adds the `ElectricLoad` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()

    load_series_kw = p.s.cooling_load.loads_kw_thermal
    r["load_series_ton"] = load_series_kw/ KWH_THERMAL_PER_TONHOUR

    r["annual_calculated_tonhr"] = round(
        sum(r["load_series_ton"]) / p.s.settings.time_steps_per_hour, digits=2
    )
    
    d["CoolingLoad"] = r
    nothing
end

"""
`HeatingLoad` results keys:
- `dhw_load_series_mmbtu` vector of site domestic hot water load in every time step
- `space_heating_load_series_mmbtu` vector of site space heating load in every time step
- `load_series_mmbtu` vector of sum heating load in every time step
- `annual_calculated_dhw_mmbtu` sum of the `dhw_load_series_mmbtu`
- `annual_calculated_space_heating_mmbtu` sum of the `space_heating_load_series_mmbtu`
- `annual_calculated_mmbtu` sum of the `load_series_mmbtu`
"""
function add_heating_load_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    # Adds the `ElectricLoad` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()

    dhw_load_series_kw = p.s.dhw_load.loads_kw_thermal
    space_heating_load_series_kw = p.s.space_heating_load.loads_kw_thermal

    r["dhw_load_series_mmbtu"] = dhw_load_series_kw ./ KWH_PER_MMBTU
    r["space_heating_load_series_mmbtu"] = space_heating_load_series_kw ./ KWH_PER_MMBTU
    r["load_series_mmbtu"] = r["dhw_load_series_mmbtu"] .+ r["space_heating_load_series_mmbtu"]

    r["annual_calculated_dhw_mmbtu"] = round(
        sum(r["dhw_load_series_mmbtu"]) / p.s.settings.time_steps_per_hour, digits=2
    )
    r["annual_calculated_space_heating_mmbtu"] = round(
        sum(r["space_heating_load_series_mmbtu"]) / p.s.settings.time_steps_per_hour, digits=2
    )
    r["annual_calculated_mmbtu"] = round(
        r["dhw_load_series_mmbtu"] + r["space_heating_load_series_mmbtu"], digits=2
    )
    
    d["HeatingLoad"] = r
    nothing
end