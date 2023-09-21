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
GHP evaluations typically require the `GhpGhx.jl` package to be loaded unless the `GhpGhx.jl` package 
was already used externally to create `inputs_dict["GHP"]["ghpghx_responses"]`. See the Home page under 
"Additional package loading for GHP" for instructions. This `GHP` struct uses the response from `GhpGhx.jl`
to process input parameters for REopt including additional cost parameters for `GHP`.

    GHP

struct with outer constructor:
```julia
    require_ghp_purchase::Union{Bool, Int64} = false  # 0 = false, 1 = true
    installed_cost_heatpump_per_ton::Float64 = 1075.0
    heatpump_capacity_sizing_factor_on_peak_load::Float64 = 1.1
    installed_cost_ghx_per_ft::Float64 = 14.0
    installed_cost_building_hydronic_loop_per_sqft = 1.70
    om_cost_per_sqft_year::Float64 = -0.51
    building_sqft::Float64 # Required input
    space_heating_efficiency_thermal_factor::Float64 = NaN  # Default depends on building and location
    cooling_efficiency_thermal_factor::Float64 = NaN # Default depends on building and location
    ghpghx_response::Dict = Dict()
    can_serve_dhw::Bool = false

    macrs_option_years::Int = 5
    macrs_bonus_fraction::Float64 = 0.8
    macrs_itc_reduction::Float64 = 0.5
    federal_itc_fraction::Float64 = 0.3
    federal_rebate_per_ton::Float64 = 0.0
    federal_rebate_per_kw::Float64 = 0.0
    state_ibi_fraction::Float64 = 0.0
    state_ibi_max::Float64 = 1.0e10
    state_rebate_per_ton::Float64 = 0.0
    state_rebate_per_kw::Float64 = 0.0
    state_rebate_max::Float64 = 1.0e10
    utility_ibi_fraction::Float64 = 0.0
    utility_ibi_max::Float64 = 1.0e10
    utility_rebate_per_ton::Float64 = 0.0
    utility_rebate_per_kw::Float64 = 0.0
    utility_rebate_max::Float64 = 1.0e10

    # Processed data from inputs and results of GhpGhx.jl
    heating_thermal_kw::Vector{Float64} = []
    cooling_thermal_kw::Vector{Float64} = []
    yearly_electric_consumption_kw::Vector{Float64} = []
    peak_combined_heatpump_thermal_ton::Float64 = NaN

    # Intermediate parameters for cost processing
    tech_sizes_for_cost_curve::Union{Float64, AbstractVector{Float64}} = NaN
    installed_cost_per_kw::Union{Float64, AbstractVector{Float64}} = NaN
    heatpump_capacity_ton::Float64 = NaN

    # Process and populate these parameters needed more directly by the model
    installed_cost::Float64 = NaN
    om_cost_year_one::Float64 = NaN
```
"""



Base.@kwdef mutable struct GHP <: AbstractGHP
    require_ghp_purchase::Union{Bool, Int64} = false  # 0 = false, 1 = true
    installed_cost_heatpump_per_ton::Float64 = 1075.0
    heatpump_capacity_sizing_factor_on_peak_load::Float64 = 1.1
    installed_cost_ghx_per_ft::Float64 = 14.0
    installed_cost_building_hydronic_loop_per_sqft = 1.70
    om_cost_per_sqft_year::Float64 = -0.51
    building_sqft::Float64 # Required input
    space_heating_efficiency_thermal_factor::Float64 = NaN  # Default depends on building and location
    cooling_efficiency_thermal_factor::Float64 = NaN # Default depends on building and location
    ghpghx_response::Dict = Dict()
    can_serve_dhw::Bool = false

    aux_heater_type::String = "electric"
    is_ghx_hybrid::Bool = false
    aux_heater_installed_cost_per_mmbtu_per_hr::Float64 = 26000.00
    aux_cooler_installed_cost_per_ton::Float64 = 400.00
    aux_unit_capacity_sizing_factor_on_peak_load::Float64 = 1.2

    macrs_option_years::Int = 5
    macrs_bonus_fraction::Float64 = 0.8
    macrs_itc_reduction::Float64 = 0.5
    federal_itc_fraction::Float64 = 0.3
    federal_rebate_per_ton::Float64 = 0.0
    federal_rebate_per_kw::Float64 = 0.0
    state_ibi_fraction::Float64 = 0.0
    state_ibi_max::Float64 = 1.0e10
    state_rebate_per_ton::Float64 = 0.0
    state_rebate_per_kw::Float64 = 0.0
    state_rebate_max::Float64 = 1.0e10
    utility_ibi_fraction::Float64 = 0.0
    utility_ibi_max::Float64 = 1.0e10
    utility_rebate_per_ton::Float64 = 0.0
    utility_rebate_per_kw::Float64 = 0.0
    utility_rebate_max::Float64 = 1.0e10

    # Processed data from inputs and results of GhpGhx.jl
    heating_thermal_kw::Vector{Float64} = []
    cooling_thermal_kw::Vector{Float64} = []
    yearly_electric_consumption_kw::Vector{Float64} = []
    peak_combined_heatpump_thermal_ton::Float64 = NaN

    # Intermediate parameters for cost processing
    tech_sizes_for_cost_curve::Union{Float64, AbstractVector{Float64}} = NaN
    installed_cost_per_kw::Union{Float64, AbstractVector{Float64}} = NaN
    heatpump_capacity_ton::Float64 = NaN

    # Process and populate these parameters needed more directly by the model
    om_cost_year_one::Float64 = NaN
end


function GHP(response::Dict, d::Dict)
    ghp = GHP(; ghpghx_response = response, dictkeys_tosymbols(d)...)
    
    if !(0 <= ghp.aux_cooler_installed_cost_per_ton <= 1.0e6)
        @error "out of bounds aux_cooler_installed_cost_per_ton"
    end

    if !(0 <= ghp.aux_heater_installed_cost_per_mmbtu_per_hr <= 1.0e6)
        @error "out of bounds aux_heater_installed_cost_per_mmbtu_per_hr"
    end

    if !(1.0 <= ghp.aux_unit_capacity_sizing_factor_on_peak_load <= 5.0)
        @error "out of bounds aux_unit_capacity_sizing_factor_on_peak_load"
    end

    # Inputs of GhpGhx.jl, which are still needed in REopt
    ghp.heating_thermal_kw = response["inputs"]["heating_thermal_load_mmbtu_per_hr"] * KWH_PER_MMBTU
    ghp.cooling_thermal_kw = response["inputs"]["cooling_thermal_load_ton"] * KWH_THERMAL_PER_TONHOUR
    # Outputs of GhpGhx.jl
    ghp.yearly_electric_consumption_kw = response["outputs"]["yearly_total_electric_consumption_series_kw"]
    ghp.peak_combined_heatpump_thermal_ton = response["outputs"]["peak_combined_heatpump_thermal_ton"]

    # Change units basis from ton to kW to use existing cost_curve function
    for region in ["federal", "state", "utility"]
        setfield!(ghp, Symbol(region * "_rebate_per_kw"), getfield(ghp, Symbol(region * "_rebate_per_ton")))
    end
    # incentives = IncentivesNoProdBased(**d_mod)
    
    setup_installed_cost_curve!(ghp, response)

    setup_om_cost!(ghp)

    # Convert boolean input into an integer for the model
    if typeof(ghp.require_ghp_purchase) == Bool && ghp.require_ghp_purchase
        ghp.require_ghp_purchase = 1
    else
        ghp.require_ghp_purchase = 0
    end

    return ghp
end

"""
    setup_installed_cost_curve!(response::Dict, ghp::GHP)

