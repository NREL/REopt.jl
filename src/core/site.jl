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
struct Site
    "required"
    latitude
    "required"
    longitude
    land_acres
    roof_squarefeet
    min_resil_timesteps
    mg_tech_sizes_equal_grid_sizes
    node  # TODO validate that multinode Sites do not share node numbers? Or just raise warning
    function Site(;
        latitude::Real, 
        longitude::Real, 
        land_acres::Union{Float64, Nothing} = nothing, 
        roof_squarefeet::Union{Float64, Nothing} = nothing,
        min_resil_timesteps::Int=0,
        mg_tech_sizes_equal_grid_sizes::Bool = true,
        node::Int = 1, 
        )
        invalid_args = String[]
        if !(-90 <= latitude < 90)
            push!(invalid_args, "latitude must satisfy -90 <= latitude < 90, got $(latitude)")
        end
        if !(-180 <= longitude < 180)
            push!(invalid_args, "longitude must satisfy -180 <= longitude < 180, got $(longitude)")
        end
        if length(invalid_args) > 0
            error("Invalid argument values: $(invalid_args)")
        end
        new(latitude, longitude, land_acres, roof_squarefeet, min_resil_timesteps, 
            mg_tech_sizes_equal_grid_sizes, node)
    end
end