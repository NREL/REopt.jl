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
    Financial

Financial data struct with inner constructor:
```julia
function Financial(;
    om_cost_escalation_pct::Real = 0.025,
    elec_cost_escalation_pct::Real = 0.019,
    boiler_fuel_cost_escalation_pct::Real = 0.034,
    chp_fuel_cost_escalation_pct::Real = 0.034,
    generator_fuel_cost_escalation_pct::Real = 0.027,
    offtaker_tax_pct::Real = 0.26,
    offtaker_discount_pct::Real = 0.0564,
    third_party_ownership::Bool = false,
    owner_tax_pct::Real = 0.26,
    owner_discount_pct::Real = 0.0564,
    analysis_years::Int = 25,
    value_of_lost_load_per_kwh::Union{Array{R,1}, R} where R<:Real = 1.00,
    microgrid_upgrade_cost_pct::Real = off_grid_flag ? 0.0 : 0.3,
    macrs_five_year::Array{<:Real,1} = [0.2, 0.32, 0.192, 0.1152, 0.1152, 0.0576],  # IRS pub 946
    macrs_seven_year::Array{<:Real,1} = [0.1429, 0.2449, 0.1749, 0.1249, 0.0893, 0.0892, 0.0893, 0.0446],
    offgrid_other_capital_costs::Real = 0.0, # only applicable when off_grid_flag is true. Straight-line depreciation is applied to this capex cost, reducing taxable income.
    offgrid_other_annual_costs::Real = 0.0 # only applicable when off_grid_flag is true. Considered tax deductible for owner. Costs are per year. 
)
```

!!! note
    When `third_party_ownership` is `false` the offtaker's discount and tax percentages are used throughout the model:
    ```julia
        if !third_party_ownership
            owner_tax_pct = offtaker_tax_pct
            owner_discount_pct = offtaker_discount_pct
        end
    ```
"""
struct Financial
    om_cost_escalation_pct::Real
    elec_cost_escalation_pct::Real
    boiler_fuel_cost_escalation_pct::Real
    chp_fuel_cost_escalation_pct::Real
    generator_fuel_cost_escalation_pct::Real
    offtaker_tax_pct::Real
    offtaker_discount_pct::Real
    third_party_ownership::Bool
    owner_tax_pct::Real
    owner_discount_pct::Real
    analysis_years::Int
    value_of_lost_load_per_kwh::Union{Array{R,1}, R} where R<:Real
    microgrid_upgrade_cost_pct::Real
    macrs_five_year::Array{<:Real,1}
    macrs_seven_year::Array{<:Real,1}
    offgrid_other_capital_costs::Real
    offgrid_other_annual_costs::Real

    function Financial(;
        off_grid_flag::Bool = false,
        om_cost_escalation_pct::Real = 0.025,
        elec_cost_escalation_pct::Real = 0.019,
        boiler_fuel_cost_escalation_pct::Real = 0.034,
        chp_fuel_cost_escalation_pct::Real = 0.034,
        generator_fuel_cost_escalation_pct::Real = 0.027,
        offtaker_tax_pct::Real = 0.26,
        offtaker_discount_pct::Real = 0.0564,
        third_party_ownership::Bool = false,
        owner_tax_pct::Real = 0.26,
        owner_discount_pct::Real = 0.0564,
        analysis_years::Int = 25,
        value_of_lost_load_per_kwh::Union{Array{R,1}, R} where R<:Real = 1.00,
        microgrid_upgrade_cost_pct::Real = off_grid_flag ? 0.0 : 0.3,
        macrs_five_year::Array{<:Real,1} = [0.2, 0.32, 0.192, 0.1152, 0.1152, 0.0576],  # IRS pub 946
        macrs_seven_year::Array{<:Real,1} = [0.1429, 0.2449, 0.1749, 0.1249, 0.0893, 0.0892, 0.0893, 0.0446],
        offgrid_other_capital_costs::Real = 0.0, # only applicable when off_grid_flag is true. Straight-line depreciation is applied to this capex cost, reducing taxable income.
        offgrid_other_annual_costs::Real = 0.0 # only applicable when off_grid_flag is true. Considered tax deductible for owner.
    )
        
        if off_grid_flag && !(microgrid_upgrade_cost_pct == 0.0)
            @warn "microgrid_upgrade_cost_pct is not applied when off_grid_flag is true. Setting microgrid_upgrade_cost_pct to 0.0."
            microgrid_upgrade_cost_pct = 0.0
        end

        if !off_grid_flag && (offgrid_other_capital_costs != 0.0 || offgrid_other_annual_costs != 0.0)
            @warn "offgrid_other_capital_costs and offgrid_other_annual_costs are only applied when off_grid_flag is true. Setting these inputs to 0.0 for this grid-connected analysis."
            offgrid_other_capital_costs = 0.0
            offgrid_other_annual_costs = 0.0
        end

        if !third_party_ownership
            owner_tax_pct = offtaker_tax_pct
            owner_discount_pct = offtaker_discount_pct
        end

        return new(
            om_cost_escalation_pct,
            elec_cost_escalation_pct,
            boiler_fuel_cost_escalation_pct,
            chp_fuel_cost_escalation_pct,
            generator_fuel_cost_escalation_pct,
            offtaker_tax_pct,
            offtaker_discount_pct,
            third_party_ownership,
            owner_tax_pct,
            owner_discount_pct,
            analysis_years,
            value_of_lost_load_per_kwh,
            microgrid_upgrade_cost_pct,
            macrs_five_year,
            macrs_seven_year,
            offgrid_other_capital_costs,
            offgrid_other_annual_costs
        )
    end
end