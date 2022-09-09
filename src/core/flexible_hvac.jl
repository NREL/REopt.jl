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



struct BAU_HVAC
    existing_boiler_kw_thermal::AbstractVector{<:Real}
    existing_chiller_kw_thermal::AbstractVector{<:Real}
    temperatures::AbstractMatrix{<:Real}
end


"""
`FlexibleHVAC` is an optional REopt input with the following keys and default values: 
```julia
    system_matrix::AbstractMatrix{Float64}  # N x N, with N states (temperatures in RC network)
    input_matrix::AbstractMatrix{Float64}  # N x M, with M inputs
    exogenous_inputs::AbstractMatrix{Float64}  # M x T, with T time steps
    control_node::Int64
    initial_temperatures::AbstractVector{Float64}
    temperature_upper_bound_degC::Union{Real, Nothing}
    temperature_lower_bound_degC::Union{Real, Nothing}
    installed_cost::Float64
```

Every model with `FlexibleHVAC` includes a preprocessing step to calculate the business-as-usual (BAU)
cost of meeting the thermal loads using a dead-band controller. The BAU cost is then used in the 
binary decision for purchasing the `FlexibleHVAC` system: if the `FlexibleHVAC` system is purchased then
the heating and cooling costs are determined by the HVAC dispatch that minimizes the lifecycle cost
of energy. If the `FlexibleHVAC` system is not purchased then the BAU heating and cooling costs must
be paid.

There are two construction methods for `FlexibleHVAC`, which depend on whether or not the data was 
loaded in from a JSON file. The issue with data from JSON is that the vector-of-vectors from the JSON 
file must be appropriately converted to Julia Matrices. When loading in a Scenario from JSON that 
includes a `FlexibleHVAC` model, if you include the `flex_hvac_from_json` argument to the `Scenario` 
constructor then the conversion to Matrices will be done appropriately. 

!!! note
    At least one of the inputs for `temperature_upper_bound_degC` or `temperature_lower_bound_degC`
    must be provided to evaluate the `FlexibleHVAC` option. For example, if only `temperature_lower_bound_degC`
    is provided then only a heating system will be evaluated. Also, the heating system will only be
    used (or purchased) if the `exogenous_inputs` lead to the temperature at the `control_node` going
    below the `temperature_lower_bound_degC`.

!!! note  
    The `ExistingChiller` is electric and so its operating cost is determined by the `ElectricTariff`.

!!! note 
    BAU heating costs will be determined by the `ExistingBoiler` inputs, including`fuel_cost_per_mmbtu`.
"""
struct FlexibleHVAC
    system_matrix::AbstractMatrix{Float64}  # N x N, with N states (temperatures in RC network)
    input_matrix::AbstractMatrix{Float64}  # N x M, with M inputs
    exogenous_inputs::AbstractMatrix{Float64}  # M x T, with T time steps
    control_node::Int64
    initial_temperatures::AbstractVector{Float64}
    temperature_upper_bound_degC::Union{Real, Nothing}
    temperature_lower_bound_degC::Union{Real, Nothing}
    installed_cost::Float64
    bau_hvac::BAU_HVAC
end


