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
    add_financial_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")

Adds the Financial results to the dictionary passed back from `run_reopt` using the solved model `m` and the `REoptInputs` for node `_n`.
Note: the node number is an empty string if evaluating a single `Site`.

Financial results:
- `lcc` Optimal lifecycle cost
- `net_capital_costs_plus_om` Capital cost for all technologies plus present value of operations and maintenance over anlaysis period
- `net_capital_costs` Net capital costs for all technologies, in present value, including replacement costs and incentives.
"""
function add_financial_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict; _n="")
    r = Dict{String, Any}()
    r["lcc"] = round(value(m[Symbol("Costs"*_n)]) + 0.0001 * value(m[Symbol("MinChargeAdder"*_n)]))
    r["net_capital_costs_plus_om"] = round(
        value(m[Symbol("TotalTechCapCosts"*_n)] + m[Symbol("TotalStorageCapCosts"*_n)]) +
        value(m[Symbol("TotalPerUnitSizeOMCosts"*_n)]) * (1 - p.owner_tax_pct), digits=0
    )
    r["net_capital_costs"] = round(value(m[Symbol("TotalTechCapCosts"*_n)] + m[Symbol("TotalStorageCapCosts"*_n)]), 
                                   digits=2)
    d["Financial"] = r
    nothing
end