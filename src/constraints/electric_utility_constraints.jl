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
function add_egat_constraints(m, p; _n="")
    ##Constraint for EGAT to limit imported power to line limit at each timestep
    @constraint(m, ElecImportMaxCon[ts in p.time_steps_with_grid],
        100000 >=
        sum( m[Symbol("dvGridPurchase"*_n)][ts,tier] for tier in 1:p.s.electric_tariff.n_energy_tiers ) -
        sum( m[Symbol("dvProductionToGrid"*_n)][t, u, ts] for t in p.techs.elec, u in p.export_bins_by_tech[t] )
    )

end

function add_export_constraints(m, p; _n="")

    ##Constraint (8e): Production export and curtailment no greater than production
    @constraint(m, [t in p.techs.elec, ts in p.time_steps_with_grid],
        p.production_factor[t,ts] * p.levelization_factor[t] * m[Symbol("dvRatedProduction"*_n)][t,ts] 
        >= sum(m[Symbol("dvProductionToGrid"*_n)][t, u, ts] for u in p.export_bins_by_tech[t]) +
           m[Symbol("dvCurtail"*_n)][t, ts]
    )

    binNEM = 0
    binWHL = 0
    NEM_benefit = 0
    EXC_benefit = 0
    WHL_benefit = 0
    NEM_techs = String[t for t in p.techs.elec if :NEM in p.export_bins_by_tech[t]]
    WHL_techs = String[t for t in p.techs.elec if :WHL in p.export_bins_by_tech[t]]

    if !isempty(NEM_techs)
        # Constraint (9c): Net metering only -- can't sell more than you purchase
        # hours_per_timestep is cancelled on both sides, but used for unit consistency (convert power to energy)
        @constraint(m,
            p.hours_per_timestep * sum( m[Symbol("dvProductionToGrid"*_n)][t, :NEM, ts] 
            for t in NEM_techs, ts in p.time_steps)
            <= p.hours_per_timestep * sum( m[Symbol("dvGridPurchase"*_n)][ts, tier]
                for ts in p.time_steps, tier in 1:p.s.electric_tariff.n_energy_tiers)
        )

        if p.s.electric_utility.net_metering_limit_kw == p.s.electric_utility.interconnection_limit_kw && isempty(WHL_techs)
            # no need for binNEM nor binWHL
            binNEM = 1
            @constraint(m,
                sum(m[Symbol("dvSize"*_n)][t] for t in NEM_techs) <= p.s.electric_utility.interconnection_limit_kw
            )
            NEM_benefit = @expression(m, p.pwf_e * p.hours_per_timestep *
                sum( sum(p.s.electric_tariff.export_rates[:NEM][ts] * m[Symbol("dvProductionToGrid"*_n)][t, :NEM, ts] 
                    for t in p.techs_by_exportbin[:NEM]) for ts in p.time_steps)
            )
            if :EXC in p.s.electric_tariff.export_bins
                EXC_benefit = @expression(m, p.pwf_e * p.hours_per_timestep *
                    sum( sum(p.s.electric_tariff.export_rates[:EXC][ts] * m[Symbol("dvProductionToGrid"*_n)][t, :EXC, ts] 
                        for t in p.techs_by_exportbin[:EXC]) for ts in p.time_steps)
                )
            end
        else
            if !(isempty(_n))
                @error """Binaries decisions for net metering capacity limit is not implemented for multinode models to keep 
                            them linear. Please set the net metering limit to zero or equal to the interconnection limit."""
            end

            binNEM = @variable(m, binary = true)
            @warn "Adding binary variable for net metering choice. Some solvers are slow with binaries."

            # Good to bound the benefit
            max_bene = sum([ld*rate for (ld,rate) in zip(p.s.electric_load.loads_kw, p.s.electric_tariff.export_rates[:NEM])])*10
            NEM_benefit = @variable(m, lower_bound = max_bene)

            # If choosing to take advantage of NEM, must have total capacity less than net_metering_limit_kw
            @constraint(m,
                binNEM => {sum(m[Symbol("dvSize"*_n)][t] for t in NEM_techs) <= p.s.electric_utility.net_metering_limit_kw}
            )
            @constraint(m,
                !binNEM => {sum(m[Symbol("dvSize"*_n)][t] for t in NEM_techs) <= p.s.electric_utility.interconnection_limit_kw}
            )

            # binary choice for NEM benefit
            @constraint(m,
                binNEM => {NEM_benefit >= p.pwf_e * p.hours_per_timestep *
                    sum( sum(p.s.electric_tariff.export_rates[:NEM][ts] * m[Symbol("dvProductionToGrid"*_n)][t, :NEM, ts] 
                        for t in p.techs_by_exportbin[:NEM]) for ts in p.time_steps)
                }
            )
            @constraint(m, !binNEM => {NEM_benefit >= 0})

            EXC_benefit = 0
            if :EXC in p.s.electric_tariff.export_bins
                EXC_benefit = @variable(m, lower_bound = max_bene)
                @constraint(m,
                    binNEM => {EXC_benefit >= p.pwf_e * p.hours_per_timestep *
                        sum( sum(p.s.electric_tariff.export_rates[:EXC][ts] * m[Symbol("dvProductionToGrid"*_n)][t, :EXC, ts] 
                            for t in p.techs_by_exportbin[:EXC]) for ts in p.time_steps)
                    }
                )
                @constraint(m, !binNEM => {EXC_benefit >= 0})
            end
        end
    end

    if !isempty(WHL_techs)

        if typeof(binNEM) <: Real  # no need for wholesale binary
            binWHL = 1
            WHL_benefit = @expression(m, p.pwf_e * p.hours_per_timestep *
                sum( sum(p.s.electric_tariff.export_rates[:WHL][ts] * m[Symbol("dvProductionToGrid"*_n)][t, :WHL, ts] 
                        for t in p.techs_by_exportbin[:WHL]) for ts in p.time_steps)
            )
        else
            binWHL = @variable(m, binary = true)
            @warn "Adding binary variable for wholesale export choice. Some solvers are slow with binaries."
            max_bene = sum([ld*rate for (ld,rate) in zip(p.s.electric_load.loads_kw, p.s.electric_tariff.export_rates[:WHL])])*10
            WHL_benefit = @variable(m, lower_bound = max_bene)

            @constraint(m, binNEM + binWHL == 1)  # can either NEM or WHL export, not both

            @constraint(m,
                binWHL => {WHL_benefit >= p.pwf_e * p.hours_per_timestep *
                    sum( sum(p.s.electric_tariff.export_rates[:WHL][ts] * m[Symbol("dvProductionToGrid"*_n)][t, :WHL, ts] 
                            for t in p.techs_by_exportbin[:WHL]) for ts in p.time_steps)
                }
            )
            @constraint(m, !binWHL => {WHL_benefit >= 0})
        end
    end

    # register the benefits in the model
    m[Symbol("NEM_benefit"*_n)] = NEM_benefit
    m[Symbol("EXC_benefit"*_n)] = EXC_benefit
    m[Symbol("WHL_benefit"*_n)] = WHL_benefit
    nothing
