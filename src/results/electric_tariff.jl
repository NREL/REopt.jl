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
function add_electric_tariff_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    r = Dict{String, Any}()
    m[Symbol("Year1UtilityEnergy"*_n)] = p.hours_per_timestep * 
        sum(m[Symbol("dvGridPurchase"*_n)][ts] for ts in p.time_steps)

    r["total_energy_cost_us_dollars"] = round(value(m[Symbol("TotalEnergyChargesUtil"*_n)]) * (1 - p.offtaker_tax_pct), digits=2)
    r["year_one_energy_cost_us_dollars"] = round(value(m[Symbol("TotalEnergyChargesUtil"*_n)]) / p.pwf_e, digits=2)

    r["total_demand_cost_us_dollars"] = round(value(m[Symbol("TotalDemandCharges"*_n)]) * (1 - p.offtaker_tax_pct), digits=2)
    r["year_one_demand_cost_us_dollars"] = round(value(m[Symbol("TotalDemandCharges"*_n)]) / p.pwf_e, digits=2)
    
    r["total_fixed_cost_us_dollars"] = round(m[Symbol("TotalFixedCharges"*_n)] * (1 - p.offtaker_tax_pct), digits=2)
    r["year_one_fixed_cost_us_dollars"] = round(m[Symbol("TotalFixedCharges"*_n)] / p.pwf_e, digits=0)

    r["total_min_charge_adder_us_dollars"] = round(value(m[Symbol("MinChargeAdder"*_n)]) * (1 - p.offtaker_tax_pct), digits=2)
    r["year_one_min_charge_adder_us_dollars"] = round(value(m[Symbol("MinChargeAdder"*_n)]) / p.pwf_e, digits=2)

    r["year_one_bill_us_dollars"] = r["year_one_energy_cost_us_dollars"] + r["year_one_demand_cost_us_dollars"] +
                                    r["year_one_fixed_cost_us_dollars"]  + r["year_one_min_charge_adder_us_dollars"]
                                
    r["total_export_benefit_us_dollars"] = -1 * round(value(m[Symbol("TotalExportBenefit"*_n)]) * (1 - p.offtaker_tax_pct), digits=2)
    r["year_one_export_benefit_us_dollars"] = -1 * round(value(m[Symbol("TotalExportBenefit"*_n)]) / p.pwf_e, digits=0)
    
    d["ElectricTariff"] = r
    nothing
end


function add_electric_tariff_results(m::JuMP.AbstractModel, p::MPCInputs, d::Dict; _n="")
    r = Dict{String, Any}()
    m[Symbol("energy_purchased"*_n)] = p.hours_per_timestep * 
        sum(m[Symbol("dvGridPurchase"*_n)][ts] for ts in p.time_steps)

    r["energy_cost_us_dollars"] = round(value(m[Symbol("TotalEnergyChargesUtil"*_n)]), digits=2)

    r["demand_cost_us_dollars"] = round(value(m[Symbol("TotalDemandCharges"*_n)]), digits=2)
                                
    r["export_benefit_us_dollars"] = -1 * round(value(m[Symbol("TotalExportBenefit"*_n)]), digits=0)
    
    d["ElectricTariff"] = r
    nothing
end