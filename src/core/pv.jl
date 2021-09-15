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
    PV

struct with inner constructor:
```julia
function PV(;
    tilt::Real,
    array_type::Int=1,
    module_type::Int=0,
    losses::Real=0.14,
    azimuth::Real=180,
    gcr::Real=0.4,
    radius::Int=0,
    name::String="PV",
    location::String="both",
    existing_kw::Real=0,
    min_kw::Real=0,
    max_kw::Real=1.0e9,
    installed_cost_per_kw::Real=1600.0,
    om_cost_per_kw::Real=16.0,
    degradation_pct::Real=0.005,
    macrs_option_years::Int = 5,
    macrs_bonus_pct::Float64 = 1.0,
    macrs_itc_reduction::Float64 = 0.5,
    kw_per_square_foot::Float64=0.01,
    acres_per_kw::Float64=6e-3,
    inv_eff::Float64=0.96,
    dc_ac_ratio::Float64=1.2,
    prod_factor_series_kw::Union{Missing, Array{Real,1}} = missing,
    federal_itc_pct::Float64 = 0.26,
    federal_rebate_per_kw::Float64 = 0.0,
    state_ibi_pct::Float64 = 0.0,
    state_ibi_max::Float64 = 1.0e10,
    state_rebate_per_kw::Float64 = 0.0,
    state_rebate_max::Float64 = 1.0e10,
    utility_ibi_pct::Float64 = 0.0,
    utility_ibi_max::Float64 = 1.0e10,
    utility_rebate_per_kw::Float64 = 0.0,
    utility_rebate_max::Float64 = 1.0e10,
    production_incentive_per_kwh::Float64 = 0.0,
    production_incentive_max_benefit::Float64 = 1.0e9,
    production_incentive_years::Int = 1,
    production_incentive_max_kw::Float64 = 1.0e9
    can_net_meter::Bool = true,
    can_wholesale::Bool = true,
    can_export_beyond_nem_limit::Bool = true
)
```
!!! note
    If `tilt` is not provided then it is set to the `Site.latitude`. (Which is handled in the `Scenario` struct.)
"""
struct PV <: AbstractTech
    tilt
    array_type
    module_type
    losses
    azimuth
    gcr
    radius
    name
    location
    existing_kw
    min_kw
    max_kw
    installed_cost_per_kw
    om_cost_per_kw
    degradation_pct
    macrs_option_years
    macrs_bonus_pct
    macrs_itc_reduction
    kw_per_square_foot
    acres_per_kw
    inv_eff
    dc_ac_ratio
    prod_factor_series_kw
    federal_itc_pct
    federal_rebate_per_kw
    state_ibi_pct
    state_ibi_max
    state_rebate_per_kw
    state_rebate_max
    utility_ibi_pct
    utility_ibi_max
    utility_rebate_per_kw
    utility_rebate_max
    production_incentive_per_kwh
    production_incentive_max_benefit
    production_incentive_years
    production_incentive_max_kw
    can_net_meter
    can_wholesale
    can_export_beyond_nem_limit
    can_curtail

    function PV(;
        tilt::Real,
        array_type::Int=1,
        module_type::Int=0,
        losses::Real=0.14,
        azimuth::Real=180,
        gcr::Real=0.4,
        radius::Int=0,
        name::String="PV",
        location::String="both",
        existing_kw::Real=0,
        min_kw::Real=0,
        max_kw::Real=1.0e9,
        installed_cost_per_kw::Real=1600.0,
        om_cost_per_kw::Real=16.0,
        degradation_pct::Real=0.005,
        macrs_option_years::Int = 5,
        macrs_bonus_pct::Float64 = 1.0,
        macrs_itc_reduction::Float64 = 0.5,
        kw_per_square_foot::Float64=0.01,
        acres_per_kw::Float64=6e-3,
        inv_eff::Float64=0.96,
        dc_ac_ratio::Float64=1.2,
        prod_factor_series_kw::Union{Missing, Array{Real,1}} = missing,
        federal_itc_pct::Float64 = 0.26,
        federal_rebate_per_kw::Float64 = 0.0,
        state_ibi_pct::Float64 = 0.0,
        state_ibi_max::Float64 = 1.0e10,
        state_rebate_per_kw::Float64 = 0.0,
        state_rebate_max::Float64 = 1.0e10,
        utility_ibi_pct::Float64 = 0.0,
        utility_ibi_max::Float64 = 1.0e10,
        utility_rebate_per_kw::Float64 = 0.0,
        utility_rebate_max::Float64 = 1.0e10,
        production_incentive_per_kwh::Float64 = 0.0,
        production_incentive_max_benefit::Float64 = 1.0e9,
        production_incentive_years::Int = 1,
        production_incentive_max_kw::Float64 = 1.0e9,
        can_net_meter::Bool = true,
        can_wholesale::Bool = true,
        can_export_beyond_nem_limit::Bool = true,
        can_curtail::Bool = true,
        )

        # validate inputs
        invalid_args = String[]
        if !(0 <= azimuth < 360)
            push!(invalid_args, "azimuth must satisfy 0 <= azimuth < 360, got $(azimuth)")
        end
        if !(array_type in [0, 1, 2, 3, 4])
            push!(invalid_args, "array_type must be in [0, 1, 2, 3, 4], got $(array_type)")
        end
        if !(module_type in [0, 1, 2])
            push!(invalid_args, "module_type must be in [0, 1, 2], got $(module_type)")
        end
        if !(0.0 <= losses <= 0.99)
            push!(invalid_args, "losses must satisfy 0.0 <= losses <= 0.99, got $(losses)")
        end
        if !(0 <= tilt <= 90)
            push!(invalid_args, "tilt must satisfy 0 <= tilt <= 90, got $(tilt)")
        end
        if !(location in ["roof", "ground", "both"])
            push!(invalid_args, "location must be in [\"roof\", \"ground\", \"both\"], got $(location)")
        end
        if !(0.0 <= degradation_pct <= 1.0)
            push!(invalid_args, "degradation_pct must satisfy 0 <= degradation_pct <= 1, got $(degradation_pct)")
        end
        if !(0.0 <= inv_eff <= 1.0)
            push!(invalid_args, "inv_eff must satisfy 0 <= inv_eff <= 1, got $(inv_eff)")
        end
        if !(0.0 <= dc_ac_ratio <= 2.0)
            push!(invalid_args, "dc_ac_ratio must satisfy 0 <= dc_ac_ratio <= 1, got $(dc_ac_ratio)")
        end
        # TODO validate additional args
        if length(invalid_args) > 0
            error("Invalid argument values: $(invalid_args)")
        end

        new(
            tilt,
            array_type,
            module_type,
            losses,
            azimuth,
            gcr,
            radius,
            name,
            location,
            existing_kw,
            min_kw,
            max_kw,
            installed_cost_per_kw,
            om_cost_per_kw,
            degradation_pct,
            macrs_option_years,
            macrs_bonus_pct,
            macrs_itc_reduction,
            kw_per_square_foot,
            acres_per_kw,
            inv_eff,
            dc_ac_ratio,
            prod_factor_series_kw,
            federal_itc_pct,
            federal_rebate_per_kw,
            state_ibi_pct,
            state_ibi_max,
            state_rebate_per_kw,
            state_rebate_max,
            utility_ibi_pct,
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
            can_curtail
        )
    end
end


function get_pv_by_name(name::String, pvs::AbstractArray{PV, 1})
    pvs[findfirst(pv -> pv.name == name, pvs)]
end