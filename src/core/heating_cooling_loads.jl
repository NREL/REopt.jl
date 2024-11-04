# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
`DomesticHotWaterLoad` is an optional REopt input with the following keys and default values:
```julia
    doe_reference_name::String = "",
    blended_doe_reference_names::Array{String, 1} = String[],
    blended_doe_reference_percents::Array{<:Real,1} = Real[],
    addressable_load_fraction::Any = 1.0,  # Fraction of input fuel load which is addressable by heating technologies. Can be a scalar or vector with length aligned with use of monthly_mmbtu or fuel_loads_mmbtu_per_hour.
    annual_mmbtu::Union{Real, Nothing} = nothing,
    monthly_mmbtu::Array{<:Real,1} = Real[],
    fuel_loads_mmbtu_per_hour::Array{<:Real,1} = Real[], # Vector of hot water fuel loads [mmbtu/hour]. Length must equal 8760 * `Settings.time_steps_per_hour`
    existing_boiler_efficiency::Real = NaN
```

There are many ways in which a DomesticHotWaterLoad can be defined:
1. When using either `doe_reference_name` or `blended_doe_reference_names` in an `ElectricLoad` one only needs to provide the input key "DomesticHotWaterLoad" in the `Scenario` (JSON or Dict). In this case the values from DoE reference names from the `ElectricLoad` will be used to define the `DomesticHotWaterLoad`.
2. One can provide the `doe_reference_name` or `blended_doe_reference_names` directly in the `DomesticHotWaterLoad` key within the `Scenario`. These values can be combined with the `annual_mmbtu` or `monthly_mmbtu` inputs to scale the DoE reference profile(s).
3. One can provide the `fuel_loads_mmbtu_per_hour` value in the `DomesticHotWaterLoad` key within the `Scenario`.

!!! note "Hot water loads"
    Hot water, space heating, and process heat thermal "load" inputs are in terms of energy input required (boiler fuel), 
    not the actual energy demand. The fuel energy is multiplied by the existing_boiler_efficiency to get the actual energy 
    demand.

"""
struct DomesticHotWaterLoad
    loads_kw::Array{Real, 1}
    annual_mmbtu::Real
    unaddressable_annual_fuel_mmbtu::Real

    function DomesticHotWaterLoad(;
        doe_reference_name::String = "",
        city::String = "",
        blended_doe_reference_names::Array{String, 1} = String[],
        blended_doe_reference_percents::Array{<:Real,1} = Real[],
        annual_mmbtu::Union{Real, Nothing} = nothing,
        monthly_mmbtu::Array{<:Real,1} = Real[],
        addressable_load_fraction::Any = 1.0,
        fuel_loads_mmbtu_per_hour::Array{<:Real,1} = Real[],
        time_steps_per_hour::Int = 1, # corresponding to `fuel_loads_mmbtu_per_hour`
        latitude::Real = 0.0,
        longitude::Real = 0.0,
        existing_boiler_efficiency::Real = NaN
    )

        if length(addressable_load_fraction) > 1
            if !isempty(fuel_loads_mmbtu_per_hour) && length(addressable_load_fraction) != length(fuel_loads_mmbtu_per_hour)
                throw(@error("`addressable_load_fraction` must be a scalar or an array of length `fuel_loads_mmbtu_per_hour`"))
            end
            if !isempty(monthly_mmbtu) && length(addressable_load_fraction) != 12
                throw(@error("`addressable_load_fraction` must be a scalar or an array of length 12 if `monthly_mmbtu` is input"))
            end
            addressable_load_fraction = convert(Vector{Real}, addressable_load_fraction)
        elseif typeof(addressable_load_fraction) <: Vector{}
            addressable_load_fraction = convert(Real, addressable_load_fraction[1])            
        else
            addressable_load_fraction = convert(Real, addressable_load_fraction)
        end
    
        if length(fuel_loads_mmbtu_per_hour) > 0

            if !(length(fuel_loads_mmbtu_per_hour) / time_steps_per_hour ≈ 8760)
                throw(@error("Provided DomesticHotWaterLoad `fuel_loads_mmbtu_per_hour` does not match the time_steps_per_hour."))
            end

            loads_kw = fuel_loads_mmbtu_per_hour .* (KWH_PER_MMBTU * existing_boiler_efficiency) .* addressable_load_fraction
            unaddressable_annual_fuel_mmbtu = sum(fuel_loads_mmbtu_per_hour .* (1 .- addressable_load_fraction)) / time_steps_per_hour

            if !isempty(doe_reference_name) || length(blended_doe_reference_names) > 0
                @warn "DomesticHotWaterLoad `fuel_loads_mmbtu_per_hour` was provided, so doe_reference_name and/or blended_doe_reference_names will be ignored."
            end

        elseif !isempty(doe_reference_name)
            loads_kw = BuiltInDomesticHotWaterLoad(city, doe_reference_name, latitude, longitude, 2017, addressable_load_fraction, annual_mmbtu, monthly_mmbtu, existing_boiler_efficiency)
            if length(blended_doe_reference_names) > 0
                @warn "DomesticHotWaterLoad doe_reference_name was provided, so blended_doe_reference_names will be ignored."
            end
            unaddressable_annual_fuel_mmbtu = get_unaddressable_fuel(addressable_load_fraction, annual_mmbtu, monthly_mmbtu, loads_kw, existing_boiler_efficiency)
        elseif length(blended_doe_reference_names) > 0 && 
            length(blended_doe_reference_names) == length(blended_doe_reference_percents)
            loads_kw = blend_and_scale_doe_profiles(BuiltInDomesticHotWaterLoad, latitude, longitude, 2017, 
                                                    blended_doe_reference_names, blended_doe_reference_percents, city, 
                                                    annual_mmbtu, monthly_mmbtu, addressable_load_fraction,
                                                    existing_boiler_efficiency)
            unaddressable_annual_fuel_mmbtu = get_unaddressable_fuel(addressable_load_fraction, annual_mmbtu, monthly_mmbtu, loads_kw, existing_boiler_efficiency)
        else
            throw(@error("Cannot construct DomesticHotWaterLoad. You must provide either [fuel_loads_mmbtu_per_hour], 
                [doe_reference_name, city], or [blended_doe_reference_names, blended_doe_reference_percents, city]."))
        end

        if length(loads_kw) < 8760*time_steps_per_hour
            loads_kw = repeat(loads_kw, inner=Int(time_steps_per_hour / (length(loads_kw)/8760)))
            @warn "Repeating domestic hot water loads in each hour to match the time_steps_per_hour."
        end

        new(
            loads_kw,
            (sum(loads_kw)/time_steps_per_hour)/KWH_PER_MMBTU,
            unaddressable_annual_fuel_mmbtu
        )
    end
end


"""
`SpaceHeatingLoad` is an optional REopt input with the following keys and default values:
```julia
    doe_reference_name::String = "",
    blended_doe_reference_names::Array{String, 1} = String[],
    blended_doe_reference_percents::Array{<:Real,1} = Real[],
    addressable_load_fraction::Any = 1.0,  # Fraction of input fuel load which is addressable by heating technologies. Can be a scalar or vector with length aligned with use of monthly_mmbtu or fuel_loads_mmbtu_per_hour.
    annual_mmbtu::Union{Real, Nothing} = nothing,
    monthly_mmbtu::Array{<:Real,1} = Real[],
    fuel_loads_mmbtu_per_hour::Array{<:Real,1} = Real[], # Vector of space heating fuel loads [mmbtu/hr]. Length must equal 8760 * `Settings.time_steps_per_hour`
    existing_boiler_efficiency::Real = NaN
```

There are many ways to define a `SpaceHeatingLoad`:
1. a time-series via the `fuel_loads_mmbtu_per_hour`,
2. scaling a DoE Commercial Reference Building (CRB) profile or a blend of CRB profiles to either the `annual_mmbtu` or `monthly_mmbtu` values;
3. or using the `doe_reference_name` or `blended_doe_reference_names` from the `ElectricLoad`.

When using an `ElectricLoad` defined from a `doe_reference_name` or `blended_doe_reference_names` 
one only needs to provide an empty Dict in the scenario JSON to add a `SpaceHeatingLoad` to a 
`Scenario`, i.e.:
```json
...
"ElectricLoad": {"doe_reference_name": "MidriseApartment"},
"SpaceHeatingLoad" : {},
...
```
In this case the values provided for `doe_reference_name`, or  `blended_doe_reference_names` and 
`blended_doe_reference_percents` are copied from the `ElectricLoad` to the `SpaceHeatingLoad`.

!!! note "Space heating loads"
    Hot water, space heating, and process heat thermal "load" inputs are in terms of energy input required (boiler fuel), 
    not the actual energy demand. The fuel energy is multiplied by the existing_boiler_efficiency to get the actual energy 
    emand.
