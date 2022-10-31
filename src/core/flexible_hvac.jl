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

The `FlexibleHVAC` system is modeled via a discrete state-space system:

``\\boldsymbol{x}[t+1] = \\boldsymbol{A x}[t] + \\boldsymbol{B u}[t]``

where
- ``\\boldsymbol{A}`` is the `system_matrix`;
- ``\\boldsymbol{B}`` is the `input_matrix`;
- ``\\boldsymbol{u}`` is the `exogenous_inputs`;
- ``\\boldsymbol{x}`` is the state vector, which includes the space temperature; and
- ``t`` is the integer hour (only hourly models available currently).

When providing your own `FlexibleHVAC` model, in addition to the above values one must also provide:
- `space_temperature_node` an integer for the index in ``\\boldsymbol{x}`` that must obey the comfort limits
- `hvac_input_node` an integer for the index in ``\\boldsymbol{u}`` that REopt can choose to inject or extract heat
- `temperature_upper_bound_degC` and/or `temperature_lower_bound_degC`
- `initial_temperatures` a vector of values for ``\\boldsymbol{x}[1]``
See construction methods below for more.

There are two construction methods for `FlexibleHVAC`, which depend on whether or not the data was 
loaded in from a JSON file. The issue with data from JSON is that the vector-of-vectors from the JSON 
file must be appropriately converted to Julia Matrices. When loading in a Scenario from JSON that 
includes a `FlexibleHVAC` model, if you include the `flex_hvac_from_json` argument to the `Scenario` 
constructor then the conversion to Matrices will be done appropriately. 

The simplest way to evaluate the FlexibleHVAC option is to use a built-in state-space model for one
of the DoE Commercial Reference Buildings. For example, assuming that `d` is a Dict for defining 
your REopt Scenario:
```julia
d["FlexibleHVAC"] = Dict(
    "installed_cost" => 1000.0,
    "doe_reference_name" => "LargeOffice",
    "city" => "LosAngeles",
    "temperature_upper_bound_degC" => 22,
    "temperature_lower_bound_degC" => 18.0,
)
```
When using a built-in FlexibleHVAC model the `doe_reference_name` argument must be provided. The 
climate zone / city will be inferred from the `ElectricLoad` if a `doe_reference_name` is also 
provided in the `ElectricLoad` inputs. Otherwise the `city` argument must be provided. See the 
[ElectricLoad](@ref) docs for the list of possible `doe_reference_name` and `city` values.

!!! note  
    The `ExistingChiller` is electric and so its operating cost is determined by the `ElectricTariff`.

"""
struct FlexibleHVAC
    system_matrix::AbstractMatrix{Float64}  # N x N, with N states (temperatures in RC network)
    input_matrix::AbstractMatrix{Float64}  # N x M, with M inputs
    exogenous_inputs::AbstractMatrix{Float64}  # M x T, with T time steps
    space_temperature_node::Int64
    hvac_input_node::Int64
    initial_temperatures::AbstractVector{Float64}
    temperature_upper_bound_degC_heating::Union{Real, Nothing}
    temperature_lower_bound_degC_heating::Union{Real, Nothing}
    temperature_upper_bound_degC_cooling::Union{Real, Nothing}
    temperature_lower_bound_degC_cooling::Union{Real, Nothing}
    installed_cost::Float64
    bau_hvac::BAU_HVAC
end


"""
    make_bau_hvac(A, B, u, space_temperature_node, hvac_input_node, initial_temperatures, T_hi, T_lo)

Determine the business-as-usual (BAU) energy cost for keeping the building temperature within the
bounds using a discrete-time simulation. The simulation assumes a dead band control by calculating 
what the temperature would be due to the `exogenous_inputs` alone. Then, if the temperature is outside
of the bounds then the energy necessary to make the temperature eqaul to the comfort limit is 
determined and used as the energy consumed in the BAU scenario.

Every model with `FlexibleHVAC` includes a preprocessing step to calculate the business-as-usual (BAU)
cost of meeting the thermal loads using a dead-band controller. The BAU cost is then used in the 
binary decision for purchasing the `FlexibleHVAC` system: if the `FlexibleHVAC` system is purchased then
the heating and cooling costs are determined by the HVAC dispatch that minimizes the lifecycle cost
of energy. If the `FlexibleHVAC` system is not purchased then the BAU heating and cooling costs must
be paid.

