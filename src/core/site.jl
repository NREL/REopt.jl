# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
Inputs related to the physical location:

`Site` is a required REopt input with the following keys and default values:
```julia
    latitude::Real, 
    longitude::Real, 
    land_acres::Union{Real, Nothing} = nothing, # acres of land available for PV panels and/or Wind turbines. Constraint applied separately to PV and Wind, meaning the two technologies are assumed to be able to be co-located.
    roof_squarefeet::Union{Real, Nothing} = nothing,
    min_resil_time_steps::Int=0, # The minimum number consecutive timesteps that load must be fully met once an outage begins. Only applies to multiple outage modeling using inputs outage_start_time_steps and outage_durations.
    mg_tech_sizes_equal_grid_sizes::Bool = true,
    sector::String = "commercial/industrial",
    federal_sector_state::String = "",
    federal_procurement_type::String = "",
    CO2_emissions_reduction_min_fraction::Union{Float64, Nothing} = nothing,
    CO2_emissions_reduction_max_fraction::Union{Float64, Nothing} = nothing,
    bau_emissions_lb_CO2_per_year::Union{Float64, Nothing} = nothing, # Auto-populated based on BAU run. This input will be overwritten if the BAU scenario is run, but can be user-provided if no BAU scenario is run.
    bau_grid_emissions_lb_CO2_per_year::Union{Float64, Nothing} = nothing,
    renewable_electricity_min_fraction::Real = 0.0,
    renewable_electricity_max_fraction::Union{Float64, Nothing} = nothing,
    include_grid_renewable_fraction_in_RE_constraints::Bool = false,
    include_exported_elec_emissions_in_total::Bool = true,
    include_exported_renewable_electricity_in_total::Bool = true,
    outdoor_air_temperature_degF::Union{Nothing, Array{<:Real,1}} = nothing,
    node::Int = 1,
```
"""
mutable struct Site
    "required"
    latitude
    "required"
    longitude
    land_acres
    roof_squarefeet
    min_resil_time_steps
    mg_tech_sizes_equal_grid_sizes
    sector
    federal_elec_cost_escalation_region
    federal_procurement_type
    CO2_emissions_reduction_min_fraction
    CO2_emissions_reduction_max_fraction
    bau_emissions_lb_CO2_per_year
    bau_grid_emissions_lb_CO2_per_year
    renewable_electricity_min_fraction
    renewable_electricity_max_fraction
    include_grid_renewable_fraction_in_RE_constraints
    include_exported_elec_emissions_in_total
    include_exported_renewable_electricity_in_total
    outdoor_air_temperature_degF
    node  # TODO validate that multinode Sites do not share node numbers
    function Site(;
        latitude::Real, 
        longitude::Real, 
        land_acres::Union{Real, Nothing} = nothing, 
        roof_squarefeet::Union{Real, Nothing} = nothing,
        min_resil_time_steps::Int=0,
        mg_tech_sizes_equal_grid_sizes::Bool = true,
        sector::String = "commercial/industrial",
        federal_sector_state::String = "",
        federal_procurement_type::String = "",
        CO2_emissions_reduction_min_fraction::Union{Float64, Nothing} = nothing,
        CO2_emissions_reduction_max_fraction::Union{Float64, Nothing} = nothing,
        bau_emissions_lb_CO2_per_year::Union{Float64, Nothing} = nothing,
        bau_grid_emissions_lb_CO2_per_year::Union{Float64, Nothing} = nothing,
        renewable_electricity_min_fraction::Union{Float64, Nothing} = nothing,
        renewable_electricity_max_fraction::Union{Float64, Nothing} = nothing,
        include_grid_renewable_fraction_in_RE_constraints::Bool = false,
        include_exported_elec_emissions_in_total::Bool = true,
        include_exported_renewable_electricity_in_total::Bool = true,
        outdoor_air_temperature_degF::Union{Nothing, Array{<:Real,1}} = nothing,
        node::Int = 1, 
        )
        invalid_args = String[]
        if !(-90 <= latitude < 90)
            push!(invalid_args, "latitude must satisfy -90 <= latitude < 90, got $(latitude)")
        end
        if !(-180 <= longitude < 180)
            push!(invalid_args, "longitude must satisfy -180 <= longitude < 180, got $(longitude)")
        end
        if sector != "commercial/industrial" && sector != "federal"
            push!(invalid_args, "sector must be either 'commercial/industrial' or 'federal', got $(sector)")
        end
        federal_elec_cost_escalation_region = ""
        if sector == "federal"
            federal_elec_cost_escalation_region = get_NIST_EERC_rate_region(federal_sector_state)
            if isempty(federal_elec_cost_escalation_region)
                push!(invalid_args, "federal_sector_state must be a valid US state name or abbreviation when sector is 'federal'")
            end
            if !(federal_procurement_type in ("fedowned_dirpurch", "fedowned_thirdparty", "privateowned_thirdparty"))
                push!(invalid_args, "federal_procurement_type must be one of 'fedowned_dirpurch', 'fedowned_thirdparty', or 'privateowned_thirdparty' when sector is 'federal'")
            end
        end
        if !isnothing(renewable_electricity_max_fraction) && !isnothing(renewable_electricity_min_fraction)
            if (renewable_electricity_min_fraction > renewable_electricity_max_fraction)
                push!(invalid_args, "renewable_electricity_min_fraction must be less than or equal to renewable_electricity_max_fraction")
            end
        end
        if length(invalid_args) > 0
            throw(@error("Invalid Site argument values: $(invalid_args)"))
        end

        new(latitude, longitude, land_acres, roof_squarefeet, min_resil_time_steps, 
            mg_tech_sizes_equal_grid_sizes, sector, federal_elec_cost_escalation_region, 
            federal_procurement_type, CO2_emissions_reduction_min_fraction, 
            CO2_emissions_reduction_max_fraction, bau_emissions_lb_CO2_per_year,
            bau_grid_emissions_lb_CO2_per_year, renewable_electricity_min_fraction,
            renewable_electricity_max_fraction, include_grid_renewable_fraction_in_RE_constraints, include_exported_elec_emissions_in_total,
            include_exported_renewable_electricity_in_total, outdoor_air_temperature_degF, node)
    end
    function state_name_to_abbr(federal_sector_state)
        return get(
            Dict{String,String}(
                "Washington" => "WA",
                "Oregon" => "OR",
                "California" => "CA",
                "Alaska" => "AK",
                "Hawaii" => "HI",

                "Nevada" => "NV",
                "Idaho" => "ID",
                "Utah" => "UT",
                "Arizona" => "AZ",
                "Montana" => "MT",
                "Wyoming" => "WY",
                "Colorado" => "CO",

                "New Mexico" => "NM",
                "North Dakota" => "ND",
                "South Dakota" => "SD",
                "Nebraska" => "NE",
                "Kansas" => "KS",
                "Minnesota" => "MN",
                "Iowa" => "IA",
                "Missouri" => "MO",

                "Wisconsin" => "WI",
                "Illinois" => "IL",
                "Indiana" => "IN",
                "Ohio" => "OH",
                "Michigan" => "MI",

                "Louisiana" => "LA",
                "Texas" => "TX",
                "Oklahoma" => "OK",
                "Arkansas" => "AR",

                "Kentucky" => "KY",
                "Tennessee" => "TN",
                "Alabama" => "AL",
                "Mississippi" => "MS",
                
                "North Carolina" => "NC",
                "South Carolina" => "SC",
                "Georgia" => "GA",
                "Florida" => "FL",
                "Tennessee" => "TN",
                "Kentucky" => "KY",
                "West Virginia" => "WV",
                "Virginia" => "VA",
                "Maryland" => "MD",
                "Delaware" => "DE",
                "District of Columbia" => "DC",

                "New Jersey" => "NJ",
                "New York" => "NY",
                "Pennsylvania" => "PA",

                "Connecticut" => "CT",
                "Rhode Island" => "RI",
                "Massachusetts" => "MA",
                "New Hampshire" => "NH",
                "Maine" => "ME",
                "Vermont" => "VT",
                "New Jersey" => "NJ"
            ),
            federal_sector_state,
            ""
        )
    end
    function get_NIST_EERC_rate_region(state::String)
        abbr_to_region = Dict{String,String}(
            "WA" => "Pacific",
            "OR" => "Pacific",
            "CA" => "Pacific",
            "AK" => "Pacific",
            "HI" => "Pacific",

            "NV" => "Mountain",
            "ID" => "Mountain",
            "UT" => "Mountain",
            "AZ" => "Mountain",
            "MT" => "Mountain",
            "WY" => "Mountain",
            "CO" => "Mountain",
            "NM" => "Mountain",

            "ND" => "West North Central",
            "SD" => "West North Central",
            "NE" => "West North Central",
            "KS" => "West North Central",
            "MN" => "West North Central",
            "IA" => "West North Central",
            "MO" => "West North Central",

            "WI" => "East North Central",
            "IL" => "East North Central",
            "IN" => "East North Central",
            "OH" => "East North Central",
            "MI" => "East North Central",

            "LA" => "West South Central",
            "TX" => "West South Central",
            "OK" => "West South Central",
            "AR" => "West South Central",

            "KY" => "East South Central",
            "TN" => "East South Central",
            "AL" => "East South Central",
            "MS" => "East South Central",

            "NC" => "South Atlantic",
            "SC" => "South Atlantic",
            "GA" => "South Atlantic",
            "FL" => "South Atlantic",
            "WV" => "South Atlantic",
            "VA" => "South Atlantic",
            "MD" => "South Atlantic",
            "DE" => "South Atlantic",
            "DC" => "South Atlantic",

            "NJ" => "Middle Atlantic",
            "NY" => "Middle Atlantic",
            "PA" => "Middle Atlantic",

            "CT" => "New England",
            "RI" => "New England",
            "MA" => "New England",
            "NH" => "New England",
            "ME" => "New England",
            "VT" => "New England",
            "NJ" => "New England"
        )
        region = get(abbr_to_region, state, "")
        if isempty(region)
            region = get(abbr_to_region, state_name_to_abbr(state), "")
        end
        return region
    end
end