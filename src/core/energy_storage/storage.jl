# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

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
    dc_coupled::Vector{String}
    ac_coupled::Vector{String}
end
```
"""
mutable struct StorageTypes
    all::Vector{String}
    elec::Vector{String}
    thermal::Vector{String}
    hot::Vector{String}
    cold::Vector{String}
    dc_coupled::Vector{String}
    ac_coupled::Vector{String}

    function StorageTypes()
        new(
            String[],
            String[],
            String[],
            String[],
            String[],
            String[],
            String[]
        )
    end

    function StorageTypes(d::Dict{String, AbstractStorage})
        all_storage = String[]
        elec_storage = String[]
        hot_storage = String[]
        cold_storage = String[]
        dc_coupled = String[]
        ac_coupled = String[]

        for (k,v) in d
            if v.max_kw > 0.0 && v.max_kwh > 0.0

                push!(all_storage, k)

                if typeof(v) <: AbstractElectricStorage
                    push!(elec_storage, k)
                    if v.dc_coupled
                        push!(dc_coupled, k)
                    else
                        push!(ac_coupled, k)
                    end
                elseif typeof(v) <: HotThermalStorage
                    push!(hot_storage, k)
                elseif typeof(v) <: ColdThermalStorage
                    push!(cold_storage, k)
                else
                    throw(@error("Storage not labeled as Hot or Cold, or Electric."))
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
            dc_coupled,
            ac_coupled
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
