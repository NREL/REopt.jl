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

    ##Constraint (8e): Production export and curtailment no greater than production
    @constraint(m, [t in p.elec_techs, ts in p.time_steps_with_grid],
        p.production_factor[t,ts] * p.levelization_factor[t] * m[Symbol("dvRatedProduction"*_n)][t,ts] 
        >= sum(m[Symbol("dvProductionToGrid"*_n)][t, u, ts] for u in p.export_bins_by_tech[t]) +
           m[Symbol("dvCurtail"*_n)][t, ts]
    )

    m[Symbol("NEMExportBenefit"*_n)] = 0
    binNEM = 0
    NEM_techs = String[t for t in p.elec_techs if :NEM in p.export_bins_by_tech[t]]
    WHL_techs = String[t for t in p.elec_techs if :WHL in p.export_bins_by_tech[t]]

    if !isempty(NEM_techs)

        # Constraint (9c): Net metering only -- can't sell more than you purchase
        # hours_per_timestep is cancelled on both sides, but used for unit consistency (convert power to energy)
        @constraint(m,
            p.hours_per_timestep * sum( m[Symbol("dvProductionToGrid"*_n)][t, :NEM, ts] 
            for t in NEM_techs, ts in p.time_steps)
            <= p.hours_per_timestep * sum( m[Symbol("dvGridPurchase"*_n)][ts] for ts in p.time_steps)
        )

        if p.elecutil.net_metering_limit_kw == p.elecutil.interconnection_limit_kw && isempty(WHL_techs)
            # no need for binNEM
            binNEM = 1
            @constraint(m,
                sum(m[Symbol("dvSize"*_n)][t] for t in NEM_techs) <= p.elecutil.interconnection_limit_kw
            )
        else
            if !(isempty(_n))
                @error """Binaries decisions for net metering capacity limit is not implemented for multinode models to keep 
                            them linear. Please set the net metering limit to zero or equal to the interconnection limit."""
            end
            binNEM = @variable(m, binary = true)

            # If choosing to take advantage of NEM, must have total capacity less than net_metering_limit_kw
            @constraint(m,
                binNEM => {sum(m[Symbol("dvSize"*_n)][t] for t in NEM_techs) <= p.elecutil.net_metering_limit_kw}
            )
            @constraint(m,
                !binNEM => {sum(m[Symbol("dvSize"*_n)][t] for t in NEM_techs) <= p.elecutil.interconnection_limit_kw}
            )
        end
        
        m[Symbol("NEMExportBenefit"*_n)] = @expression(m, binNEM * p.pwf_e * p.hours_per_timestep *
            sum( sum(p.etariff.export_rates[:NEM][ts] * m[Symbol("dvProductionToGrid"*_n)][t, :NEM, ts] 
                    for t in p.techs_by_exportbin[:NEM])
            for ts in p.time_steps)
        )
    end
    m[:binNEM] = binNEM

    m[Symbol("WHLExportBenefit"*_n)] = 0
    if !isempty(WHL_techs)
        @variable(m, binWHL, Bin)
        @constraint(m, binNEM + m[:binWHL] == 1)  # can either NEM or WHL export, not both
        m[Symbol("WHLExportBenefit"*_n)] = @expression(m, m[:binWHL] * p.pwf_e * p.hours_per_timestep *
            sum( sum(p.etariff.export_rates[:WHL][ts] * m[Symbol("dvProductionToGrid"*_n)][t, :WHL, ts] 
                    for t in p.techs_by_exportbin[:WHL])
            for ts in p.time_steps)
        )
    end
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
    @constraint(m, 
        m[Symbol("MinChargeAdder"*_n)] >= m[Symbol("TotalMinCharge"*_n)] - ( m[Symbol("TotalEnergyChargesUtil"*_n)] + 
        m[Symbol("TotalDemandCharges"*_n)] + m[Symbol("TotalExportBenefit"*_n)] + m[Symbol("TotalFixedCharges"*_n)] )
    )
end