"""
function setup_installed_cost_curve!(ghp::GHP, response::Dict)
    big_number = 1.0e10
    # GHX and GHP sizing metrics for cost calculations
    total_ghx_ft = response["outputs"]["number_of_boreholes"] * response["outputs"]["length_boreholes_ft"]
    heatpump_peak_ton = response["outputs"]["peak_combined_heatpump_thermal_ton"]

    # Use initial cost curve to leverage existing incentives-based cost curve method in data_manager
    # The GHX and hydronic loop cost are the y-intercepts ([$]) of the cost for each design
    ghx_cost = total_ghx_ft * ghp.installed_cost_ghx_per_ft
    hydronic_loop_cost = ghp.building_sqft * ghp.installed_cost_building_hydronic_loop_per_sqft

    aux_heater_cost = 0.0
    aux_cooler_cost = 0.0
    if ghp.is_ghx_hybrid
        aux_heater_cost = ghp.aux_heater_installed_cost_per_mmbtu_per_hr*
        response["outputs"]["peak_aux_heater_thermal_production_mmbtu_per_hour"]*
        ghp.aux_unit_capacity_sizing_factor_on_peak_load
        
        aux_cooler_cost = ghp.aux_cooler_installed_cost_per_ton*
        response["outputs"]["peak_aux_cooler_thermal_production_ton"]*
        ghp.aux_unit_capacity_sizing_factor_on_peak_load
    end

    # The DataManager._get_REopt_cost_curve method expects at least a two-point tech_sizes_for_cost_curve to
    #   to use the first value of installed_cost_per_kw as an absolute $ value and
    #   the initial slope is based on the heat pump size (e.g. $/ton) of the cost curve for
    #   building a rebate-based cost curve if there are less-than big_number maximum incentives
    ghp.tech_sizes_for_cost_curve = [0.0, big_number]
    ghp.installed_cost_per_kw = [ghx_cost + hydronic_loop_cost + aux_cooler_cost + aux_heater_cost, 
                                ghp.installed_cost_heatpump_per_ton]

    # Using a separate call to _get_REopt_cost_curve in data_manager for "ghp" (not included in "available_techs")
    #    and then use the value below for heat pump capacity to calculate the final absolute cost for GHP

    # Use this with the cost curve to determine absolute cost
    ghp.heatpump_capacity_ton = heatpump_peak_ton * ghp.heatpump_capacity_sizing_factor_on_peak_load
end

function setup_om_cost!(ghp::GHP)
    # O&M Cost
    ghp.om_cost_year_one = ghp.building_sqft * ghp.om_cost_per_sqft_year
end

function assign_thermal_factor!(d::Dict, heating_or_cooling::String)
    if heating_or_cooling == "space_heating"
        name = "space_heating_efficiency_thermal_factor"
        if haskey(d, "SpaceHeatingLoad")
            file_path = joinpath(@__DIR__, "..", "..", "data", "ghp", "ghp_space_heating_efficiency_thermal_factors.csv")
            factor_data_df = CSV.read(file_path, DataFrame)
            building_type = get(d["SpaceHeatingLoad"], "doe_reference_name", [])
        else
            building_type = "dummy"
        end
    elseif heating_or_cooling == "cooling"
        name = "cooling_efficiency_thermal_factor"
        if haskey(d, "CoolingLoad")
            file_path = joinpath(@__DIR__, "..", "..", "data", "ghp", "ghp_cooling_efficiency_thermal_factors.csv")
            factor_data_df = CSV.read(file_path, DataFrame)
            building_type = get(d["CoolingLoad"], "doe_reference_name", [])
        else
            building_type = "dummy"
        end
    else
        throw(@error("Specify `space_heating` or `cooling` for assign_thermal_factor! function"))
    end
    latitude = d["Site"]["latitude"]
    longitude = d["Site"]["longitude"]
    nearest_city, climate_zone = find_ashrae_zone_city(latitude, longitude; get_zone=true)
    # Default thermal factors are assigned for certain building types and not for campuses (multiple buildings)
    if !(building_type == "dummy") && building_type in factor_data_df[!, "BuildingType"]
        factor = filter("BuildingType" => ==(building_type), factor_data_df)[1, climate_zone]
    else
        factor = 1.0
    end
    
    # Mutate d to assign GHP efficiency_thermal_factors
    d["GHP"][name] = factor

    # Return this data for informational purposes
    return nearest_city, climate_zone
end

function call_ghpghx(ghpghx_inputs::Dict)
    # Call GhpGhx.jl to size GHP and GHX
    results, inputs_params = GhpGhx.ghp_model(ghpghx_inputs)
    # Create a dictionary of the results data needed for REopt
    ghpghx_results = GhpGhx.get_results_for_reopt(results, inputs_params)
    return ghpghx_results
end

function handle_hybrid_ghp(ghpghx_inputs::Dict,aux_heater_type::Union{String, Nothing})

    ## Deal with hybrid
    hybrid_ghx_sizing_method = get(ghpghx_inputs, "hybrid_ghx_sizing_method", nothing)

    hybrid_ghx_sizing_flag = false
    if hybrid_ghx_sizing_method == "Automatic"
        determine_heat_cool_post = deepcopy(ghpghx_inputs)
        determine_heat_cool_post["simulation_years"] = 2
        determine_heat_cool_post["max_sizing_iterations"] = 1

        # Call GhpGhx.jl to size GHP and GHX
        @info "Starting GhpGhx.jl for automatic hybrid GHX sizing"
        determine_heat_cool_results_resp_dict = call_ghpghx(determine_heat_cool_post)
        @info "Automatic hybrid GHX sizing complete using GhpGhx.jl"

        temp_diff = determine_heat_cool_results_resp_dict["end_of_year_ghx_lft_f"][2] \
        - determine_heat_cool_results_resp_dict["end_of_year_ghx_lft_f"][1]

        hybrid_sizing_flag = 1.0 # non hybrid
        if temp_diff > 0
            hybrid_sizing_flag = -2.0 #heating
            hybrid_ghx_sizing_flag = true
        elseif temp_diff < 0
            hybrid_sizing_flag = -1.0 #cooling
            hybrid_ghx_sizing_flag = true
        else
            # non hybrid if exactly 0.
            hybrid_sizing_flag = 1.0
        end
        ghpghx_inputs["hybrid_sizing_flag"] = hybrid_sizing_flag

    elseif hybrid_ghx_sizing_method == "Fractional"
        hybrid_ghx_sizing_flag = true
        ghpghx_inputs["hybrid_sizing_flag"] = get(ghpghx_inputs, "hybrid_ghx_sizing_fraction", 0.6)
    else
        @warn "Unknown hybrid GHX sizing model provided"
    end

    # set ghp tech sizing method
    is_ghx_hybrid = false
    if !hybrid_ghx_sizing_flag
        is_ghx_hybrid = false
    else
        is_ghx_hybrid = true
    end

    if !isnothing(aux_heater_type)
        if aux_heater_type == "electric"
            ghpghx_inputs["is_heating_electric"] = true
        else
            @warn "Unknown auxillary heater type provided"
            ghpghx_inputs["is_heating_electric"] = false
        end
    end
    return ghpghx_inputs, is_ghx_hybrid
end