"""
struct SpaceHeatingLoad
    loads_kw::Array{Real, 1}
    annual_mmbtu::Real
    unaddressable_annual_fuel_mmbtu::Real

    function SpaceHeatingLoad(;
        doe_reference_name::String = "",
        city::String = "",
        blended_doe_reference_names::Array{String, 1} = String[],
        blended_doe_reference_percents::Array{<:Real,1} = Real[],
        annual_mmbtu::Union{Real, Nothing} = nothing,
        monthly_mmbtu::Array{<:Real,1} = Real[],
        addressable_load_fraction::Any = 1.0,
        fuel_loads_mmbtu_per_hour::Array{<:Real,1} = Real[],
        time_steps_per_hour::Int = 1, # corresponding to `fuel_loads_mmbtu_per_hour`
        latitude::Real = 0.0,
        longitude::Real = 0.0,
        existing_boiler_efficiency::Real = NaN
    )

        if length(addressable_load_fraction) > 1
            if !isempty(fuel_loads_mmbtu_per_hour) && length(addressable_load_fraction) != length(fuel_loads_mmbtu_per_hour)
                throw(@error("`addressable_load_fraction` must be a scalar or an array of length `fuel_loads_mmbtu_per_hour`"))
            end
            if !isempty(monthly_mmbtu) && length(addressable_load_fraction) != 12
                throw(@error("`addressable_load_fraction` must be a scalar or an array of length 12 if `monthly_mmbtu` is input"))
            end
            addressable_load_fraction = convert(Vector{Real}, addressable_load_fraction)
        elseif typeof(addressable_load_fraction) <: Vector{}
            addressable_load_fraction = convert(Real, addressable_load_fraction[1])  
        else
            addressable_load_fraction = convert(Real, addressable_load_fraction)            
        end

        if length(fuel_loads_mmbtu_per_hour) > 0

            if !(length(fuel_loads_mmbtu_per_hour) / time_steps_per_hour ≈ 8760)
                throw(@error("Provided space heating load does not match the time_steps_per_hour."))
            end

            loads_kw = fuel_loads_mmbtu_per_hour .* (KWH_PER_MMBTU * existing_boiler_efficiency) .* addressable_load_fraction
            unaddressable_annual_fuel_mmbtu = sum(fuel_loads_mmbtu_per_hour .* (1 .- addressable_load_fraction))  / time_steps_per_hour

            if !isempty(doe_reference_name) || length(blended_doe_reference_names) > 0
                @warn "SpaceHeatingLoad fuel_loads_mmbtu_per_hour was provided, so doe_reference_name and/or blended_doe_reference_names will be ignored."
            end

        elseif !isempty(doe_reference_name)
            loads_kw = BuiltInSpaceHeatingLoad(city, doe_reference_name, latitude, longitude, 2017, addressable_load_fraction, annual_mmbtu, monthly_mmbtu, existing_boiler_efficiency)
            if length(blended_doe_reference_names) > 0
                @warn "SpaceHeatingLoad doe_reference_name was provided, so blended_doe_reference_names will be ignored."
            end
            unaddressable_annual_fuel_mmbtu = get_unaddressable_fuel(addressable_load_fraction, annual_mmbtu, monthly_mmbtu, loads_kw, existing_boiler_efficiency)           
        elseif length(blended_doe_reference_names) > 0 && 
            length(blended_doe_reference_names) == length(blended_doe_reference_percents)
            loads_kw = blend_and_scale_doe_profiles(BuiltInSpaceHeatingLoad, latitude, longitude, 2017, 
                                                    blended_doe_reference_names, blended_doe_reference_percents, city, 
                                                    annual_mmbtu, monthly_mmbtu, addressable_load_fraction,
                                                    existing_boiler_efficiency)
            unaddressable_annual_fuel_mmbtu = get_unaddressable_fuel(addressable_load_fraction, annual_mmbtu, monthly_mmbtu, loads_kw, existing_boiler_efficiency)                                                   
        else
            throw(@error("Cannot construct BuiltInSpaceHeatingLoad. You must provide either [fuel_loads_mmbtu_per_hour], 
                [doe_reference_name, city], or [blended_doe_reference_names, blended_doe_reference_percents, city]."))
        end

        if length(loads_kw) < 8760*time_steps_per_hour
            loads_kw = repeat(loads_kw, inner=Int(time_steps_per_hour / (length(loads_kw)/8760)))
            @warn "Repeating space heating loads in each hour to match the time_steps_per_hour."
        end

        new(
            loads_kw,
            (sum(loads_kw)/time_steps_per_hour)/KWH_PER_MMBTU,
            unaddressable_annual_fuel_mmbtu
        )
    end
end

"""
function get_existing_chiller_default_cop(; existing_chiller_max_thermal_factor_on_peak_load=nothing, 
                                            max_load_kw=nothing, 
                                            max_load_kw_thermal=nothing)
This function returns the default value for ExistingChiller.cop based on:
    1. No information about load, returns average of lower and higher cop default values (`cop_unknown_thermal`)
    2. If the cooling electric `max_load_kw` is known, we first guess the thermal load profile using `cop_unknown_thermal`,
        and then we use the default logic to determine the `existing_chiller_cop` based on the peak thermal load with a thermal factor multiplier.
    3. If the cooling thermal `max_load_kw_thermal` is known, same as 2. but we don't have to guess the cop to convert electric to thermal load first.
"""
function get_existing_chiller_default_cop(; existing_chiller_max_thermal_factor_on_peak_load=nothing, max_load_kw=nothing, max_load_kw_thermal=nothing)
    cop_less_than_100_ton = 4.40
    cop_more_than_100_ton = 4.69
    cop_unknown_thermal = (cop_less_than_100_ton + cop_more_than_100_ton) / 2.0
    max_cooling_load_ton = nothing
    if !isnothing(max_load_kw_thermal)
        max_cooling_load_ton = max_load_kw_thermal / KWH_THERMAL_PER_TONHOUR
    elseif !isnothing(max_load_kw)
        max_cooling_load_ton = max_load_kw / KWH_THERMAL_PER_TONHOUR * cop_unknown_thermal
    end
    if isnothing(max_cooling_load_ton) || isnothing(existing_chiller_max_thermal_factor_on_peak_load)
        return cop_unknown_thermal
    elseif max_cooling_load_ton * existing_chiller_max_thermal_factor_on_peak_load < 100.0
        return cop_less_than_100_ton
    else
        return cop_more_than_100_ton
    end
end

"""
`CoolingLoad` is an optional REopt input with the following keys and default values:
```julia
    doe_reference_name::String = "",
    city::String = "",
    blended_doe_reference_names::Array{String, 1} = String[],
    blended_doe_reference_percents::Array{<:Real,1} = Real[],
    annual_tonhour::Union{Real, Nothing} = nothing,
    monthly_tonhour::Array{<:Real,1} = Real[],
    thermal_loads_ton::Array{<:Real,1} = Real[], # Vector of cooling thermal loads [ton] = [short ton hours/hour]. Length must equal 8760 * `Settings.time_steps_per_hour`
    annual_fraction_of_electric_load::Union{Real, Nothing} = nothing, # Fraction of total electric load that is used for cooling 
    monthly_fractions_of_electric_load::Array{<:Real,1} = Real[],
    per_time_step_fractions_of_electric_load::Array{<:Real,1} = Real[]
```


There are many ways to define a `CoolingLoad`:
1. a time-series via the `thermal_loads_ton`,
2. DoE Commercial Reference Building (CRB) profile or a blend of CRB profiles which uses the buildings' fraction of total electric for cooling profile applied to the `ElectricLoad`
3. scaling a DoE Commercial Reference Building (CRB) profile or a blend of CRB profiles using `annual_tonhour` or `monthly_tonhour`
4. the `annual_fraction_of_electric_load`, `monthly_fractions_of_electric_load`, or `per_time_step_fractions_of_electric_load` values, which get applied to the `ElectricLoad` to determine the cooling electric load;
5. or using the `doe_reference_name` or `blended_doe_reference_names` from the `ElectricLoad`.

The electric-based `loads_kw` of the `CoolingLoad` is a _subset_ of the total electric load `ElectricLoad`, so `CoolingLoad.loads_kw` for the BAU/conventional electric consumption of the `existing_chiller` is subtracted from the `ElectricLoad` for the non-cooling electric load balance constraint in the model. 