"""
    make_bau_hvac(A, B, u, control_node, initial_temperatures, T_hi, T_lo)

Determine the business-as-usual (BAU) energy cost for keeping the building temperature within the
bounds using a discrete-time simulation. The simulation assumes a dead band control by calculating 
what the temperature would be due to the `exogenous_inputs` alone. Then, if the temperature is outside
of the bounds the energy necessary to make the temperature 0.5 deg C within the bounds is determined.

TODO? either calculate an approximate BAU cost or enforce dvThermalProduction for !binFlexHVAC in model.
The cost of the energy necessary to heat/cool the building is determined by either:
1. The `ElectricTariff` for cooling using the `ExistingChiller`; or 
2. the `ExistingBoiler.fuel_cost_per_mmbtu` for heating
"""
function make_bau_hvac(A, B, u, control_node, initial_temperatures, T_hi, T_lo)
    J, T = size(u)
    N = size(A, 1)

    temperatures = zeros(N, T)
    temperatures[:, 1] .= initial_temperatures
    input_vec = zeros(N)
    input_vec[control_node] = 1

    thermal_kw = Dict(
        "ExistingChiller" => zeros(T),
        "ExistingBoiler" => zeros(T)
    )
    
    for ts in 2:T
        temperatures[:, ts] = temperatures[:, ts-1] + 
            A * temperatures[:, ts-1] +
            B * u[:, ts-1]

        if !isnothing(T_hi) && temperatures[control_node, ts] > T_hi
            deltaT = temperatures[control_node, ts] - T_hi
            thermal_kw["ExistingChiller"][ts] = deltaT / B[control_node, control_node]

            temperatures[:, ts] = temperatures[:, ts-1] + 
                A * temperatures[:, ts-1] +
                B * u[:, ts-1] -
                input_vec .* B[:, control_node] * thermal_kw["ExistingChiller"][ts]

        elseif !isnothing(T_lo) && temperatures[control_node, ts] < T_lo
            deltaT = T_lo - temperatures[control_node, ts]
            thermal_kw["ExistingBoiler"][ts] = deltaT / B[control_node, control_node] 

            temperatures[:, ts] = temperatures[:, ts-1] + 
                A * temperatures[:, ts-1] +
                B * u[:, ts-1] +
                input_vec .* B[:, control_node] * thermal_kw["ExistingBoiler"][ts]
        end
    end

    return BAU_HVAC(
        thermal_kw["ExistingBoiler"],
        thermal_kw["ExistingChiller"],
        temperatures
    )
end


"""
    FlexibleHVAC(dict_from_json::Dict)


"""
function FlexibleHVAC(
        dict_from_json::Dict
    )
    #=
    When loading in JSON list of lists we get a Vector{Any}, containing more Vector{Any}
    Convert the Vector of Vectors to a Matrix with:
    Matrix(hcat(Vector{Float64}.(<VectorOfVectors-from-JSON>)...))
    =#
    A = Matrix(hcat(Vector{Float64}.(dict_from_json["system_matrix"])...))
    B = Matrix(hcat(Vector{Float64}.(dict_from_json["input_matrix"])...))
    u = Matrix(hcat(Vector{Float64}.(dict_from_json["exogenous_inputs"])...))'
   
    bau_hvac = make_bau_hvac(A, B, u, 
        dict_from_json["control_node"], 
        dict_from_json["initial_temperatures"], 
        dict_from_json["temperature_upper_bound_degC"], 
        dict_from_json["temperature_lower_bound_degC"]
    )

    FlexibleHVAC(
        A,
        B,
        u,
        dict_from_json["control_node"],
        dict_from_json["initial_temperatures"],
        dict_from_json["temperature_upper_bound_degC"],
        dict_from_json["temperature_lower_bound_degC"],
        dict_from_json["installed_cost"],
        bau_hvac
    )
end

"""
    function FlexibleHVAC(;
        system_matrix::AbstractMatrix,
        input_matrix::AbstractMatrix,
        exogenous_inputs::AbstractMatrix,
        control_node::Int64,
        initial_temperatures::AbstractVector,
        temperature_upper_bound_degC::Union{Real, Nothing} = nothing,
        temperature_lower_bound_degC::Union{Real, Nothing} = nothing,
        installed_cost::Real
    )

When the A, B, and u values are in Matrix format (note u is normally a vector but in our case it has a time index in the second dimension)
"""
function FlexibleHVAC(;
        system_matrix::AbstractMatrix,
        input_matrix::AbstractMatrix,
        exogenous_inputs::AbstractMatrix,
        control_node::Int64,
        initial_temperatures::AbstractVector,
        temperature_upper_bound_degC::Union{Real, Nothing} = nothing,
        temperature_lower_bound_degC::Union{Real, Nothing} = nothing,
        installed_cost::Real
    )

    bau_hvac = make_bau_hvac(system_matrix, input_matrix, exogenous_inputs, control_node, 
        initial_temperatures, temperature_upper_bound_degC, temperature_lower_bound_degC)
    
    FlexibleHVAC(
        system_matrix,
        input_matrix,
        exogenous_inputs,
        control_node,
        initial_temperatures,
        temperature_upper_bound_degC,
        temperature_lower_bound_degC,
        installed_cost,
        bau_hvac
    )
end
