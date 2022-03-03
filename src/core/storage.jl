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
    Storage(p::REoptInputs, s::BAUScenario)

    Create a `Storage` struct for the BAUInputs; assumes no storage.
"""
function Storage(p::REoptInputs, s::BAUScenario)
    Storage(
        String[],
        String[],
        String[],
        String[],
        String[]
    )
end


"""
    Storage(s::Scenario) 

    Create a `Storage` struct for the REoptInputs.
"""
function Storage(s::Scenario)
    all_storage = String[]
    elec_storage = String[]
    hot_storage = String[]
    cold_storage = String[]

    if s.elec_storage.max_kw > 0.0 && s.elec_storage.max_kwh > 0.0
        push!(all_storage, "ElectricStorage")
        push!(elec_storage, "ElectricStorage")
    end

    if s.hot_tes.max_kw > 0.0 && s.hot_tes.max_kwh > 0.0
        push!(all_storage, "HotThermalStorage")
        push!(hot_storage, "HotThermalStorage")
    end

    if s.cold_tes.max_kw > 0.0 && s.cold_tes.max_kwh > 0.0
        push!(all_storage, "ColdThermalStorage")
        push!(cold_storage, "ColdThermalStorage")
    end

    thermal_storage = union(hot_storage, cold_storage)

    Storage(
        all_storage,
        elec_storage,
        thermal_storage,
        hot_storage,
        cold_storage
    )
end


"""
    Storage(s::MPCScenario) 

    Create a `Storage` struct for the MPCInputs
"""
function Storage(s::MPCScenario)
    # TODO: Confirm storage models are continuous, keep this as is? 
    all_storage = String[]
    elec_storage = String[]
    hot_storage = String[]
    cold_storage = String[]

    if s.storage.size_kw > 0.0 && s.storage.size_kwh > 0.0
        push!(all_storage, "ElectricStorage")
        push!(elec_storage, "ElectricStorage")
    end

    thermal_storage = union(hot_storage, cold_storage)

    Storage(
        all_storage,
        elec_storage,
        thermal_storage,
        hot_storage,
        cold_storage
    )
end



function fill_financial_storage_vals!(d::Dict, s::AbstractStorage, f::Financial, is_electric::Bool)    
    if is_electric
        installed_cost_per_kw = s.installed_cost_per_kw
        installed_cost_per_kwh = s.installed_cost_per_kwh
        replace_cost_per_kw = s.replace_cost_per_kw
        replace_cost_per_kwh = s.replace_cost_per_kwh
        replacement_year = s.inverter_replacement_year
    else
        installed_cost_per_kw = 0.0
        installed_cost_per_kwh = s.installed_cost_per_gal * d[:kwh_per_gal]
        replace_cost_per_kw = 0.0
        replace_cost_per_kwh = 0.0
        replacement_year = 100
    end
    
    d[:installed_cost_per_kw] = effective_cost(;
        itc_basis = installed_cost_per_kw,
        replacement_cost = replace_cost_per_kw,
        replacement_year = replacement_year,
        discount_rate = f.owner_discount_pct,
        tax_rate = f.owner_tax_pct,
        itc = s.total_itc_pct,
        macrs_schedule = s.macrs_option_years == 7 ? f.macrs_seven_year : f.macrs_five_year,
        macrs_bonus_pct = s.macrs_bonus_pct,
        macrs_itc_reduction = s.macrs_itc_reduction,
        rebate_per_kw = s.total_rebate_per_kw
    )
    d[:installed_cost_per_kwh] = effective_cost(;
        itc_basis = installed_cost_per_kwh,
        replacement_cost = replace_cost_per_kwh,
        replacement_year = replacement_year,
        discount_rate = f.owner_discount_pct,
        tax_rate = f.owner_tax_pct,
        itc = s.total_itc_pct,
        macrs_schedule = s.macrs_option_years == 7 ? f.macrs_seven_year : f.macrs_five_year,
        macrs_bonus_pct = s.macrs_bonus_pct,
        macrs_itc_reduction = s.macrs_itc_reduction
    )
    
    d[:installed_cost_per_kwh] -= s.total_rebate_per_kwh

end

