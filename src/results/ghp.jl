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
- `ghp_option_chosen` Option chosen for GHP (0 = none)
-- With ghp_option_chosen >=1, all data about the GHP system can be achieved by s.ghp_option_list[ghp_option_chosen]
- `heating_thermal_load_reduction_with_ghp_kw`
- `cooling_thermal_load_reduction_with_ghp_kw`
"""

function add_ghp_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
	r = Dict{String, Any}()
    @expression(m, GHPOptionChosen, sum(g * m[Symbol("binGHP"*_n)][g] for g in p.ghp_options))
	r["ghp_option_chosen"] = convert(Int64, value(GHPOptionChosen))
    if r["ghp_option_chosen"] > 0
        @expression(m, HeatingThermalReductionWithGHP[ts in p.time_steps],
		    sum(p.heating_thermal_load_reduction_with_ghp_kw[g,ts] * m[Symbol("binGHP"*_n)][g] for g in p.ghp_options))
        r["heating_thermal_load_reduction_with_ghp_kw"] = round.(value.(HeatingThermalReductionWithGHP), digits=3)
        @expression(m, CoolingThermalReductionWithGHP[ts in p.time_steps],
		    sum(p.cooling_thermal_load_reduction_with_ghp_kw[g,ts] * m[Symbol("binGHP"*_n)][g] for g in p.ghp_options))
        r["cooling_thermal_load_reduction_with_ghp_kw"] = round.(value.(CoolingThermalReductionWithGHP), digits=3)
    else
        r["heating_thermal_load_reduction_with_ghp_kw"] = zeros(length(p.time_steps))
        r["cooling_thermal_load_reduction_with_ghp_kw"] = zeros(length(p.time_steps))
    end
    d["GHP"] = r
    nothing
end