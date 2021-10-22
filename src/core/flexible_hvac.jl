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

struct FlexibleHVAC
    system_matrix::AbstractMatrix{Float64}  # N x N, with N states (temperatures in RC network)
    input_matrix::AbstractMatrix{Float64}  # N x M, with M inputs
    exogenous_inputs::AbstractMatrix{Float64}  # M x T, with T time steps
    control_node::Int64
    initial_temperatures::AbstractVector{Float64}
    comfort_temperature_upper_bound::Float64
    comfort_temperature_lower_bound::Float64
    installed_cost::Float64
end

function FlexibleHVAC(;
    system_matrix::AbstractVector,
    input_matrix::AbstractVector,
    exogenous_inputs::AbstractVector,
    control_node::Int64,
    initial_temperatures::AbstractVector,
    comfort_temperature_upper_bound::Float64,
    comfort_temperature_lower_bound::Float64,
    installed_cost::Float64
    )
    #=
    When loading in JSON list of lists we get a Vector{Any}, containing more Vector{Any}
    Convert the Vector of Vectors to a Matrix with:
    Matrix(hcat(Vector{Float64}.(<VectorOfVectors-from-JSON>)...))
    =#
    A = Matrix(hcat(Vector{Float64}.(system_matrix)...))
    B = Matrix(hcat(Vector{Float64}.(input_matrix)...))
    u = Matrix(hcat(Vector{Float64}.(exogenous_inputs)...))'
    # TODO should the above Matrices be transposed? (What was the intended format in test_flexloads.py?)
    FlexibleHVAC(
        A,
        B,
        u,
        control_node,
        initial_temperatures,
        comfort_temperature_upper_bound,
        comfort_temperature_lower_bound,
        installed_cost,
    )
end