function add_simultaneous_export_import_constraint(m, p; _n="")
    @constraint(m, NoGridPurchasesBinary[ts in p.time_steps],
        m[Symbol("binNoGridPurchases"*_n)][ts] => {
          m[Symbol("dvGridPurchase"*_n)][ts] +
          sum(m[Symbol("dvGridToStorage"*_n)][b, ts] for b in p.storage.types) <= 0
        }
    )
    @constraint(m, ExportOnlyAfterSiteLoadMetCon[ts in p.time_steps],
        !m[Symbol("binNoGridPurchases"*_n)][ts] => {
            sum(m[Symbol("dvProductionToGrid"*_n)][t,u,ts] for t in p.elec_techs, u in p.export_bins_by_tech[t]) <= 0
        }
    )
end


function add_elec_utility_expressions(m, p; _n="")

    if !isempty(p.etariff.export_bins) && !isempty(p.techs)
        # NOTE: levelization_factor is baked into dvProductionToGrid
        m[Symbol("TotalExportBenefit"*_n)] = m[Symbol("NEMExportBenefit"*_n)] + m[Symbol("WHLExportBenefit"*_n)]
        # TODO add EXC benefits
    else
        m[Symbol("TotalExportBenefit"*_n)] = 0
    end

    m[Symbol("TotalEnergyChargesUtil"*_n)] = @expression(m, p.pwf_e * p.hours_per_timestep * 
        sum( p.etariff.energy_rates[ts] * m[Symbol("dvGridPurchase"*_n)][ts] for ts in p.time_steps) 
    )

    if !isempty(p.etariff.tou_demand_rates)
        m[Symbol("DemandTOUCharges"*_n)] = @expression(m, 
            p.pwf_e * sum( p.etariff.tou_demand_rates[r] * m[Symbol("dvPeakDemandTOU"*_n)][r] for r in p.ratchets)
        )
    else
        m[Symbol("DemandTOUCharges"*_n)] = 0
    end
    
    if !isempty(p.etariff.monthly_demand_rates)
        m[Symbol("DemandFlatCharges"*_n)] = @expression(m, 
            p.pwf_e * sum( p.etariff.monthly_demand_rates[mth] * m[Symbol("dvPeakDemandMonth"*_n)][mth] for mth in p.months) 
        )
    else
        m[Symbol("DemandFlatCharges"*_n)] = 0
    end

    m[Symbol("TotalDemandCharges"*_n)] = m[Symbol("DemandTOUCharges"*_n)] + m[Symbol("DemandFlatCharges"*_n)]

    m[Symbol("TotalFixedCharges"*_n)] = p.pwf_e * p.etariff.fixed_monthly_charge * 12
        
    if p.etariff.annual_min_charge > 12 * p.etariff.min_monthly_charge
        m[Symbol("TotalMinCharge"*_n)] = p.etariff.annual_min_charge 
    else
        m[Symbol("TotalMinCharge"*_n)] = 12 * p.etariff.min_monthly_charge
    end

	if m[Symbol("TotalMinCharge"*_n)] >= 1e-2
		add_mincharge_constraint(m, p)
	else
		@constraint(m, m[Symbol("MinChargeAdder"*_n)] == 0)
	end

    m[Symbol("TotalElecBill"*_n)] = (
        m[Symbol("TotalEnergyChargesUtil"*_n)] 
        + m[Symbol("TotalDemandCharges"*_n)] 
        + m[Symbol("TotalExportBenefit"*_n)] 
        + m[Symbol("TotalFixedCharges"*_n)] 
        + 0.999 * m[Symbol("MinChargeAdder"*_n)]
    )
    #= Note: 0.999 * MinChargeAdder in Objective b/c when 
        TotalMinCharge > (TotalEnergyCharges + TotalDemandCharges + TotalExportBenefit + TotalFixedCharges)
		it is arbitrary where the min charge ends up (eg. could be in TotalDemandCharges or MinChargeAdder).
		0.001 * MinChargeAdder is added back into LCC when writing to results.  
    =#
    nothing
end