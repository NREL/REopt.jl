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
# LIABILITY, WHETHERa IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************
"""
`HydrogenLoad` is an optional REopt input with the following keys and default values:
```julia
    loads_kg::Array{<:Real,1} = Real[], # Hydrogen load profile in kg for one year. Must be hourly (8,760 samples), 30 minute (17,520 samples), or 15 minute (35,040 samples). All load values must be greater than or equal to zero.
    path_to_csv::String = "", # Path to csv containing the input for loads_kg 
    critical_loads_kg::Union{Nothing, Array{Real,1}} = nothing, # Critical hydrogen load during outages (kg/timestep). If not provided, it will be set to critical_load_fraction * loads_kg
    critical_load_fraction::Real = 0.0, # loads_kg is multiplied by the critical_load_fraction to determine the critical load that must be met during an outage if critical_loads_kg is not provided
```
"""
mutable struct HydrogenLoad
    loads_kg::Array{Real,1}
    critical_loads_kg::Array{Real,1}
    
    function HydrogenLoad(;
        loads_kg::Array{<:Real,1} = Real[],
        path_to_csv::String = "",
        critical_loads_kg::Union{Nothing, Array{Real,1}} = nothing,
        critical_load_fraction::Real = 0.0,
        time_steps_per_hour::Int = 1
        )
        
        # TODO warn user if critical hydrogen load is nonzero.

        if length(loads_kg) > 0

            if !(length(loads_kg) / time_steps_per_hour ≈ 8760)
                throw(@error("Provided hydrogen load does not match the time_steps_per_hour."))
            end

        elseif !isempty(path_to_csv)
            try
                loads_kg = vec(readdlm(path_to_csv, ',', Float64, '\n'))
            catch e
                throw(@error("Unable to read in hydrogen load profile from $path_to_csv. Please provide a valid path to a csv with no header."))
            end

            if !(length(loads_kg) / time_steps_per_hour ≈ 8760)
                throw(@error("Provided hydrogen load does not match the time_steps_per_hour."))
            end
    
        else
            throw(@error("Cannot construct HydrogenLoad. You must provide [loads_kg]."))
        end

        if length(loads_kg) < 8760*time_steps_per_hour
            loads_kg = repeat(loads_kg, inner=Int(time_steps_per_hour / (length(loads_kg)/8760)))
            @warn "Repeating hydrogen loads in each hour to match the time_steps_per_hour."
        end

        if isnothing(critical_loads_kg)
            critical_loads_kg = critical_load_fraction * loads_kg
        end

        new(
            loads_kg,
            critical_loads_kg
        )
    end
end