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

    if s.elec_storage.max_kw > 0
        push!(all_storage, "ElecStorage")
        push!(elec_storage, "ElecStorage")
    end

    if s.hot_tes.max_kw > 0
        push!(all_storage, "HotThermalStorage")
        push!(hot_storage, "HotThermalStorage")
    end

    if s.cold_tes.max_kw > 0
        push!(all_storage, "HotThermalStorage")
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

    if s.elec_storage.max_kw > 0
        push!(all_storage, "ElecStorage")
        push!(elec_storage, "ElecStorage")
    end

    if s.hot_tes.max_kw > 0
        push!(all_storage, "HotThermalStorage")
        push!(hot_storage, "HotThermalStorage")
    end

    if s.cold_tes.max_kw > 0
        push!(all_storage, "HotThermalStorage")
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
    fill_storage_vals!(d::Dict, f::Financial)

    Fill storage dictionary `d`'s values using financial model `f`. The dict `d` must have keys equivalent to the fieldnames(Storage)
"""
function fill_storage_vals!(d::Dict, f::Financial)
    d[:charge_efficiency] = d[:rectifier_efficiency_pct] * d[:internal_efficiency_pct]^0.5
    d[:discharge_efficiency] = d[:inverter_efficiency_pct] * d[:s.internal_efficiency_pct]^0.5)
    d[:installed_cost_per_kw] = effective_cost(;
        itc_basis = d[:installed_cost_per_kw],
        replacement_cost = d[:replace_cost_per_kw],
        replacement_year = d[:inverter_replacement_year],
        discount_rate = f.owner_discount_pct,
        tax_rate = f.owner_tax_pct,
        itc = d[:total_itc_pct],
        macrs_schedule = d[:macrs_option_years] == 7 ? f.macrs_seven_year : f.macrs_five_year,
        macrs_bonus_pct = d[:macrs_bonus_pct],
        macrs_itc_reduction = d[:macrs_itc_reduction],
        rebate_per_kw = d[:total_rebate_per_kw]
    )
    d[:installed_cost_per_kwh] = effective_cost(;
        itc_basis = d[:installed_cost_per_kwh],
        replacement_cost = d[:replace_cost_per_kwh],
        replacement_year = d[:inverter_replacement_year],
        discount_rate = f.owner_discount_pct,
        tax_rate = f.owner_tax_pct,
        itc = d[:total_itc_pct],
        macrs_schedule = d[:macrs_option_years] == 7 ? f.macrs_seven_year : f.macrs_five_year,
        macrs_bonus_pct = d[:macrs_bonus_pct],
        macrs_itc_reduction = d[:macrs_itc_reduction]
    )

end