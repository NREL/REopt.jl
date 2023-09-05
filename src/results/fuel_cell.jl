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
`FuelCell` results keys:
- `size_kw` Optimal fuel cell capacity
- `lifecycle_fixed_om_cost_after_tax` Lifecycle fixed operations and maintenance cost in present value, after tax
- `year_one_fixed_om_cost_before_tax` fixed operations and maintenance cost over the first year, before considering tax benefits
- `lifecycle_variable_om_cost_after_tax` Lifecycle variable operations and maintenance cost in present value, after tax
- `year_one_variable_om_cost_before_tax` variable operations and maintenance cost over the first year, before considering tax benefits
- `electric_to_storage_series_kw` Vector of power sent to battery in an average year
- `electric_to_grid_series_kw` Vector of power sent to grid in an average year
- `electric_to_load_series_kw` Vector of power sent to load in an average year
- `annual_energy_produced_kwh` Average annual energy produced over analysis period

!!! note "'Series' and 'Annual' energy outputs are average annual"
    REopt performs load balances using average annual production values for technologies that include degradation. 
    Therefore, all timeseries (`_series`) and `annual_` results should be interpretted as energy outputs averaged over the analysis period. 
    
"""
function add_fuel_cell_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    # Adds the `Compressor` results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
    # Note: the node number is an empty string if evaluating a single `Site`.

    r = Dict{String, Any}()
    r["size_kw"] = round(value(m[Symbol("dvSize"*_n)]["FuelCell"]), digits=4)

    d["FuelCell"] = r

end