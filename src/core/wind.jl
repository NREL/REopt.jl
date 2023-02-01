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
`Wind` is an optional REopt input with the following keys and default values:
```julia
    min_kw = 0.0,
    max_kw = 1.0e9,
    installed_cost_per_kw = nothing,
    om_cost_per_kw = 35.0,
    production_factor_series = nothing,
    size_class = "",
    wind_meters_per_sec = [],
    wind_direction_degrees = [],
    temperature_celsius = [],
    pressure_atmospheres = [],
    acres_per_kw = 0.03, # assuming a power density of 30 acres per MW for turbine sizes >= 1.5 MW. No size constraint applied to turbines below 1.5 MW capacity. (not exposed in API)
    macrs_option_years = 5,
    macrs_bonus_fraction = 0.0,
    macrs_itc_reduction = 0.5,
    federal_itc_fraction = nothing,
    federal_rebate_per_kw = 0.0,
    state_ibi_fraction = 0.0,
    state_ibi_max = 1.0e10,
    state_rebate_per_kw = 0.0,
    state_rebate_max = 1.0e10,
    utility_ibi_fraction = 0.0,
    utility_ibi_max = 1.0e10,
    utility_rebate_per_kw = 0.0,
    utility_rebate_max = 1.0e10,
    production_incentive_per_kwh = 0.0,
    production_incentive_max_benefit = 1.0e9,
    production_incentive_years = 1,
    production_incentive_max_kw = 1.0e9,
    can_net_meter = true,
    can_wholesale = true,
    can_export_beyond_nem_limit = true
    operating_reserve_required_fraction::Real = off_grid_flag ? 0.50 : 0.0, # Only applicable when `off_grid_flag` is true. Applied to each time_step as a % of wind generation serving load.
```
!!! note "Default assumptions" 
    `size_class` must be one of ["residential", "commercial", "medium", "large"]. If `size_class` is not provided then it is determined based on the average electric load.

    If no `installed_cost_per_kw` is provided then it is determined from:
    ```julia
    size_class_to_installed_cost = Dict(
        "residential"=> 11950.0,
        "commercial"=> 7390.0,
        "medium"=> 4440.0,
        "large"=> 3450.0
    )
    ```
    If the `production_factor_series` is not provided then NREL's System Advisor Model (SAM) is used to get the wind turbine production factor.

!!! note "Wind resource value inputs"
    Wind resource values are optional (i.e., `wind_meters_per_sec`, `wind_direction_degrees`, `temperature_celsius`, and `pressure_atmospheres`).
    If not provided then the resource values are downloaded from NREL's Wind Toolkit.
    These values are passed to SAM to get the turbine production factor.

!!! note "Wind sizing and land constraint" 
    Wind size is constrained by Site.land_acres, assuming a power density of Wind.acres_per_kw for turbine sizes above 1.5 MW (default assumption of 30 acres per MW). 
    If the turbine size recommended is smaller than 1.5 MW, the input for land available will not constrain the system size. 
    If the the land available constrains the system size to less than 1.5 MW, the system will be capped at 1.5 MW (i.e., turbines < 1.5 MW are not subject to the acres/kW limit).  

