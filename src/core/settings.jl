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
Captures high-level inputs affecting the optimization.

`Settings` is an optional REopt input with the following keys and default values:
```julia
    time_steps_per_hour::Int = 1 # corresponds to the time steps per hour for user-provided time series (e.g., `ElectricLoad.loads_kw` and `DomesticHotWaterLoad.fuel_loads_mmbtu_per_hour`) 
    add_soc_incentive::Bool = true # when true, an incentive is added to the model's objective function to keep the ElectricStorage SOC high
    off_grid_flag::Bool = false # true if modeling an off-grid system, not connected to bulk power system
    include_climate_in_objective::Bool = false # true if climate costs of emissions should be included in the model's objective function
    include_health_in_objective::Bool = false # true if health costs of emissions should be included in the model's objective function
```
"""
Base.@kwdef struct Settings
    time_steps_per_hour::Int = 1 # corresponds to the time steps per hour for user-provided time series (e.g., `ElectricLoad.loads_kw` and `DomesticHotWaterLoad.fuel_loads_mmbtu_per_hour`) 
    add_soc_incentive::Bool = true # when true, an incentive is added to the model's objective function to keep the ElectricStorage SOC high
    off_grid_flag::Bool = false # true if modeling an off-grid system, not connected to bulk power system
    include_climate_in_objective::Bool = false # true if climate costs of emissions should be included in the model's objective function
    include_health_in_objective::Bool = false # true if health costs of emissions should be included in the model's objective function
end