When using an `ElectricLoad` defined from a `doe_reference_name` or `blended_doe_reference_names` 
one only needs to provide an empty Dict in the scenario JSON to add a `CoolingLoad` to a 
`Scenario`, i.e.:
```json
...
"ElectricLoad": {"doe_reference_name": "MidriseApartment"},
"CoolingLoad" : {},
...
```
In this case the values provided for `doe_reference_name`, or  `blended_doe_reference_names` and 
`blended_doe_reference_percents` are copied from the `ElectricLoad` to the `CoolingLoad`.
"""

struct CoolingLoad
    loads_kw_thermal::Array{Real, 1}
    existing_chiller_cop::Real

    function CoolingLoad(;
        doe_reference_name::String = "",
        city::String = "",
        blended_doe_reference_names::Array{String, 1} = String[],
        blended_doe_reference_percents::Array{<:Real,1} = Real[],
        annual_tonhour::Union{Real, Nothing} = nothing,
        monthly_tonhour::Array{<:Real,1} = Real[],
        thermal_loads_ton::Array{<:Real,1} = Real[], # Vector of cooling thermal loads [ton] = [short ton hours/hour]. Length must equal 8760 * `Settings.time_steps_per_hour`
        annual_fraction_of_electric_load::Union{Real, Nothing} = nothing, # Fraction of total electric load that is used for cooling
        monthly_fractions_of_electric_load::Array{<:Real,1} = Real[],
        per_time_step_fractions_of_electric_load::Array{<:Real,1} = Real[],
        site_electric_load_profile = Real[],
        time_steps_per_hour::Int = 1,
        latitude::Float64=0.0,
        longitude::Float64=0.0,
        existing_chiller_cop::Union{Real, Nothing} = nothing, # Passed from ExistingChiller or set to a default
        existing_chiller_max_thermal_factor_on_peak_load::Union{Real, Nothing}= nothing # Passed from ExistingChiller or set to a default
    )
        # determine the timeseries of loads_kw_thermal
        loads_kw_thermal = nothing
        loads_kw = nothing
        if length(thermal_loads_ton) > 0
            if !(length(thermal_loads_ton) / time_steps_per_hour ≈ 8760)
                throw(@error("Provided cooling load does not match the time_steps_per_hour."))
            end
            loads_kw_thermal = thermal_loads_ton .* (KWH_THERMAL_PER_TONHOUR)
        
        elseif !isempty(per_time_step_fractions_of_electric_load) && (length(site_electric_load_profile) / time_steps_per_hour ≈ 8760)
            if !(length(per_time_step_fractions_of_electric_load) / time_steps_per_hour ≈ 8760)
                throw(@error("Provided cooling per_time_step_fractions_of_electric_load array does not match the time_steps_per_hour."))
            end
            loads_kw = per_time_step_fractions_of_electric_load .* site_electric_load_profile
        
        elseif !isempty(monthly_fractions_of_electric_load) && (length(site_electric_load_profile) / time_steps_per_hour ≈ 8760)
            if !(length(monthly_fractions_of_electric_load) ≈ 12)
                throw(@error("Provided cooling monthly_fractions_of_electric_load array does not have 12 values."))
            end
            timeseries = collect(DateTime(2017,1,1) : Minute(60/time_steps_per_hour) : 
                                 DateTime(2017,1,1) + Minute(8760*60 - 60/time_steps_per_hour))
            loads_kw = [monthly_fractions_of_electric_load[month(dt)] * site_electric_load_profile[ts] for (ts, dt) 
                        in enumerate(timeseries)]
        
        elseif !isnothing(annual_fraction_of_electric_load) && (length(site_electric_load_profile) / time_steps_per_hour ≈ 8760)
            loads_kw = annual_fraction_of_electric_load * site_electric_load_profile
        
        elseif !isempty(doe_reference_name)
            if isnothing(annual_tonhour) && isempty(monthly_tonhour)
                loads_kw = get_default_fraction_of_total_electric(city, doe_reference_name, 
                                            latitude, longitude, 2017) .* site_electric_load_profile
            else
                loads_kw = BuiltInCoolingLoad(city, doe_reference_name, latitude, longitude, 2017, 
                                          annual_tonhour, monthly_tonhour, existing_chiller_cop)
            end
        
        elseif length(blended_doe_reference_names) > 1 && 
            length(blended_doe_reference_names) == length(blended_doe_reference_percents)
            if isnothing(annual_tonhour) && isempty(monthly_tonhour)
                loads_kw = zeros(Int(8760/time_steps_per_hour))
                for (i, building) in enumerate(blended_doe_reference_names)
                    default_fraction = get_default_fraction_of_total_electric(city, building, latitude, longitude, 2017)
                    modified_fraction = default_fraction * blended_doe_reference_percents[i]
                    if length(site_electric_load_profile) > 8784
                        modified_fraction = repeat(modified_fraction, inner=time_steps_per_hour / (length(site_electric_load_profile)/8760))
                        @warn "Repeating cooling electric load in each hour to match the time_steps_per_hour."
                    end
                    loads_kw += site_electric_load_profile .* modified_fraction
                end
            else            
                loads_kw = blend_and_scale_doe_profiles(BuiltInCoolingLoad, latitude, longitude, 2017, 
                                                        blended_doe_reference_names, 
                                                        blended_doe_reference_percents, city, 
                                                        annual_tonhour, monthly_tonhour)
            end
        
        else
            throw(@error("Cannot construct BuiltInCoolingLoad. You must provide either [thermal_loads_ton], 
                [doe_reference_name, city], [blended_doe_reference_names, blended_doe_reference_percents, city],
                or the site_electric_load_profile along with one of [per_time_step_fractions_of_electric_load, monthly_fractions_of_electric_load, annual_fraction_of_electric_load]."))
        end

        if isnothing(loads_kw_thermal)  # have to convert electric loads_kw to thermal load
            if (!isnothing(annual_tonhour) || !isempty(monthly_tonhour)) && isnothing(existing_chiller_cop)
                # cop_unknown_thermal (4.55) was used to convert thermal to electric in BuiltInCoolingLoad, so need to use the same here to convert back
                #  in order to preserve the input tonhour amounts - however, the updated/actual existing_chiller_cop is still assigned based on user input or actual max ton load conditional defaults
                chiller_cop = get_existing_chiller_default_cop()
            elseif (!isempty(doe_reference_name) || !isempty(blended_doe_reference_names)) || isnothing(existing_chiller_cop)
                # Generated loads_kw (electric) above based on the building's default fraction of electric profile
                chiller_cop = get_existing_chiller_default_cop(;existing_chiller_max_thermal_factor_on_peak_load=existing_chiller_max_thermal_factor_on_peak_load, 
                                        max_load_kw=maximum(loads_kw))
            else
                chiller_cop = existing_chiller_cop
            end
            loads_kw_thermal = chiller_cop * loads_kw
        end

        # Now that cooling thermal loads_kw_thermal is known, update existing_chiller_cop if it was not input
        if isnothing(existing_chiller_cop)
            existing_chiller_cop = get_existing_chiller_default_cop(;existing_chiller_max_thermal_factor_on_peak_load=existing_chiller_max_thermal_factor_on_peak_load, 
                                        max_load_kw_thermal=maximum(loads_kw_thermal))
        end

        if length(loads_kw_thermal) < 8760*time_steps_per_hour
            loads_kw_thermal = repeat(loads_kw_thermal, inner=Int(time_steps_per_hour / 
                               (length(loads_kw_thermal)/8760)))
            @warn "Repeating cooling loads in each hour to match the time_steps_per_hour."
        end

        new(
            loads_kw_thermal,
            existing_chiller_cop
        )
    end
end

function get_default_fraction_of_total_electric(city, doe_reference_name, latitude, longitude, year)
    crb_total_elec_loads_kw = BuiltInElectricLoad(city, doe_reference_name, latitude, longitude, year)

    crb_cooling_elec_loads_kw = BuiltInCoolingLoad(city, doe_reference_name, latitude, longitude, year, nothing, Real[], nothing)
    
    default_fraction_of_total_electric_profile = crb_cooling_elec_loads_kw ./
                                                    max.(crb_total_elec_loads_kw, repeat([1.0E-6], length(crb_total_elec_loads_kw)))
    return default_fraction_of_total_electric_profile
end


function BuiltInDomesticHotWaterLoad(
    city::String,
    buildingtype::String,
    latitude::Real,
    longitude::Real,
    year::Int,
    addressable_load_fraction::Union{<:Real, AbstractVector{<:Real}},
    annual_mmbtu::Union{Real, Nothing}=nothing,
    monthly_mmbtu::Vector{<:Real}=Real[],
    existing_boiler_efficiency::Union{Real, Nothing}=nothing
    )
    dhw_annual_mmbtu = Dict(
        "Miami" => Dict(
            "FastFoodRest" => 53.47209411,
            "FullServiceRest" => 158.0518043,
            "Hospital" => 442.7295435,
            "LargeHotel" => 3713.248373,
            "LargeOffice" => 127.9412792,
            "MediumOffice" => 22.09603477,
            "MidriseApartment" => 158.0580017,
            "Outpatient" => 27.60091429,
            "PrimarySchool" => 105.3179165,
            "RetailStore" => 0.0,
            "SecondarySchool" => 250.1299246,
            "SmallHotel" => 242.232695,
            "SmallOffice" => 9.891779415,
            "StripMall" => 0.0,
            "Supermarket" => 17.94985187,
            "Warehouse" => 0.0,
            "FlatLoad" => 333.0450133
        ),
        "Houston" => Dict(
            "FastFoodRest" => 62.56835989,
            "FullServiceRest" => 188.292814,
            "Hospital" => 530.6352726,
            "LargeHotel" => 4685.666667,
            "LargeOffice" => 160.8917808,
            "MediumOffice" => 25.9266894,
            "MidriseApartment" => 199.2544784,
            "Outpatient" => 32.87691943,
            "PrimarySchool" => 128.0705362,
            "RetailStore" => 0.0,
            "SecondarySchool" => 314.7654465,
            "SmallHotel" => 290.6293673,
            "SmallOffice" => 10.27839347,
            "StripMall" => 0.0,
            "Supermarket" => 19.86608717,
            "Warehouse" => 0.0,
            "FlatLoad" => 415.6076756
        ),
        "Phoenix" => Dict(
            "FastFoodRest" => 57.34025418,
            "FullServiceRest" => 170.9086319,
            "Hospital" => 480.098265,
            "LargeHotel" => 4127.191046,
            "LargeOffice" => 141.8507451,
            "MediumOffice" => 23.71397275,
            "MidriseApartment" => 175.5949563,
            "Outpatient" => 29.83372212,
            "PrimarySchool" => 116.811664,
            "RetailStore" => 0.0,
            "SecondarySchool" => 285.2339344,
            "SmallHotel" => 262.8487714,
            "SmallOffice" => 10.05557471,
            "StripMall" => 0.0,
            "Supermarket" => 18.7637822,
            "Warehouse" => 0.0,
            "FlatLoad" => 368.7653325
        ),
        "Atlanta" => Dict(
            "FastFoodRest" => 71.33170579,
            "FullServiceRest" => 217.4332205,
            "Hospital" => 615.3498557,
            "LargeHotel" => 5622.340656,
            "LargeOffice" => 192.7164525,
            "MediumOffice" => 29.62182675,
            "MidriseApartment" => 238.9315749,
            "Outpatient" => 37.9759973,
            "PrimarySchool" => 148.8362119,
            "RetailStore" => 0.0,
            "SecondarySchool" => 372.2083434,
            "SmallHotel" => 337.2688069,
            "SmallOffice" => 10.65138846,
            "StripMall" => 0.0,
            "Supermarket" => 21.71038069,
            "Warehouse" => 0.0,
            "FlatLoad" => 494.7735263
        ),
        "LasVegas" => Dict(
            "FastFoodRest" => 63.63848459,
            "FullServiceRest" => 191.8494897,
            "Hospital" => 540.9697668,
            "LargeHotel" => 4800.331564,
            "LargeOffice" => 164.7154124,
            "MediumOffice" => 26.36796732,
            "MidriseApartment" => 204.1120165,
            "Outpatient" => 33.48190098,
            "PrimarySchool" => 131.9651451,
            "RetailStore" => 0.0,
            "SecondarySchool" => 327.441087,
            "SmallHotel" => 296.3578765,
            "SmallOffice" => 10.32392915,
            "StripMall" => 0.0,
            "Supermarket" => 20.08676069,
            "Warehouse" => 0.0,
            "FlatLoad" => 425.7275876
        ),
        "LosAngeles" => Dict(
            "FastFoodRest" => 69.63212501,
            "FullServiceRest" => 211.7827529,
            "Hospital" => 598.9350422,
            "LargeHotel" => 5440.174033,
            "LargeOffice" => 186.6199083,
            "MediumOffice" => 28.91483286,
            "MidriseApartment" => 231.215325,
            "Outpatient" => 37.00823296,
            "PrimarySchool" => 142.8059487,
            "RetailStore" => 0.0,
            "SecondarySchool" => 352.7467563,
            "SmallHotel" => 328.1935523,
            "SmallOffice" => 10.58011717,
            "StripMall" => 0.0,
            "Supermarket" => 21.35337379,
            "Warehouse" => 0.0,
            "FlatLoad" => 478.7476251
        ),
        "SanFrancisco" => Dict(
            "FastFoodRest" => 77.13092952,
            "FullServiceRest" => 236.7180594,
            "Hospital" => 671.40531,
            "LargeHotel" => 6241.842643,
            "LargeOffice" => 213.8445094,
            "MediumOffice" => 32.07909301,
            "MidriseApartment" => 265.1697301,
            "Outpatient" => 41.35500136,
            "PrimarySchool" => 160.4507431,
            "RetailStore" => 0.0,
            "SecondarySchool" => 401.395655,
            "SmallHotel" => 368.0979112,
            "SmallOffice" => 10.90004379,
            "StripMall" => 0.0,
            "Supermarket" => 22.9292287,
            "Warehouse" => 0.0,
            "FlatLoad" => 546.4574286
        ),
        "Baltimore" => Dict(
            "FastFoodRest" => 78.2191761,
            "FullServiceRest" => 240.338156,
            "Hospital" => 681.9322322,
            "LargeHotel" => 6358.710286,
            "LargeOffice" => 217.7306132,
            "MediumOffice" => 32.52815422,
            "MidriseApartment" => 270.1195541,
            "Outpatient" => 41.96148216,
            "PrimarySchool" => 165.3116185,
            "RetailStore" => 0.0,
            "SecondarySchool" => 417.9512972,
            "SmallHotel" => 373.906416,
            "SmallOffice" => 10.94554028,
            "StripMall" => 0.0,
            "Supermarket" => 23.15795696,
            "Warehouse" => 0.0,
            "FlatLoad" => 557.0507802
        ),
        "Albuquerque" => Dict(
            "FastFoodRest" => 76.9149868,
            "FullServiceRest" => 235.9992545,
            "Hospital" => 669.3128607,
            "LargeHotel" => 6219.08303,
            "LargeOffice" => 212.9944774,
            "MediumOffice" => 31.97726287,
            "MidriseApartment" => 264.2063457,
            "Outpatient" => 41.20639013,
            "PrimarySchool" => 162.1556119,
            "RetailStore" => 0.0,
            "SecondarySchool" => 409.1649863,
            "SmallHotel" => 366.9712928,
            "SmallOffice" => 10.88949351,
            "StripMall" => 0.0,
            "Supermarket" => 22.88525618,
            "Warehouse" => 0.0,
            "FlatLoad" => 545.235078
        ),
        "Seattle" => Dict(
            "FastFoodRest" => 81.80231236,
            "FullServiceRest" => 252.2609525,
            "Hospital" => 716.6111323,
            "LargeHotel" => 6741.736717,
            "LargeOffice" => 230.8057849,
            "MediumOffice" => 34.04746055,
            "MidriseApartment" => 286.3412104,
            "Outpatient" => 44.07342164,
            "PrimarySchool" => 172.0233322,
            "RetailStore" => 0.0,
            "SecondarySchool" => 434.0806311,
            "SmallHotel" => 392.968915,
            "SmallOffice" => 11.09863592,
            "StripMall" => 0.0,
            "Supermarket" => 23.91178737,
            "Warehouse" => 0.0,
            "FlatLoad" => 588.8601433
        ),
        "Chicago" => Dict(
            "FastFoodRest" => 84.2645196,
            "FullServiceRest" => 260.4454844,
            "Hospital" => 740.4172516,
            "LargeHotel" => 7005.083356,
            "LargeOffice" => 239.7065959,
            "MediumOffice" => 35.08184587,
            "MidriseApartment" => 297.4938584,
            "Outpatient" => 45.49600079,
            "PrimarySchool" => 179.4639347,
            "RetailStore" => 0.0,
            "SecondarySchool" => 456.8817409,
            "SmallHotel" => 406.0751832,
            "SmallOffice" => 11.2033023,
            "StripMall" => 0.0,
            "Supermarket" => 24.4292392,
            "Warehouse" => 0.0,
            "FlatLoad" => 611.6276445
        ),
        "Boulder" => Dict(
            "FastFoodRest" => 83.95201542,
            "FullServiceRest" => 259.3997752,
            "Hospital" => 737.372005,
            "LargeHotel" => 6971.32924,
            "LargeOffice" => 238.572519,
            "MediumOffice" => 34.9486709,
            "MidriseApartment" => 296.06471,
            "Outpatient" => 45.31437164,
            "PrimarySchool" => 178.3378526,
            "RetailStore" => 0.0,
            "SecondarySchool" => 453.228537,
            "SmallHotel" => 404.4154946,
            "SmallOffice" => 11.18970855,
            "StripMall" => 0.0,
            "Supermarket" => 24.36505320,
            "Warehouse" => 0.0,
            "FlatLoad" => 608.6556221
        ),
        "Minneapolis" => Dict(
            "FastFoodRest" => 89.48929949,
            "FullServiceRest" => 277.8184269,
            "Hospital" => 790.9262388,
            "LargeHotel" => 7563.607619,
            "LargeOffice" => 258.6874644,
            "MediumOffice" => 37.28641454,
            "MidriseApartment" => 321.1473562,
            "Outpatient" => 48.51884975,
            "PrimarySchool" => 191.9480118,
            "RetailStore" => 0.0,
            "SecondarySchool" => 491.5554097,
            "SmallHotel" => 433.8738637,
            "SmallOffice" => 11.42620649,
            "StripMall" => 0.0,
            "Supermarket" => 25.53218144,
            "Warehouse" => 0.0,
            "FlatLoad" => 658.8635839
        ),
        "Helena" => Dict(
            "FastFoodRest" => 90.44011877,
            "FullServiceRest" => 280.9757902,
            "Hospital" => 800.0940058,
            "LargeHotel" => 7665.023574,
            "LargeOffice" => 262.1461576,
            "MediumOffice" => 37.68905029,
            "MidriseApartment" => 325.4421541,
            "Outpatient" => 49.09222188,
            "PrimarySchool" => 193.4573283,
            "RetailStore" => 0.0,
            "SecondarySchool" => 494.7393735,
            "SmallHotel" => 438.9398731,
            "SmallOffice" => 11.46564268,
            "StripMall" => 0.0,
            "Supermarket" => 25.72866824,
            "Warehouse" => 0.0,
            "FlatLoad" => 667.2021224
        ),
        "Duluth" => Dict(
            "FastFoodRest" => 98.10641517,
            "FullServiceRest" => 306.4772907,
            "Hospital" => 874.2611723,
            "LargeHotel" => 8484.906093,
            "LargeOffice" => 290.0193773,
            "MediumOffice" => 40.92475821,
            "MidriseApartment" => 360.161261,
            "Outpatient" => 53.53681127,
            "PrimarySchool" => 211.2386551,
            "RetailStore" => 0.0,
            "SecondarySchool" => 543.3733772,
            "SmallHotel" => 479.7414481,
            "SmallOffice" => 11.79316054,
            "StripMall" => 0.0,
            "Supermarket" => 27.3451629,
            "Warehouse" => 0.0,
            "FlatLoad" => 736.3678114
        ),
        "Fairbanks" => Dict(
            "FastFoodRest" => 108.5335945,
            "FullServiceRest" => 341.1572799,
            "Hospital" => 975.1062178,
            "LargeHotel" => 9600.267161,
            "LargeOffice" => 327.8820873,
            "MediumOffice" => 45.32138512,
            "MidriseApartment" => 407.3910855,
            "Outpatient" => 59.6203514,
            "PrimarySchool" => 234.2595741,
            "RetailStore" => 0.0,
            "SecondarySchool" => 604.6838786,
            "SmallHotel" => 535.2525234,
            "SmallOffice" => 12.23744003,
            "StripMall" => 0.0,
            "Supermarket" => 29.53958045,
            "Warehouse" => 0.0,
            "FlatLoad" => 830.07826
        )
    )
    if isempty(city)
        city = find_ashrae_zone_city(latitude, longitude)
    end
    if !(buildingtype in default_buildings)
        throw(@error("buildingtype $(buildingtype) not in $(default_buildings)."))
    end
    if isnothing(annual_mmbtu)
        # Use FlatLoad annual_mmbtu from data for all types of FlatLoads because we don't have separate data for e.g. FlatLoad_16_7
        if occursin("FlatLoad", buildingtype)
            annual_mmbtu = dhw_annual_mmbtu[city]["FlatLoad"]
        else        
            annual_mmbtu = dhw_annual_mmbtu[city][buildingtype]
        end
    else
        annual_mmbtu *= addressable_load_fraction
    end
    if length(monthly_mmbtu) == 12
        monthly_mmbtu = monthly_mmbtu .* addressable_load_fraction
    end
    built_in_load("domestic_hot_water", city, buildingtype, year, annual_mmbtu, monthly_mmbtu, 
                    existing_boiler_efficiency)
end


function BuiltInSpaceHeatingLoad(
    city::String,
    buildingtype::String,
    latitude::Real,
    longitude::Real,
    year::Int,
    addressable_load_fraction::Union{<:Real, AbstractVector{<:Real}},
    annual_mmbtu::Union{Real, Nothing}=nothing,
    monthly_mmbtu::Vector{<:Real}=Real[],
    existing_boiler_efficiency::Union{Real, Nothing}=nothing
    )
    spaceheating_annual_mmbtu = Dict(
        "Miami" => Dict(
            "FastFoodRest" => 5.426780867,
            "FullServiceRest" => 12.03181471,
            "Hospital" => 6248.413294,
            "LargeHotel" => 198.0691407,
            "LargeOffice" => 168.9731637,
            "MediumOffice" => 0.036985655,
            "MidriseApartment" => 38.70606161,
            "Outpatient" => 2559.185872,
            "PrimarySchool" => 49.78021153,
            "RetailStore" => 12.12015432,
            "SecondarySchool" => 203.5185485,
            "SmallHotel" => 9.098564901,
            "SmallOffice" => 0.312524873,
            "StripMall" => 20.73216748,
            "Supermarket" => 101.2785324,
            "Warehouse" => 56.0796017,
            "FlatLoad" => 605.2352137
        ),
        "Houston" => Dict(
            "FastFoodRest" => 85.49111065,
            "FullServiceRest" => 199.7942842,
            "Hospital" => 8732.10385,
            "LargeHotel" => 1307.035548,
            "LargeOffice" => 2229.971744,
            "MediumOffice" => 16.25994314,
            "MidriseApartment" => 386.0269973,
            "Outpatient" => 2829.324307,
            "PrimarySchool" => 469.2532935,
            "RetailStore" => 289.0470815,
            "SecondarySchool" => 2011.1678969999998,
            "SmallHotel" => 108.9825885,
            "SmallOffice" => 19.55157672,
            "StripMall" => 292.23235389999996,
            "Supermarket" => 984.7374347000001,
            "Warehouse" => 475.9377273,
            "FlatLoad" => 1277.307359
        ),
        "Phoenix" => Dict(
            "FastFoodRest" => 57.89972381,
            "FullServiceRest" => 147.2569493,
            "Hospital" => 9382.021026,
            "LargeHotel" => 896.790817,
            "LargeOffice" => 1584.061452,
            "MediumOffice" => 1.922551528,
            "MidriseApartment" => 290.9887152,
            "Outpatient" => 3076.340876,
            "PrimarySchool" => 305.573525,
            "RetailStore" => 208.66330580000002,
            "SecondarySchool" => 1400.638544,
            "SmallHotel" => 83.98084516,
            "SmallOffice" => 9.988210938,
            "StripMall" => 230.16060699999997,
            "Supermarket" => 972.3008295,
            "Warehouse" => 362.42249280000004,
            "FlatLoad" => 1188.188154
        ),
        "Atlanta" => Dict(
            "FastFoodRest" => 168.8402371,
            "FullServiceRest" => 379.5865464,
            "Hospital" => 10467.659959999999,
            "LargeHotel" => 2427.6589879999997,
            "LargeOffice" => 3624.593975,
            "MediumOffice" => 49.00635733,
            "MidriseApartment" => 718.9316697,
            "Outpatient" => 3186.250588,
            "PrimarySchool" => 931.7212450999999,
            "RetailStore" => 627.2489826000001,
            "SecondarySchool" => 3968.4936420000004,
            "SmallHotel" => 202.26124219999997,
            "SmallOffice" => 42.74797302,
            "StripMall" => 615.2240506,
            "Supermarket" => 1880.5304489999999,
            "Warehouse" => 930.9449202,
            "FlatLoad" => 1888.856302
        ),
        "LasVegas" => Dict(
            "FastFoodRest" => 100.0877773,
            "FullServiceRest" => 247.21791319999997,
            "Hospital" => 9100.302056,
            "LargeHotel" => 1500.581408,
            "LargeOffice" => 2479.152321,
            "MediumOffice" => 5.220181581,
            "MidriseApartment" => 487.43122850000003,
            "Outpatient" => 2924.8220460000002,
            "PrimarySchool" => 499.6562223,
            "RetailStore" => 386.0185744,
            "SecondarySchool" => 2277.7410649999997,
            "SmallHotel" => 138.4427074,
            "SmallOffice" => 19.16330622,
            "StripMall" => 389.30494280000005,
            "Supermarket" => 1479.302604,
            "Warehouse" => 579.7671637999999,
            "FlatLoad" => 1413.3882199999998
        ),
        "LosAngeles" => Dict(
            "FastFoodRest" => 40.90390152,
            "FullServiceRest" => 97.94277036,
            "Hospital" => 10346.1713,
            "LargeHotel" => 707.848762,
            "LargeOffice" => 1458.148818,
            "MediumOffice" => 0.12342009699999999,
            "MidriseApartment" => 265.2851759,
            "Outpatient" => 3417.120585,
            "PrimarySchool" => 318.73600980000003,
            "RetailStore" => 175.104083,
            "SecondarySchool" => 1198.276619,
            "SmallHotel" => 72.42852638,
            "SmallOffice" => 5.898878347,
            "StripMall" => 193.18730269999998,
            "Supermarket" => 1040.273464,
            "Warehouse" => 323.96697819999997,
            "FlatLoad" => 1228.8385369999999
        ),
        "SanFrancisco" => Dict(
            "FastFoodRest" => 127.22328700000001,
            "FullServiceRest" => 362.48645889999995,
            "Hospital" => 11570.9155,
            "LargeHotel" => 1713.3629670000003,
            "LargeOffice" => 2690.1191,
            "MediumOffice" => 3.8159670660000002,
            "MidriseApartment" => 648.4472797999999,
            "Outpatient" => 3299.0539519999998,
            "PrimarySchool" => 818.2159102,
            "RetailStore" => 569.8081034,
            "SecondarySchool" => 3414.148347,
            "SmallHotel" => 189.0244446,
            "SmallOffice" => 27.53039453,
            "StripMall" => 526.2320428,
            "Supermarket" => 2301.616069,
            "Warehouse" => 675.6758453,
            "FlatLoad" => 1808.604729
        ),
        "Baltimore" => Dict(
            "FastFoodRest" => 305.2671204,
            "FullServiceRest" => 657.1337578,
            "Hospital" => 11253.61694,
            "LargeHotel" => 3731.0254619999996,
            "LargeOffice" => 5109.311943,
            "MediumOffice" => 116.8101842,
            "MidriseApartment" => 1132.964052,
            "Outpatient" => 3285.227941,
            "PrimarySchool" => 1428.239177,
            "RetailStore" => 1068.034778,
            "SecondarySchool" => 6557.634924,
            "SmallHotel" => 346.3683857,
            "SmallOffice" => 63.29818348,
            "StripMall" => 1075.39546,
            "Supermarket" => 2929.182261,
            "Warehouse" => 1568.722061,
            "FlatLoad" => 2539.2645399999997
        ),
        "Albuquerque" => Dict(
            "FastFoodRest" => 199.73581399999998,
            "FullServiceRest" => 398.5712205,
            "Hospital" => 8371.240776999999,
            "LargeHotel" => 2750.8382260000003,
            "LargeOffice" => 3562.0023950000004,
            "MediumOffice" => 47.49307973,
            "MidriseApartment" => 805.0965778,
            "Outpatient" => 2971.868562,
            "PrimarySchool" => 981.4176700999999,
            "RetailStore" => 755.4523907,
            "SecondarySchool" => 4338.227865999999,
            "SmallHotel" => 232.2194443,
            "SmallOffice" => 43.25360481,
            "StripMall" => 760.0982018,
            "Supermarket" => 2302.228741,
            "Warehouse" => 1151.250885,
            "FlatLoad" => 1854.437216
        ),
        "Seattle" => Dict(
            "FastFoodRest" => 255.5992711,
            "FullServiceRest" => 627.5634984000001,
            "Hospital" => 11935.157290000001,
            "LargeHotel" => 3343.683348,
            "LargeOffice" => 5266.970348,
            "MediumOffice" => 28.97979768,
            "MidriseApartment" => 1117.5465470000001,
            "Outpatient" => 3468.128914,
            "PrimarySchool" => 1263.541878,
            "RetailStore" => 952.2758742000001,
            "SecondarySchool" => 6367.850187,
            "SmallHotel" => 310.8087307,
            "SmallOffice" => 49.34878545,
            "StripMall" => 969.1074739000001,
            "Supermarket" => 3004.1844929999997,
            "Warehouse" => 1137.398514,
            "FlatLoad" => 2506.1340600000003
        ),
        "Chicago" => Dict(
            "FastFoodRest" => 441.93439000000006,
            "FullServiceRest" => 888.3312571,
            "Hospital" => 12329.57943,
            "LargeHotel" => 5104.848129,
            "LargeOffice" => 7706.028917000001,
            "MediumOffice" => 216.01411800000002,
            "MidriseApartment" => 1482.040156,
            "Outpatient" => 3506.5381090000005,
            "PrimarySchool" => 2006.0002120000001,
            "RetailStore" => 1472.8704380000001,
            "SecondarySchool" => 8962.172873,
            "SmallHotel" => 479.4653436000001,
            "SmallOffice" => 94.19308949,
            "StripMall" => 1497.556168,
            "Supermarket" => 3696.2112950000005,
            "Warehouse" => 2256.477231,
            "FlatLoad" => 3258.766323
        ),
        "Boulder" => Dict(
            "FastFoodRest" => 306.8980525,
            "FullServiceRest" => 642.8843574,
            "Hospital" => 9169.381845,
            "LargeHotel" => 3975.1080020000004,
            "LargeOffice" => 5027.882454,
            "MediumOffice" => 124.26913059999998,
            "MidriseApartment" => 1098.944993,
            "Outpatient" => 3087.969786,
            "PrimarySchool" => 1356.396807,
            "RetailStore" => 1086.9187570000001,
            "SecondarySchool" => 6268.036872,
            "SmallHotel" => 342.77800099999996,
            "SmallOffice" => 65.95714912,
            "StripMall" => 1093.093638,
            "Supermarket" => 2966.790122,
            "Warehouse" => 1704.8648210000001,
            "FlatLoad" => 2394.8859239999997
        ),
        "Minneapolis" => Dict(
            "FastFoodRest" => 588.8854722,
            "FullServiceRest" => 1121.229499,
            "Hospital" => 13031.2313,
            "LargeHotel" => 6359.946704,
            "LargeOffice" => 10199.279129999999,
            "MediumOffice" => 394.1525556,
            "MidriseApartment" => 1814.148381,
            "Outpatient" => 3661.1462229999997,
            "PrimarySchool" => 2600.964302,
            "RetailStore" => 1869.8106289999998,
            "SecondarySchool" => 11963.323859999999,
            "SmallHotel" => 618.0427338999999,
            "SmallOffice" => 128.12525349999999,
            "StripMall" => 1952.731917,
            "Supermarket" => 4529.776664,
            "Warehouse" => 3231.223746,
            "FlatLoad" => 4004.001148
        ),
        "Helena" => Dict(
            "FastFoodRest" => 468.8276835,
            "FullServiceRest" => 934.8994934,
            "Hospital" => 10760.57411,
            "LargeHotel" => 5554.910785,
            "LargeOffice" => 7373.056709,
            "MediumOffice" => 239.8330306,
            "MidriseApartment" => 1531.102079,
            "Outpatient" => 3390.42972,
            "PrimarySchool" => 2097.777112,
            "RetailStore" => 1494.85988,
            "SecondarySchool" => 9535.484059,
            "SmallHotel" => 499.85992930000003,
            "SmallOffice" => 98.85818175,
            "StripMall" => 1604.0043970000002,
            "Supermarket" => 3948.5338049999996,
            "Warehouse" => 2504.784991,
            "FlatLoad" => 3252.362248
        ),
        "Duluth" => Dict(
            "FastFoodRest" => 738.1353594999999,
            "FullServiceRest" => 1400.36692,
            "Hospital" => 14179.84149,
            "LargeHotel" => 7781.9012760000005,
            "LargeOffice" => 12504.64187,
            "MediumOffice" => 468.2112216,
            "MidriseApartment" => 2204.85149,
            "Outpatient" => 3774.3233130000003,
            "PrimarySchool" => 3160.1200719999997,
            "RetailStore" => 2298.8242920000002,
            "SecondarySchool" => 14468.64346,
            "SmallHotel" => 772.5386662000001,
            "SmallOffice" => 155.8350887,
            "StripMall" => 2411.847491,
            "Supermarket" => 5587.977185,
            "Warehouse" => 3962.122014,
            "FlatLoad" => 4741.886326
        ),
        "Fairbanks" => Dict(
            "FastFoodRest" => 1245.3608279999999,
            "FullServiceRest" => 2209.293209,
            "Hospital" => 20759.042680000002,
            "LargeHotel" => 12298.7791,
            "LargeOffice" => 23214.51532,
            "MediumOffice" => 949.8812392000001,
            "MidriseApartment" => 3398.039504,
            "Outpatient" => 4824.076322999999,
            "PrimarySchool" => 6341.861225,
            "RetailStore" => 3869.670979,
            "SecondarySchool" => 25619.149269999998,
            "SmallHotel" => 1264.41064,
            "SmallOffice" => 297.08593010000004,
            "StripMall" => 3934.89178,
            "Supermarket" => 8515.422039000001,
            "Warehouse" => 6882.6512680000005,
            "FlatLoad" => 7851.508208
        )
    )
    if isempty(city)
        city = find_ashrae_zone_city(latitude, longitude)
    end
    if !(buildingtype in default_buildings)
        throw(@error("buildingtype $(buildingtype) not in $(default_buildings)."))
    end
    if isnothing(annual_mmbtu)
        # Use FlatLoad annual_mmbtu from data for all types of FlatLoads because we don't have separate data for e.g. FlatLoad_16_7
        if occursin("FlatLoad", buildingtype)
            annual_mmbtu = spaceheating_annual_mmbtu[city]["FlatLoad"]
        else
            annual_mmbtu = spaceheating_annual_mmbtu[city][buildingtype]
        end
    else
        annual_mmbtu *= addressable_load_fraction
    end
    if length(monthly_mmbtu) == 12
        monthly_mmbtu = monthly_mmbtu .* addressable_load_fraction
    end
    built_in_load("space_heating", city, buildingtype, year, annual_mmbtu, monthly_mmbtu, 
                    existing_boiler_efficiency)
end


function BuiltInCoolingLoad(
    city::String,
    buildingtype::String,
    latitude::Float64,
    longitude::Float64,
    year::Int,
    annual_tonhour::Union{Real, Nothing}=nothing,
    monthly_tonhour::Vector{<:Real}=Real[],
    existing_chiller_cop::Union{Real, Nothing}=nothing
    )
    cooling_annual_kwh = Dict(
        "Albuquerque" => Dict(
            "MidriseApartment" => 34088,
            "FastFoodRest" => 8466,
            "LargeOffice" => 442687,
            "Outpatient" => 357615,
            "PrimarySchool" => 99496,
            "SmallHotel" => 109982,
            "Supermarket" => 40883,
            "SmallOffice" => 8266,
            "StripMall" => 36498,
            "MediumOffice" => 103240,
            "LargeHotel" => 475348,
            "Warehouse" => 5831,
            "SecondarySchool" => 355818,
            "Hospital" => 1382003,
            "RetailStore" => 37955,
            "FullServiceRest" => 25534,
            "FlatLoad" => 220232.0
        ),
        "Helena" => Dict(
            "StripMall" => 13260,
            "RetailStore" => 13952,
            "Outpatient" => 233034,
            "FullServiceRest" => 8420,
            "SmallHotel" => 63978,
            "MediumOffice" => 44528,
            "Hospital" => 1075876,
            "LargeHotel" => 318965,
            "PrimarySchool" => 34468,
            "Supermarket" => 14879,
            "SmallOffice" => 3442,
            "SecondarySchool" => 132887,
            "FastFoodRest" => 2919,
            "MidriseApartment" => 11101,
            "LargeOffice" => 226066,
            "Warehouse" => 1566,
            "FlatLoad" => 137459.0
        ),
        "LosAngeles" => Dict(
            "MidriseApartment" => 22912,
            "Hospital" => 1987427,
            "Outpatient" => 435175,
            "RetailStore" => 22663,
            "SmallHotel" => 116966,
            "StripMall" => 26514,
            "FastFoodRest" => 3452,
            "LargeHotel" => 526169,
            "Supermarket" => 13630,
            "SmallOffice" => 8351,
            "Warehouse" => 673,
            "PrimarySchool" => 126130,
            "FullServiceRest" => 11456,
            "SecondarySchool" => 351337,
            "MediumOffice" => 121320,
            "LargeOffice" => 707617,
            "FlatLoad" => 280112.0
        ),
        "Boulder" => Dict(
            "Warehouse" => 3574,
            "Hospital" => 1223116,
            "PrimarySchool" => 57692,
            "SmallOffice" => 5097,
            "Supermarket" => 24684,
            "LargeHotel" => 384065,
            "LargeOffice" => 316540,
            "MidriseApartment" => 18535,
            "MediumOffice" => 68389,
            "RetailStore" => 23580,
            "FullServiceRest" => 14957,
            "SecondarySchool" => 220472,
            "Outpatient" => 291603,
            "FastFoodRest" => 5270,
            "StripMall" => 23350,
            "SmallHotel" => 84804,
            "FlatLoad" => 172858.0
        ),
        "Chicago" => Dict(
            "Hospital" => 1721142,
            "SmallHotel" => 97554,
            "SecondarySchool" => 336986,
            "SmallOffice" => 6365,
            "Supermarket" => 30785,
            "StripMall" => 32544,
            "FastFoodRest" => 6320,
            "Outpatient" => 328675,
            "LargeOffice" => 533117,
            "MidriseApartment" => 25663,
            "RetailStore" => 31774,
            "LargeHotel" => 469484,
            "MediumOffice" => 85839,
            "Warehouse" => 4370,
            "PrimarySchool" => 82619,
            "FullServiceRest" => 17222,
            "FlatLoad" => 238154.0
        ),
        "Houston" => Dict(
            "PrimarySchool" => 282346,
            "LargeHotel" => 1095441,
            "Hospital" => 2942336,
            "RetailStore" => 115410,
            "StripMall" => 111025,
            "FastFoodRest" => 24525,
            "LargeOffice" => 1471054,
            "Warehouse" => 17665,
            "MidriseApartment" => 97156,
            "SecondarySchool" => 1151985,
            "Outpatient" => 630778,
            "FullServiceRest" => 63610,
            "Supermarket" => 125580,
            "SmallOffice" => 19375,
            "SmallHotel" => 220470,
            "MediumOffice" => 239477,
            "FlatLoad" => 538015.0
        ),
        "Phoenix" => Dict(
            "SecondarySchool" => 1204514,
            "StripMall" => 122803,
            "PrimarySchool" => 302372,
            "LargeOffice" => 1124585,
            "SmallOffice" => 23720,
            "Supermarket" => 145706,
            "Outpatient" => 640137,
            "SmallHotel" => 233842,
            "MediumOffice" => 271151,
            "Hospital" => 2288973,
            "FullServiceRest" => 69402,
            "LargeHotel" => 1024137,
            "MidriseApartment" => 135120,
            "RetailStore" => 123508,
            "Warehouse" => 38561,
            "FastFoodRest" => 29956,
            "FlatLoad" => 486155.0
        ),
        "Fairbanks" => Dict(
            "Warehouse" => 97,
            "LargeOffice" => 147867,
            "Hospital" => 753420,
            "MidriseApartment" => 5035,
            "MediumOffice" => 24183,
            "LargeHotel" => 234082,
            "FullServiceRest" => 2025,
            "SmallOffice" => 1877,
            "Supermarket" => 2500,
            "PrimarySchool" => 15166,
            "RetailStore" => 3289,
            "SecondarySchool" => 53222,
            "Outpatient" => 143322,
            "FastFoodRest" => 656,
            "StripMall" => 3592,
            "SmallHotel" => 48066,
            "FlatLoad" => 89900.0
        ),
        "Seattle" => Dict(
            "StripMall" => 7664,
            "SmallHotel" => 60651,
            "SmallOffice" => 2503,
            "Supermarket" => 4882,
            "Outpatient" => 266075,
            "SecondarySchool" => 89468,
            "MediumOffice" => 38713,
            "MidriseApartment" => 6380,
            "LargeOffice" => 249231,
            "FullServiceRest" => 4144,
            "PrimarySchool" => 28984,
            "Hospital" => 1432385,
            "RetailStore" => 6223,
            "LargeHotel" => 292028,
            "FastFoodRest" => 1245,
            "Warehouse" => 329,
            "FlatLoad" => 155682.0
        ),
        "Duluth" => Dict(
            "Hospital" => 1149799,
            "StripMall" => 8809,
            "MediumOffice" => 37547,
            "RetailStore" => 8489,
            "LargeHotel" => 300364,
            "SecondarySchool" => 99148,
            "PrimarySchool" => 25136,
            "LargeOffice" => 249416,
            "MidriseApartment" => 8181,
            "FullServiceRest" => 4919,
            "Warehouse" => 889,
            "SmallHotel" => 61101,
            "FastFoodRest" => 1709,
            "Supermarket" => 9788,
            "SmallOffice" => 2563,
            "Outpatient" => 198121,
            "FlatLoad" => 135374.0
        ),
        "Minneapolis" => Dict(
            "Warehouse" => 2923,
            "SmallHotel" => 91962,
            "LargeOffice" => 475102,
            "Outpatient" => 289706,
            "Hospital" => 1516644,
            "SmallOffice" => 5452,
            "Supermarket" => 25962,
            "MediumOffice" => 74813,
            "PrimarySchool" => 62017,
            "FullServiceRest" => 14996,
            "LargeHotel" => 445049,
            "SecondarySchool" => 262353,
            "FastFoodRest" => 5429,
            "MidriseApartment" => 22491,
            "RetailStore" => 26859,
            "StripMall" => 26489,
            "FlatLoad" => 209265.0
        ),
        "Baltimore" => Dict(
            "SmallHotel" => 119859,
            "Outpatient" => 406989,
            "RetailStore" => 44703,
            "FullServiceRest" => 25140,
            "SecondarySchool" => 469545,
            "PrimarySchool" => 114110,
            "StripMall" => 43896,
            "MediumOffice" => 124064,
            "MidriseApartment" => 36890,
            "LargeOffice" => 822177,
            "Warehouse" => 7156,
            "LargeHotel" => 594327,
            "Hospital" => 2085465,
            "Supermarket" => 48913,
            "SmallOffice" => 8083,
            "FastFoodRest" => 9287,
            "FlatLoad" => 310038.0
        ),
        "LasVegas" => Dict(
            "RetailStore" => 89484,
            "LargeHotel" => 798740,
            "MediumOffice" => 207085,
            "StripMall" => 84138,
            "PrimarySchool" => 218688,
            "Warehouse" => 28928,
            "SmallOffice" => 16824,
            "Supermarket" => 114543,
            "MidriseApartment" => 92778,
            "FullServiceRest" => 53259,
            "Outpatient" => 513377,
            "FastFoodRest" => 22811,
            "SmallHotel" => 175011,
            "LargeOffice" => 792463,
            "SecondarySchool" => 858081,
            "Hospital" => 1831966,
            "FlatLoad" => 368636.0
        ),
        "Atlanta" => Dict(
            "LargeOffice" => 968973,
            "LargeHotel" => 704148,
            "Supermarket" => 69686,
            "StripMall" => 62530,
            "SmallOffice" => 11259,
            "MediumOffice" => 155865,
            "Hospital" => 2328054,
            "FullServiceRest" => 33832,
            "SmallHotel" => 149237,
            "SecondarySchool" => 608831,
            "Warehouse" => 8214,
            "Outpatient" => 489234,
            "FlatLoad" => 367407.0,
            "FastFoodRest" => 12565,
            "PrimarySchool" => 160138,
            "MidriseApartment" => 50907,
            "RetailStore" => 65044
        ),
        "SanFrancisco" => Dict(
            "SecondarySchool" => 121914,
            "LargeOffice" => 297494,
            "StripMall" => 6626,
            "Supermarket" => 3252,
            "SmallOffice" => 2539,
            "Hospital" => 1427329,
            "PrimarySchool" => 48323,
            "LargeHotel" => 296230,
            "MediumOffice" => 43956,
            "MidriseApartment" => 4484,
            "FullServiceRest" => 3062,
            "Warehouse" => 365,
            "FlatLoad" => 164036.0,
            "SmallHotel" => 71414,
            "RetailStore" => 4515,
            "FastFoodRest" => 838,
            "Outpatient" => 292238
        ),
        "Miami" => Dict(
            "LargeHotel" => 1467216,
            "SmallOffice" => 28235,
            "FastFoodRest" => 36779,
            "FlatLoad" => 700779.0,
            "Supermarket" => 150368,
            "FullServiceRest" => 101567,
            "PrimarySchool" => 434031,
            "Warehouse" => 20108,
            "LargeOffice" => 1878642,
            "SmallHotel" => 318595,
            "MidriseApartment" => 176446,
            "RetailStore" => 163290,
            "Outpatient" => 811571,
            "Hospital" => 3371923,
            "StripMall" => 180645,
            "SecondarySchool" => 1735906,
            "MediumOffice" => 337147
        )
    )
    if isempty(city)
        city = find_ashrae_zone_city(latitude, longitude)
    end
    if !(buildingtype in default_buildings)
        throw(@error("buildingtype $(buildingtype) not in $(default_buildings)."))
    end
    # Set initial existing_chiller_cop to "cop_unknown_thermal" if not passed in; we will update existing_chiller_cop once the load profile is determined
    if isnothing(existing_chiller_cop)
        existing_chiller_cop = get_existing_chiller_default_cop()
    end
    if isnothing(annual_tonhour)
        # Use FlatLoad annual_kwh from data for all types of FlatLoads because we don't have separate data for e.g. FlatLoad_16_7
        if occursin("FlatLoad", buildingtype)
            annual_kwh = cooling_annual_kwh[city]["FlatLoad"]
        else
            annual_kwh = cooling_annual_kwh[city][buildingtype]
        end
    else
        annual_kwh = annual_tonhour * KWH_THERMAL_PER_TONHOUR / existing_chiller_cop
    end
    monthly_kwh = Real[]
    if length(monthly_tonhour) == 12
        monthly_kwh = monthly_tonhour * KWH_THERMAL_PER_TONHOUR / existing_chiller_cop
    end
    built_in_load("cooling", city, buildingtype, year, annual_kwh, monthly_kwh)
end
"""
`ProcessHeatLoad` is an optional REopt input with the following keys and default values:
```julia
    industry_reference_name::String = "",
    sector::String = "",
    blended_industry_reference_names::Array{String, 1} = String[],
    blended_industry_reference_percents::Array{<:Real, 1} = Real[],
    annual_mmbtu::Union{Real, Nothing} = nothing,
    monthly_mmbtu::Array{<:Real,1} = Real[],
    addressable_load_fraction::Any = 1.0,
    fuel_loads_mmbtu_per_hour::Array{<:Real,1} = Real[],
    time_steps_per_hour::Int = 1, # corresponding to `fuel_loads_mmbtu_per_hour`
    latitude::Real = 0.0,
    longitude::Real = 0.0,
    existing_boiler_efficiency::Real = NaN
```

