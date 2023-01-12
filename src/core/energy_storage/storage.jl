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
    mutable struct StorageTypes

Used to store index sets used in decision variables and keys for accessing the various energy 
storage attributes.

Includes inner constructors for `BAUScenario`, `Scenario`, and `MPCScenario`. The constructor for the a
`Scenario` takes in a `Dict{String, AbstractStorage}`

```julia
mutable struct StorageTypes
    all::Vector{String}
    elec::Vector{String}
    thermal::Vector{String}
    hot::Vector{String}
    cold::Vector{String}
    ev::Vector{String}
end
```
"""
mutable struct StorageTypes
    all::Vector{String}
    elec::Vector{String}
    thermal::Vector{String}
    hot::Vector{String}
    cold::Vector{String}
    ev::Vector{String}

    function StorageTypes()
        new(
            String[],
            String[],
            String[],
            String[],
            String[],
            String[],
        )
    end

    function StorageTypes(d::Dict{String, AbstractStorage})
        all_storage = String[]
        elec_storage = String[]
        hot_storage = String[]
        cold_storage = String[]
        ev = String[]

        for (k,v) in d
            if v.max_kw > 0.0 && v.max_kwh > 0.0

                push!(all_storage, k)

                if typeof(v) <: AbstractElectricStorage
                    push!(elec_storage, k)
                    # EV's are of type AbstractElectricStorage too, but also electric_vehicle attribute (and "EV" in v.name)
                    if !isnothing(v.electric_vehicle)  # Alternatively could check for "EV" in v.name
                        push!(ev, k)
                    end
                elseif typeof(v) <: ThermalStorage
                    if occursin("Hot", k)
                        push!(hot_storage, k)
                    elseif occursin("Cold", k)
                        push!(cold_storage, k)
                    else
                        throw(@error("Thermal Storage not labeled as Hot or Cold."))
                    end
                end
            end
        end

        thermal_storage = union(hot_storage, cold_storage)

        new(
            all_storage,
            elec_storage,
            thermal_storage,
            hot_storage,
            cold_storage,
            ev
        )
    end
end


struct Storage
    types::StorageTypes
    attr::Dict{String, AbstractStorage}

    """
        Storage()

    Create an empty `Storage` struct. Used in `BAUScenario`.
    """
    function Storage()

        new(
            StorageTypes(),
            Dict{String, AbstractStorage}()
        )

    end

    """
        Storage(d::Dict{String, AbstractStorage})

    
    """
    function Storage(d::Dict{String, AbstractStorage})
        types = StorageTypes(d)
        new(
            types,
            d
        )
    end
end