end


"""
    add_monthly_peak_constraint(m, p; _n="")

Only used if ElectricTariff has monthly demand rates.
Sets dvPeakDemandMonth to greater than dvGridPurchase across each month.
If the monthly demand rate is tiered than also adds binMonthlyDemandTier and constraints.
"""
function add_monthly_peak_constraint(m, p; _n="")

	## Constraint (11d): Monthly peak demand is >= demand at each hour in the month
    if (!isempty(p.techs.chp)) && !(p.s.chp.reduces_demand_charges)
        @constraint(m, [mth in p.months, ts in p.s.electric_tariff.time_steps_monthly[mth]],
            sum(m[Symbol("dvPeakDemandMonth"*_n)][mth, t] for t in 1:p.s.electric_tariff.n_monthly_demand_tiers) 
            >= sum(m[Symbol("dvGridPurchase"*_n)][ts, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) + 
            sum(p.production_factor[t, ts] * p.levelization_factor[t] * m[Symbol("dvRatedProduction"*_n)][t, ts] for t in p.techs.chp) - 
            sum(sum(m[Symbol("dvProductionToStorage"*_n)][b, t, ts] for b in p.s.storage.types) for t in p.techs.chp) -
            sum(sum(m[Symbol("dvProductionToGrid")][t,u,ts] for u in p.export_bins_by_tech[t]) for t in p.techs.chp)
                
        )
    else
        @constraint(m, [mth in p.months, ts in p.s.electric_tariff.time_steps_monthly[mth]],
            sum(m[Symbol("dvPeakDemandMonth"*_n)][mth, t] for t in 1:p.s.electric_tariff.n_monthly_demand_tiers) 
                >= sum(m[Symbol("dvGridPurchase"*_n)][ts, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers)
        )
    end

    if p.s.electric_tariff.n_monthly_demand_tiers > 1  # only need binaries if more than one tier
        @warn "Adding binary variables to model monthly demand tiers."
        ntiers = p.s.electric_tariff.n_monthly_demand_tiers
        dv = "binMonthlyDemandTier" * _n
        m[Symbol(dv)] = @variable(m, [p.months, 1:ntiers], binary = true, base_name = dv)
        b = m[Symbol(dv)]
        # Upper bound on peak electrical power demand by month, tier; if tier is selected (0 o.w.)
        @constraint(m, [mth in p.months, tier in 1:ntiers],
            m[Symbol("dvPeakDemandMonth"*_n)][mth, tier] <= p.s.electric_tariff.monthly_demand_tier_limits[tier] * 
                b[mth, tier]
        )

        # Monthly peak electrical power demand tier ordering
        @constraint(m, [mth in p.months, tier in 2:ntiers], b[mth, tier] <= b[mth, tier-1])

        # One monthly peak electrical power demand tier must be full before next one is active
        @constraint(m, [mth in p.months, tier in 2:ntiers],
        b[mth, tier] * p.s.electric_tariff.monthly_demand_tier_limits[tier-1] <= 
            m[Symbol("dvPeakDemandMonth"*_n)][mth, tier-1]
        )
        # TODO implement NewMaxDemandMonthsInTier, which adds mth index to monthly_demand_tier_limits
    end
end


function add_tou_peak_constraint(m, p; _n="")
    ## Constraint (12d): Ratchet peak demand is >= demand at each hour in the ratchet` 
    @constraint(m, [r in p.ratchets, ts in p.s.electric_tariff.tou_demand_ratchet_timesteps[r]],
        sum(m[Symbol("dvPeakDemandTOU"*_n)][r, tier] for tier in 1:p.s.electric_tariff.n_tou_demand_tiers) >= 
        sum(m[Symbol("dvGridPurchase"*_n)][ts, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers)
    )

    if p.s.electric_tariff.n_tou_demand_tiers > 1
        @warn "Adding binary variables to model TOU demand tiers."
        ntiers = p.s.electric_tariff.n_tou_demand_tiers
        dv = "binTOUDemandTier" * _n
        m[Symbol(dv)] = @variable(m, [p.ratchets, 1:ntiers], binary = true, base_name = dv)
        b = m[Symbol(dv)]

        # Upper bound on peak electrical power demand by tier, by ratchet, if tier is selected (0 o.w.)
        @constraint(m, [r in p.ratchets, tier in 1:ntiers],
            m[Symbol("dvPeakDemandTOU"*_n)][r, tier] <= p.s.electric_tariff.tou_demand_tier_limits[tier] * b[r, tier]
        )

        # Ratchet peak electrical power ratchet tier ordering
        @constraint(m, [r in p.ratchets, tier in 2:ntiers],
            b[r, tier] <= b[r, tier-1]
        )

        # One ratchet peak electrical power demand tier must be full before next one is active
        @constraint(m, [r in p.ratchets, tier in 2:ntiers],
            b[r, tier] * p.s.electric_tariff.tou_demand_tier_limits[tier-1] 
            <= m[Symbol("dvPeakDemandTOU"*_n)][r, tier-1]
        )

        # Ratchet peak demand is >= demand at each hour in the ratchet
        @constraint(m, [r in p.ratchets, ts in p.s.electric_tariff.tou_demand_ratchet_timesteps[r]],
            sum(m[Symbol("dvPeakDemandTOU"*_n)][r, tier] for tier in 1:ntiers) 
            >= sum( m[Symbol("dvGridPurchase"*_n)][ts, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers )
        )
    end
    # TODO implement NewMaxDemandInTier
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
          sum(m[Symbol("dvGridPurchase"*_n)][ts, tier] for tier in 1:p.s.electric_tariff.n_energy_tiers) +
          sum(m[Symbol("dvGridToStorage"*_n)][b, ts] for b in p.s.storage.types) <= 0
        }
    )
    @constraint(m, ExportOnlyAfterSiteLoadMetCon[ts in p.time_steps],
        !m[Symbol("binNoGridPurchases"*_n)][ts] => {
            sum(m[Symbol("dvProductionToGrid"*_n)][t,u,ts] for t in p.techs.elec, u in p.export_bins_by_tech[t]) <= 0
        }
    )
end


"""
    add_energy_tier_constraints(m, p; _n="")

Only necessary if n_energy_tiers > 1
"""
function add_energy_tier_constraints(m, p; _n="")
    @warn "Adding binary variables to model energy cost tiers."
    ntiers = p.s.electric_tariff.n_energy_tiers
    dv = "binEnergyTier" * _n
    m[Symbol(dv)] = @variable(m, [p.months, 1:ntiers], binary = true, base_name = dv)
    b = m[Symbol(dv)]
    ##Constraint (10a): Usage limits by pricing tier, by month
    @constraint(m, [mth in p.months, tier in 1:p.s.electric_tariff.n_energy_tiers],
        p.hours_per_timestep * sum( m[Symbol("dvGridPurchase"*_n)][ts, tier] for ts in p.s.electric_tariff.time_steps_monthly[mth] ) 
        <= b[mth, tier] * p.s.electric_tariff.energy_tier_limits[tier]
    )
    ##Constraint (10b): Ordering of pricing tiers
    @constraint(m, [mth in p.months, tier in 2:p.s.electric_tariff.n_energy_tiers],
        b[mth, tier] - b[mth, tier-1] <= 0
    )
    ## Constraint (10c): One tier must be full before any usage in next tier
    @constraint(m, [mth in p.months, tier in 2:p.s.electric_tariff.n_energy_tiers],
        b[mth, tier] * p.s.electric_tariff.energy_tier_limits[tier-1] - 
        sum( m[Symbol("dvGridPurchase"*_n)][ts, tier-1] for ts in p.s.electric_tariff.time_steps_monthly[mth]) 
        <= 0
    )
    # TODO implement NewMaxUsageInTier
end


"""
    add_demand_lookback_constraints(m, p; _n="")

Only necessary if ElectricTariff.demand_lookback_percent > 0
"""
function add_demand_lookback_constraints(m, p; _n="")
    dv = "dvPeakDemandLookback" * _n
    m[Symbol(dv)] = @variable(m, [p.months], base_name = dv, lower_bound = 0)

	if p.s.electric_tariff.demand_lookback_range != 0  # then the dvPeakDemandLookback varies by month

		##Constraint (12e): dvPeakDemandLookback is the highest peak demand in DemandLookbackMonths
		for mth in p.months
			if mth > p.s.electric_tariff.demand_lookback_range
				@constraint(m, [lm in 1:p.s.electric_tariff.demand_lookback_range, ts in p.s.electric_tariff.time_steps_monthly[mth - lm]],
					m[Symbol(dv)][mth] ≥ sum( m[Symbol("dvGridPurchase"*_n)][ts, tier] 
                                              for tier in 1:p.s.electric_tariff.n_energy_tiers )
				)
			else  # need to handle rollover months
				for lm in 1:p.s.electric_tariff.demand_lookback_range
					lkbkmonth = mth - lm
					if lkbkmonth ≤ 0
						lkbkmonth += 12
					end
					@constraint(m, [ts in p.s.electric_tariff.time_steps_monthly[lkbkmonth]],
						m[Symbol(dv)][mth] ≥ sum( m[Symbol("dvGridPurchase"*_n)][ts, tier] 
                                                  for tier in 1:p.s.electric_tariff.n_energy_tiers )
					)
				end
			end
		end

		##Constraint (12f): Ratchet peak demand charge is bounded below by lookback
		@constraint(m, [mth in p.months],
			sum( m[Symbol("dvPeakDemandMonth"*_n)][mth, tier] for tier in 1:p.s.electric_tariff.n_monthly_demand_tiers ) >=
			p.s.electric_tariff.demand_lookback_percent * m[Symbol(dv)][mth]
		)

	else  # dvPeakDemandLookback does not vary by month

		##Constraint (12e): dvPeakDemandLookback is the highest peak demand in DemandLookbackMonths
		@constraint(m, [lm in p.s.electric_tariff.demand_lookback_months],
			m[Symbol(dv)][1] >= sum(m[Symbol("dvPeakDemandMonth"*_n)][lm, tier] for tier in 1:p.s.electric_tariff.n_monthly_demand_tiers)
		)

		##Constraint (12f): Ratchet peak demand charge is bounded below by lookback
		@constraint(m, [mth in p.months],
			sum( m[Symbol("dvPeakDemandMonth"*_n)][mth, tier] for tier in 1:p.s.electric_tariff.n_monthly_demand_tiers ) >=
			p.s.electric_tariff.demand_lookback_percent * m[Symbol(dv)][1]
		)
	end
end


function add_coincident_peak_charge_constraints(m, p; _n="")
	## Constraint (14a): in each coincident peak period, charged CP demand is the max of demand in all CP timesteps
    dv = "dvPeakDemandCP" * _n
    m[Symbol(dv)] = @variable(m, [p.s.electric_tariff.coincpeak_periods], lower_bound = 0, base_name = dv)
	@constraint(m, 
        [prd in p.s.electric_tariff.coincpeak_periods, 
         ts in p.s.electric_tariff.coincident_peak_load_active_timesteps[prd]],
		m[Symbol("dvPeakDemandCP"*_n)][prd] >= sum(m[Symbol("dvGridPurchase"*_n)][ts, tier] 
                                                                      for tier in 1:p.s.electric_tariff.n_energy_tiers)
	)
end


function add_elec_utility_expressions(m, p; _n="")

    if !isempty(p.s.electric_tariff.export_bins) && !isempty(p.techs.all)
        # NOTE: levelization_factor is baked into dvProductionToGrid
        m[Symbol("TotalExportBenefit"*_n)] = m[Symbol("NEM_benefit"*_n)] + m[Symbol("WHL_benefit"*_n)] +
                                             m[Symbol("EXC_benefit"*_n)]
    else
        m[Symbol("TotalExportBenefit"*_n)] = 0
    end

    m[Symbol("TotalEnergyChargesUtil"*_n)] = @expression(m, p.pwf_e * p.hours_per_timestep * 
        sum( p.s.electric_tariff.energy_rates[ts, tier] * m[Symbol("dvGridPurchase"*_n)][ts, tier] 
            for ts in p.time_steps, tier in 1:p.s.electric_tariff.n_energy_tiers) 
    )

    if !isempty(p.s.electric_tariff.tou_demand_rates)
        m[Symbol("DemandTOUCharges"*_n)] = @expression(m, 
            p.pwf_e * sum( p.s.electric_tariff.tou_demand_rates[r] * m[Symbol("dvPeakDemandTOU"*_n)][r, tier] 
            for r in p.ratchets, tier in p.s.electric_tariff.n_tou_demand_tiers)
        )
    else
        m[Symbol("DemandTOUCharges"*_n)] = 0
    end
    
    if !isempty(p.s.electric_tariff.monthly_demand_rates)
        m[Symbol("DemandFlatCharges"*_n)] = @expression(m, p.pwf_e * 
            sum( p.s.electric_tariff.monthly_demand_rates[mth, t] * m[Symbol("dvPeakDemandMonth"*_n)][mth, t] 
                for mth in p.months, t in 1:p.s.electric_tariff.n_monthly_demand_tiers) 
        )
    else
        m[Symbol("DemandFlatCharges"*_n)] = 0
    end

    m[Symbol("TotalDemandCharges"*_n)] = m[Symbol("DemandTOUCharges"*_n)] + m[Symbol("DemandFlatCharges"*_n)]

    m[Symbol("TotalFixedCharges"*_n)] = p.pwf_e * p.s.electric_tariff.fixed_monthly_charge * 12
        
    if p.s.electric_tariff.annual_min_charge > 12 * p.s.electric_tariff.min_monthly_charge
        m[Symbol("TotalMinCharge"*_n)] = p.s.electric_tariff.annual_min_charge 
    else
        m[Symbol("TotalMinCharge"*_n)] = 12 * p.s.electric_tariff.min_monthly_charge
    end

	if m[Symbol("TotalMinCharge"*_n)] >= 1e-2
		add_mincharge_constraint(m, p)
	else
		@constraint(m, m[Symbol("MinChargeAdder"*_n)] == 0)
	end

    if !isempty(p.s.electric_tariff.coincpeak_periods)
        m[Symbol("TotalCPCharges"*_n)] = @expression(m, p.pwf_e * 
            sum( p.s.electric_tariff.coincident_peak_load_charge_per_kw[prd] * m[Symbol("dvPeakDemandCP"*_n)][prd] 
                for prd in p.s.electric_tariff.coincpeak_periods ) 
        )
    else
        m[Symbol("TotalCPCharges"*_n)] = 0
    end

    m[Symbol("TotalElecBill"*_n)] = (
        m[Symbol("TotalEnergyChargesUtil"*_n)] 
        + m[Symbol("TotalDemandCharges"*_n)] 
        + m[Symbol("TotalExportBenefit"*_n)] 
        + m[Symbol("TotalFixedCharges"*_n)] 
        + m[Symbol("TotalCPCharges"*_n)]
        + 0.999 * m[Symbol("MinChargeAdder"*_n)]
    )
    #= Note: 0.999 * MinChargeAdder in Objective b/c when 
        TotalMinCharge > (TotalEnergyCharges + TotalDemandCharges + TotalExportBenefit + TotalFixedCharges)
		it is arbitrary where the min charge ends up (eg. could be in TotalDemandCharges or MinChargeAdder).
		0.001 * MinChargeAdder is added back into LCC when writing to results.  
    =#
    nothing
end