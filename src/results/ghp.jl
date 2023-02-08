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
    add_ghp_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")

Adds the `GHP` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
Note: the node number is an empty string if evaluating a single `Site`.

GHP results:
- `ghpghx_chosen_outputs` Dict of all outputs from GhpGhx.jl results of the chosen GhpGhx system
- `size_heat_pump_ton` Total heat pump capacity [ton]
- `space_heating_thermal_load_reduction_with_ghp_mmbtu_per_hour`
- `cooling_thermal_load_reduction_with_ghp_ton`
"""

function add_ghp_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
	r = Dict{String, Any}()
    @expression(m, GHPOptionChosen, sum(g * m[Symbol("binGHP"*_n)][g] for g in p.ghp_options))
	ghp_option_chosen = convert(Int64, value(GHPOptionChosen))
    r["ghp_option_chosen"] = ghp_option_chosen
    if ghp_option_chosen >= 1
        r["ghpghx_chosen_outputs"] = p.s.ghp_option_list[ghp_option_chosen].ghpghx_response["outputs"]
        r["size_heat_pump_ton"] = r["ghpghx_chosen_outputs"]["peak_combined_heatpump_thermal_ton"] * 
            p.s.ghp_option_list[ghp_option_chosen].heatpump_capacity_sizing_factor_on_peak_load
        @expression(m, HeatingThermalReductionWithGHP[ts in p.time_steps],
		    sum(p.space_heating_thermal_load_reduction_with_ghp_kw[g,ts] * m[Symbol("binGHP"*_n)][g] for g in p.ghp_options))
        r["space_heating_thermal_load_reduction_with_ghp_mmbtu_per_hour"] = round.(value.(HeatingThermalReductionWithGHP) ./ KWH_PER_MMBTU, digits=3)
        @expression(m, CoolingThermalReductionWithGHP[ts in p.time_steps],
		    sum(p.cooling_thermal_load_reduction_with_ghp_kw[g,ts] * m[Symbol("binGHP"*_n)][g] for g in p.ghp_options))
        r["cooling_thermal_load_reduction_with_ghp_ton"] = round.(value.(CoolingThermalReductionWithGHP) ./ KWH_THERMAL_PER_TONHOUR, digits=3)
    else
        r["ghpghx_chosen_outputs"] = Dict()
        r["size_heat_pump_ton"] = 0.0
        r["space_heating_thermal_load_reduction_with_ghp_mmbtu_per_hour"] = zeros(length(p.time_steps))
        r["cooling_thermal_load_reduction_with_ghp_ton"] = zeros(length(p.time_steps))
    end
    d["GHP"] = r
    nothing
end