The cost of the energy necessary to heat/cool the building is determined by:
1. The `ElectricTariff` for cooling using the `ExistingChiller`; and/or 
2. the `ExistingBoiler.fuel_cost_per_mmbtu` for heating.
"""
function make_bau_hvac(A, B, u, space_temperature_node, hvac_input_node, initial_temperatures, T_hi, T_lo)
    T = size(u, 2)
    N = size(A, 1)

    temperatures = zeros(N, T)
    temperatures[:, 1] .= initial_temperatures

    thermal_kw = Dict(
        "ExistingChiller" => zeros(T),
        "ExistingBoiler" => zeros(T)
    )
    
    for ts in 2:T
        temperatures[:, ts] = A * temperatures[:, ts-1] + B * u[:, ts-1]

        if !isnothing(T_hi) && temperatures[space_temperature_node, ts] > T_hi
            deltaT = temperatures[space_temperature_node, ts] - T_hi
            thermal_kw["ExistingChiller"][ts-1] = deltaT / B[space_temperature_node, hvac_input_node]

            temperatures[:, ts] = 
                A * temperatures[:, ts-1] +
                B * u[:, ts-1] -
                B[:, hvac_input_node] * thermal_kw["ExistingChiller"][ts-1]

        elseif !isnothing(T_lo) && temperatures[space_temperature_node, ts] < T_lo
            deltaT = T_lo - temperatures[space_temperature_node, ts]
            thermal_kw["ExistingBoiler"][ts-1] = deltaT / B[space_temperature_node, hvac_input_node] 

            temperatures[:, ts] = 
                A * temperatures[:, ts-1] +
                B * u[:, ts-1] +
                B[:, hvac_input_node] * thermal_kw["ExistingBoiler"][ts-1]
        end
    end

    return BAU_HVAC(
        thermal_kw["ExistingBoiler"],
        thermal_kw["ExistingChiller"],
        temperatures
    )
end


"""
    FlexibleHVAC(
        doe_reference_name::String,
        city::String,
        installed_cost::Float64,
        temperature_upper_bound_degC_heating::Real,
        temperature_lower_bound_degC_heating::Real,
        temperature_upper_bound_degC_cooling::Real,
        temperature_lower_bound_degC_cooling::Real,
    )

Constructor for `FlexibleHVAC` when using a built-in RC model that has been fit to a DoE Commercial 
Reference Building.

The `city` value is optional and if not provided its value is inferred from the `Site.latitude` and
`Site.longitude` to determine the representative city for the climate zone. 
See the [ElectricLoad](@ref) docs for `city` options.


!!! note
    At least one of the inputs for `temperature_upper_bound_degC` or `temperature_lower_bound_degC`
    must be provided to evaluate the `FlexibleHVAC` option. For example, if only `temperature_lower_bound_degC`
    is provided then only a heating system will be evaluated. Also, the heating system will only be
    used (or purchased) if the `exogenous_inputs` lead to the temperature at the `space_temperature_node` going
    below the `temperature_lower_bound_degC`.

"""
function FlexibleHVAC(
        doe_reference_name::String,
        city::String,
        installed_cost::Real,
        temperature_upper_bound_degC_heating::Union{Real, Nothing},
        temperature_lower_bound_degC_heating::Union{Real, Nothing},
        temperature_upper_bound_degC_cooling::Union{Real, Nothing},
        temperature_lower_bound_degC_cooling::Union{Real, Nothing},
    )

    lib_path = joinpath(dirname(@__FILE__), "..", "..", "data", "rcmodels")
    json_path = joinpath(lib_path, string(city * "_" * doe_reference_name * ".json"))
    rc_dict = JSON.parsefile(json_path)
    rc_dict["installed_cost"] = installed_cost
    rc_dict["temperature_upper_bound_degC_heating"] = temperature_upper_bound_degC_heating
    rc_dict["temperature_lower_bound_degC_heating"] = temperature_lower_bound_degC_heating
    rc_dict["temperature_upper_bound_degC_cooling"] = temperature_upper_bound_degC_cooling
    rc_dict["temperature_lower_bound_degC_cooling"] = temperature_lower_bound_degC_cooling

    FlexibleHVAC(rc_dict)
end


"""
    FlexibleHVAC(dict_from_json::Dict)

Constructor for `FlexibleHVAC` when the inputs have been loaded from a JSON file.

