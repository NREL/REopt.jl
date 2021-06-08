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
function add_export_constraints(m, p; _n="")

    ##Constraint (8e): Production export no greater than production
    @constraint(m, [t in p.techs, ts in p.time_steps_with_grid],
        p.production_factor[t,ts] * p.levelization_factor[t] * m[Symbol("dvRatedProduction"*_n)][t,ts] >= 
        m[Symbol("dvWHLexport"*_n)][t, ts] + m[Symbol("dvNEMexport"*_n)][t, ts] + m[Symbol("dvCurtail"*_n)][t, ts]
    )
    
    ##Constraint (8f): Total sales to grid no greater than annual allocation - storage tiers
    @constraint(m,
        p.hours_per_timestep * ( 
        sum( m[Symbol("dvWHLexport"*_n)][t, ts] for t in p.techs, ts in p.time_steps_with_grid)
        + sum( m[Symbol("dvNEMexport"*_n)][t, ts] for t in p.techs, ts in p.time_steps_with_grid)
        ) <= p.max_grid_export_kwh
    )

   ### Constraint set (9): Net Meter Module 
   ##Constraint (9c): Net metering only -- can't sell more than you purchase
   # note that hours_per_timestep is cancelled on both sides, but used for unit consistency (convert power to energy)
    @constraint(m,
        p.hours_per_timestep * 
        sum( m[Symbol("dvNEMexport"*_n)][t, ts] for t in p.techs, ts in p.time_steps)
        <= p.hours_per_timestep * sum( m[Symbol("dvGridPurchase"*_n)][ts] for ts in p.time_steps)
    )
end


function add_monthly_peak_constraint(m, p; _n="")
	## Constraint (11d): Monthly peak demand is >= demand at each hour in the month
	@constraint(m, [mth in p.months, ts in p.etariff.time_steps_monthly[mth]],
    m[Symbol("dvPeakDemandMonth"*_n)][mth] >= m[Symbol("dvGridPurchase"*_n)][ts]
    )
end


function add_tou_peak_constraint(m, p; _n="")
    ## Constraint (12d): Ratchet peak demand is >= demand at each hour in the ratchet` 
    @constraint(m, [r in p.ratchets, ts in p.etariff.tou_demand_ratchet_timesteps[r]],
        m[Symbol("dvPeakDemandTOU"*_n)][r] >= m[Symbol("dvGridPurchase"*_n)][ts]
    )
end


function add_mincharge_constraint(m, p; _n="")
    @constraint(m, MinChargeAddCon, 
        m[Symbol("MinChargeAdder"*_n)] >= m[Symbol("TotalMinCharge"*_n)] - ( m[Symbol("TotalEnergyChargesUtil"*_n)] + 
        m[Symbol("TotalDemandCharges"*_n)] + m[Symbol("TotalExportBenefit"*_n)] + m[Symbol("TotalFixedCharges"*_n)] )
    )
end


function add_simultaneous_export_import_constraint(m, p; _n="")
    @constraint(m, NoGridPurchasesBinary[ts in p.time_steps],
          m[Symbol("dvGridPurchase"*_n)][ts] 
        + sum(m[Symbol("dvGridToStorage"*_n)][b, ts] for b in p.storage.types)
        - (1 - m[Symbol("binNoGridPurchases"*_n)][ts]) * 1.0E9 <= 0
    )
    @constraint(m, ExportOnlyAfterSiteLoadMetCon[ts in p.time_steps],
          sum( m[Symbol("dvWHLexport"*_n)][t, ts] for t in p.techs )
        + sum( m[Symbol("dvNEMexport"*_n)][t, ts] for t in p.techs)
        - m[Symbol("binNoGridPurchases"*_n)][ts] * 1.0E9 <= 0
    )
end