"""
struct Wind <: AbstractTech
    min_kw::Real
    max_kw::Real
    installed_cost_per_kw::Union{Nothing, Real}
    om_cost_per_kw::Real
    production_factor_series::Union{Nothing, Array{Real,1}}
    size_class::String
    hub_height::T where T <: Real
    wind_meters_per_sec::AbstractArray{Float64,1}
    wind_direction_degrees::AbstractArray{Float64,1}
    temperature_celsius::AbstractArray{Float64,1}
    pressure_atmospheres::AbstractArray{Float64,1}
    acres_per_kw::Real
    macrs_option_years::Int
    macrs_bonus_fraction::Real
    macrs_itc_reduction::Real
    federal_itc_fraction::Union{Nothing, Real}
    federal_rebate_per_kw::Real
    state_ibi_fraction::Real
    state_ibi_max::Real
    state_rebate_per_kw::Real
    state_rebate_max::Real
    utility_ibi_fraction::Real
    utility_ibi_max::Real
    utility_rebate_per_kw::Real
    utility_rebate_max::Real
    production_incentive_per_kwh::Real
    production_incentive_max_benefit::Real
    production_incentive_years::Int
    production_incentive_max_kw::Real
    can_net_meter::Bool
    can_wholesale::Bool
    can_export_beyond_nem_limit::Bool
    can_curtail::Bool
    operating_reserve_required_fraction::Real

    function Wind(;
        off_grid_flag::Bool = false,
        min_kw = 0.0,
        max_kw = 1.0e9,
        installed_cost_per_kw = nothing,
        om_cost_per_kw = 35.0,
        production_factor_series = nothing,
        size_class = "",
        wind_meters_per_sec = [],
        wind_direction_degrees = [],
        temperature_celsius = [],
        pressure_atmospheres = [],
        acres_per_kw = 0.03, # assuming a power density of 30 acres per MW for turbine sizes >= 1.5 MW. No size constraint applied to turbines below 1.5 MW capacity.
        macrs_option_years = 5,
        macrs_bonus_fraction = 0.0,
        macrs_itc_reduction = 0.5,
        federal_itc_fraction = nothing,
        federal_rebate_per_kw = 0.0,
        state_ibi_fraction = 0.0,
        state_ibi_max = 1.0e10,
        state_rebate_per_kw = 0.0,
        state_rebate_max = 1.0e10,
        utility_ibi_fraction = 0.0,
        utility_ibi_max = 1.0e10,
        utility_rebate_per_kw = 0.0,
        utility_rebate_max = 1.0e10,
        production_incentive_per_kwh = 0.0,
        production_incentive_max_benefit = 1.0e9,
        production_incentive_years = 1,
        production_incentive_max_kw = 1.0e9,
        can_net_meter = off_grid_flag ? false : true,
        can_wholesale = off_grid_flag ? false : true,
        can_export_beyond_nem_limit = off_grid_flag ? false : true,
        can_curtail= true,
        average_elec_load = 0.0,
        operating_reserve_required_fraction::Real = off_grid_flag ? 0.50 : 0.0, # Only applicable when `off_grid_flag` is true. Applied to each time_step as a % of wind generation serving load.
        )
        size_class_to_hub_height = Dict(
            "residential"=> 20,
            "commercial"=> 40,
            "medium"=> 60,  # Owen Roberts provided 50m for medium size_class, but Wind Toolkit has increments of 20m
            "large"=> 80
        )
        size_class_to_installed_cost = Dict(
            "residential"=> 5675.0,
            "commercial"=> 4300.0,
            "medium"=> 2766.0,
            "large"=> 2239.0
        )

        size_class_to_itc_incentives = Dict(
            "residential"=> 0.3,
            "commercial"=> 0.3,
            "medium"=> 0.12,
            "large"=> 0.12
        )
        
        if size_class == ""
            if average_elec_load <= 12.5
                size_class = "residential"
            elseif average_elec_load <= 100
                size_class = "commercial"
            elseif average_elec_load <= 1000
                size_class = "medium"
            else
                size_class = "large"
            end
        elseif !(size_class in keys(size_class_to_hub_height))
            throw(@error("Wind size_class must be one of $(keys(size_class_to_hub_height))"))
        end

        if isnothing(installed_cost_per_kw)
            installed_cost_per_kw = size_class_to_installed_cost[size_class]
        end

        if isnothing(federal_itc_fraction)
            federal_itc_fraction = size_class_to_itc_incentives[size_class]
        end

        hub_height = size_class_to_hub_height[size_class]

        if !(off_grid_flag) && !(operating_reserve_required_fraction == 0.0)
            @warn "Wind operating_reserve_required_fraction applies only when `off_grid_flag` is true. Setting operating_reserve_required_fraction to 0.0 for this on-grid analysis."
            operating_reserve_required_fraction = 0.0
        end

        if off_grid_flag && (can_net_meter || can_wholesale || can_export_beyond_nem_limit)
            @warn "Setting Wind can_net_meter, can_wholesale, and can_export_beyond_nem_limit to False because `off_grid_flag` is true."
            can_net_meter = false
            can_wholesale = false
            can_export_beyond_nem_limit = false
        end

        new(
            min_kw,
            max_kw,
            installed_cost_per_kw,
            om_cost_per_kw,
            production_factor_series,
            size_class,
            hub_height,
            wind_meters_per_sec,
            wind_direction_degrees,
            temperature_celsius,
            pressure_atmospheres,
            acres_per_kw,
            macrs_option_years,
            macrs_bonus_fraction,
            macrs_itc_reduction,
            federal_itc_fraction,
            federal_rebate_per_kw,
            state_ibi_fraction,
            state_ibi_max,
            state_rebate_per_kw,
            state_rebate_max,
            utility_ibi_fraction,
            utility_ibi_max,
            utility_rebate_per_kw,
            utility_rebate_max,
            production_incentive_per_kwh,
            production_incentive_max_benefit,
            production_incentive_years,
            production_incentive_max_kw,
            can_net_meter,
            can_wholesale,
            can_export_beyond_nem_limit,
            can_curtail,
            operating_reserve_required_fraction
        )
    end
end