The `dict_from_json` must have all of these keys:
- `system_matrix`
- `input_matrix`
- `exogenous_inputs`
- `space_temperature_node`
- `hvac_input_node`
- `initial_temperatures`
- `temperature_upper_bound_degC_heating`
- `temperature_lower_bound_degC_heating`
- `temperature_upper_bound_degC_cooling`
- `temperature_lower_bound_degC_cooling`
- `installed_cost`

It is assumed that the `system_matrix` and `input_matrix` are each a list-of-lists with inner lists
corresponding to rows of the matrices.

The `exogenous_inputs` is also assumed to be a list-of-lists with inner lists for each input, i.e. the 
second index is the time index.
"""
function FlexibleHVAC(dict_from_json::Dict)
    #=
    When loading in JSON list of lists we get a Vector{Any}, containing more Vector{Any}
    Convert the Vector of Vectors to a Matrix with:
    Matrix(hcat(Vector{Float64}.(<VectorOfVectors-from-JSON>)...))
    =#
    A = Matrix(hcat(Vector{Float64}.(dict_from_json["system_matrix"])...))'
    B = Matrix(hcat(Vector{Float64}.(dict_from_json["input_matrix"])...))'
    u = Matrix(hcat(Vector{Float64}.(dict_from_json["exogenous_inputs"])...))
   
    bau_hvac = make_bau_hvac(A, B, u, 
        dict_from_json["space_temperature_node"], 
        dict_from_json["hvac_input_node"], 
        dict_from_json["initial_temperatures"], 
        dict_from_json["temperature_upper_bound_degC_cooling"], 
        dict_from_json["temperature_lower_bound_degC_heating"]
    )

    FlexibleHVAC(
        A,
        B,
        u,
        dict_from_json["space_temperature_node"],
        dict_from_json["hvac_input_node"],
        dict_from_json["initial_temperatures"],
        dict_from_json["temperature_upper_bound_degC_heating"],
        dict_from_json["temperature_lower_bound_degC_heating"],
        dict_from_json["temperature_upper_bound_degC_cooling"],
        dict_from_json["temperature_lower_bound_degC_cooling"],
        dict_from_json["installed_cost"],
        bau_hvac
    )
end


"""
    function FlexibleHVAC(;
        system_matrix::AbstractMatrix,
        input_matrix::AbstractMatrix,
        exogenous_inputs::AbstractMatrix,
        space_temperature_node::Int64,
        hvac_input_node::Int64,
        initial_temperatures::AbstractVector,
        temperature_upper_bound_degC::Union{Real, Nothing} = nothing,
        temperature_lower_bound_degC::Union{Real, Nothing} = nothing,
        temperature_upper_bound_degC_cooling::Union{Real, Nothing} = nothing,
        temperature_lower_bound_degC_cooling::Union{Real, Nothing} = nothing,
        installed_cost::Float64
    )

Constructor for `FlexibleHVAC` when the `system_matrix`, `input_matrix`, and `exogenous_inputs` values 
are in Matrix format. Note that `exogenous_inputs` is normally a vector but in our case it has a time 
index in the second dimension, which makes it a Matrix as well.
"""
function FlexibleHVAC(;
        system_matrix::AbstractMatrix,
        input_matrix::AbstractMatrix,
        exogenous_inputs::AbstractMatrix,
        space_temperature_node::Int64,
        hvac_input_node::Int64,
        initial_temperatures::AbstractVector,
        temperature_upper_bound_degC_heating::Union{Real, Nothing} = nothing,
        temperature_lower_bound_degC_heating::Union{Real, Nothing} = nothing,
        temperature_upper_bound_degC_cooling::Union{Real, Nothing} = nothing,
        temperature_lower_bound_degC_cooling::Union{Real, Nothing} = nothing,
        installed_cost::Float64
    )

    bau_hvac = make_bau_hvac(system_matrix, input_matrix, exogenous_inputs, space_temperature_node, hvac_input_node,
        initial_temperatures, temperature_upper_bound_degC_cooling, temperature_lower_bound_degC_heating)
    
    FlexibleHVAC(
        system_matrix,
        input_matrix,
        exogenous_inputs,
        space_temperature_node,
        hvac_input_node,
        initial_temperatures,
        temperature_upper_bound_degC_heating,
        temperature_lower_bound_degC_heating,
        temperature_upper_bound_degC_cooling,
        temperature_lower_bound_degC_cooling,
        installed_cost,
        bau_hvac
    )
end