There are many ways in which a ProcessHeatLoad can be defined:
1. When using either `industry_reference_name` or `blended_industry_reference_names`
2. One can provide the `industry_reference_name` or `blended_industry_reference_names` directly in the `ProcessHeatLoad` key within the `Scenario`. These values can be combined with the `annual_mmbtu` or `monthly_mmbtu` inputs to scale the industry reference profile(s).
3. One can provide the `fuel_loads_mmbtu_per_hour` value in the `ProcessHeatLoad` key within the `Scenario`.

!!! note "Process heat loads"
    Process heat "load" inputs are in terms of fuel energy input required (boiler fuel), not the actual thermal demand.
    The fuel energy is multiplied by the existing_boiler_efficiency to get the actual energy demand.

"""
function BuiltInProcessHeatLoad(
    sector::String,
    process_type::String,
    latitude::Real,
    longitude::Real,
    year::Int,
    addressable_load_fraction::Union{<:Real, AbstractVector{<:Real}},
    annual_mmbtu::Union{Real, Nothing}=nothing,
    monthly_mmbtu::Vector{<:Real}=Real[],
    existing_boiler_efficiency::Union{Real, Nothing}=nothing
    )
    # Override the city with 'Industrial'
    sector  = "Industrial"
    city    = sector
    buildingtype = process_type

    process_heat_annual_mmbtu = Dict(
        "Industrial" => Dict(
            "Chemical" => 15000.0,  # mid-sized chemical processes
            "FlatLoad" => 10000,  #  continuous operations throughout the year
            "Warehouse" => 7000
        )
    )
    if isempty(city)
        city = "Industrial"
    end        
    if !(process_type in default_process_types)
        throw(@error("process_type $(process_type) is not recognized for process heating."))
    end
    if isnothing(annual_mmbtu)
        # Use FlatLoad annual_mmbtu from data for all types of FlatLoads because we don't have separate data for e.g. FlatLoad_16_7
        if occursin("FlatLoad", buildingtype)
            annual_mmbtu = process_heat_annual_mmbtu[city]["FlatLoad"]
        else
            annual_mmbtu = process_heat_annual_mmbtu[city][buildingtype]
        end
    else
        annual_mmbtu *= addressable_load_fraction
    end
    if length(monthly_mmbtu) == 12
        monthly_mmbtu = monthly_mmbtu .* addressable_load_fraction
        monthly_mmbtu = Real[monthly_mmbtu...]
    end

    built_in_load("process_heat", city, buildingtype, year, annual_mmbtu, monthly_mmbtu, existing_boiler_efficiency)
end

struct ProcessHeatLoad
    loads_kw::Array{Real, 1}
    annual_mmbtu::Real
    unaddressable_annual_fuel_mmbtu::Real

    function ProcessHeatLoad(;
        industry_reference_name::String = "",
        sector::String = "",
        blended_industry_reference_names::Array{String, 1} = String[],
        blended_industry_reference_percents::Array{<:Real, 1} = Real[],
        annual_mmbtu::Union{Real, Nothing} = nothing,
        monthly_mmbtu::Array{<:Real,1} = Real[],
        addressable_load_fraction::Any = 1.0,
        fuel_loads_mmbtu_per_hour::Array{<:Real,1} = Real[],
        time_steps_per_hour::Int = 1, # corresponding to `fuel_loads_mmbtu_per_hour`
        latitude::Real = 0.0,
        longitude::Real = 0.0,
        existing_boiler_efficiency::Real = NaN
        )
        
        sector = "Industrial"
        doe_reference_name = industry_reference_name
        city = sector
        blended_doe_reference_names = blended_industry_reference_names
        blended_doe_reference_percents = blended_industry_reference_percents


        if length(addressable_load_fraction) > 1
            if !isempty(fuel_loads_mmbtu_per_hour) && length(addressable_load_fraction) != length(fuel_loads_mmbtu_per_hour)
                throw(@error("`addressable_load_fraction` must be a scalar or an array of length `fuel_loads_mmbtu_per_hour`"))
            end
            if !isempty(monthly_mmbtu) && length(addressable_load_fraction) != 12
                throw(@error("`addressable_load_fraction` must be a scalar or an array of length 12 if `monthly_mmbtu` is input"))
            end
            addressable_load_fraction = convert(Vector{Real}, addressable_load_fraction)
        elseif typeof(addressable_load_fraction) <: Vector{}
            addressable_load_fraction = convert(Real, addressable_load_fraction[1])  
        else
            addressable_load_fraction = convert(Real, addressable_load_fraction)            
        end

        if length(fuel_loads_mmbtu_per_hour) > 0

            if !(length(fuel_loads_mmbtu_per_hour) / time_steps_per_hour ≈ 8760)
                throw(@error("Provided process heat load does not match the time_steps_per_hour."))
            end

            loads_kw = fuel_loads_mmbtu_per_hour .* (KWH_PER_MMBTU * existing_boiler_efficiency) .* addressable_load_fraction
            unaddressable_annual_fuel_mmbtu = sum(fuel_loads_mmbtu_per_hour .* (1 .- addressable_load_fraction))  / time_steps_per_hour       

            if !isempty(doe_reference_name) || length(blended_doe_reference_names) > 0
                @warn "ProcessHeatLoad fuel_loads_mmbtu_per_hour was provided, so doe_reference_name and/or blended_doe_reference_names will be ignored."
            end

        elseif !isempty(doe_reference_name)
            loads_kw = BuiltInProcessHeatLoad(city, doe_reference_name, latitude, longitude, 2017, addressable_load_fraction, annual_mmbtu, monthly_mmbtu, existing_boiler_efficiency)
            if length(blended_doe_reference_names) > 0
                @warn "ProcessHeatLoad doe_reference_name was provided, so blended_doe_reference_names will be ignored."
            end
            unaddressable_annual_fuel_mmbtu = get_unaddressable_fuel(addressable_load_fraction, annual_mmbtu, monthly_mmbtu, loads_kw, existing_boiler_efficiency)          
        elseif length(blended_doe_reference_names) > 0 && 
            length(blended_doe_reference_names) == length(blended_doe_reference_percents)
            loads_kw = blend_and_scale_doe_profiles(BuiltInProcessHeatLoad, latitude, longitude, 2017, 
                                                    blended_doe_reference_names, blended_doe_reference_percents, city, 
                                                    annual_mmbtu, monthly_mmbtu, addressable_load_fraction,
                                                    existing_boiler_efficiency)
            
            unaddressable_annual_fuel_mmbtu = get_unaddressable_fuel(addressable_load_fraction, annual_mmbtu, monthly_mmbtu, loads_kw, existing_boiler_efficiency)
        else
            throw(@error("Cannot construct BuiltInProcessHeatLoad. You must provide either [fuel_loads_mmbtu_per_hour], 
                [industry_reference_name, city], or [blended_industry_reference_names, blended_industry_reference_percents, city]."))
        end

        if length(loads_kw) < 8760*time_steps_per_hour
            loads_kw = repeat(loads_kw, inner=Int(time_steps_per_hour / (length(loads_kw)/8760)))
            @warn "Repeating space heating loads in each hour to match the time_steps_per_hour."
        end

        new(
            loads_kw,
            (sum(loads_kw)/time_steps_per_hour)/KWH_PER_MMBTU,
            unaddressable_annual_fuel_mmbtu

        )
    end
end

"""
    get_unaddressable_fuel(addressable_load_fraction, annual_mmbtu, monthly_mmbtu, loads_kw, existing_boiler_efficiency)
    
Get unaddressable fuel load, for reporting
    :addressable_load_fraction is the fraction of the input fuel load that is addressable to supply by energy technologies, like CHP
    :annual_mmbtu and :monthly_mmbtu is assumed to be fuel, not thermal, in this function
    :loads_kw is assumed to be thermal in this function, with units of kw_thermal, so needs to be converted to fuel mmbtu
"""
function get_unaddressable_fuel(addressable_load_fraction, annual_mmbtu, monthly_mmbtu, loads_kw, existing_boiler_efficiency)
    # Get unaddressable fuel load, for reporting
    if !isempty(monthly_mmbtu)
        unaddressable_annual_fuel_mmbtu = sum(monthly_mmbtu .* (1 .- addressable_load_fraction))
    elseif !isnothing(annual_mmbtu)
        unaddressable_annual_fuel_mmbtu = annual_mmbtu * (1 - addressable_load_fraction)
    else # using the default CRB annual_mmbtu, so rely on loads_kw (thermal) assuming single addressable_load_fraction
        unaddressable_annual_fuel_mmbtu = sum(loads_kw) / (KWH_PER_MMBTU * existing_boiler_efficiency)                
    end
    return unaddressable_annual_fuel_mmbtu
end