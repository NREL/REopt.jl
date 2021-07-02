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
    Generator

struct with inner constructor:
```julia
function Generator(;
    existing_kw::Real=0,
    min_kw::Real=0,
    max_kw::Real=1.0e6,
    cost_per_kw::Real=500.0,
    om_cost_per_kw::Real=10.0,
    om_cost_per_kwh::Float64=0.0,
    fuel_cost_per_gallon::Float64 = 3.0,
    fuel_slope_gal_per_kwh::Float64 = 0.076,
    fuel_intercept_gal_per_hr::Float64 = 0.0,
    fuel_avail_gal::Float64 = 660.0,
    min_turn_down_pct::Float64 = 0.0,
    only_runs_during_grid_outage::Bool = true,
    sells_energy_back_to_grid::Bool = false
)
```
"""
struct Generator <: AbstractGenerator
    existing_kw
    min_kw
    max_kw
    cost_per_kw
    om_cost_per_kw
    om_cost_per_kwh
    fuel_cost_per_gallon
    fuel_slope_gal_per_kwh
    fuel_intercept_gal_per_hr
    fuel_avail_gal
    min_turn_down_pct
    only_runs_during_grid_outage
    sells_energy_back_to_grid

    function Generator(;
        existing_kw::Real=0,
        min_kw::Real=0,
        max_kw::Real=1.0e6,
        cost_per_kw::Real=500.0,
        om_cost_per_kw::Real=10.0,
        om_cost_per_kwh::Float64=0.0,
        fuel_cost_per_gallon::Float64 = 3.0,
        fuel_slope_gal_per_kwh::Float64 = 0.076,
        fuel_intercept_gal_per_hr::Float64 = 0.0,
        fuel_avail_gal::Float64 = 660.0,
        min_turn_down_pct::Float64 = 0.0,  # TODO change this to non-zero value
        only_runs_during_grid_outage::Bool = true,
        sells_energy_back_to_grid::Bool = false
        )

        new(
            existing_kw,
            min_kw,
            max_kw,
            cost_per_kw,
            om_cost_per_kw,
            om_cost_per_kwh,
            fuel_cost_per_gallon,
            fuel_slope_gal_per_kwh,
            fuel_intercept_gal_per_hr,
            fuel_avail_gal,
            min_turn_down_pct,
            only_runs_during_grid_outage,
            sells_energy_back_to_grid,
        )
    end
end
