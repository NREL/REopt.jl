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
function add_fuel_burn_constraints(m,p; _n="")
	fuel_slope_gal_per_kwhe, fuel_intercept_gal_per_hr = fuel_slope_and_intercept(
		electric_efficiency_full_load=p.s.generator.electric_efficiency_full_load, 
		electric_efficiency_half_load=p.s.generator.electric_efficiency_half_load,
		fuel_higher_heating_value_kwh_per_unit=p.s.generator.fuel_higher_heating_value_kwh_per_gal
	)
  	@constraint(m, [t in p.techs.gen, ts in p.time_steps],
		m[Symbol("dvFuelUsage"*_n)][t, ts] == (fuel_slope_gal_per_kwhe * p.s.generator.fuel_higher_heating_value_kwh_per_gal *
		p.production_factor[t, ts] * p.hours_per_time_step * m[Symbol("dvRatedProduction"*_n)][t, ts]) +
		(fuel_intercept_gal_per_hr * p.s.generator.fuel_higher_heating_value_kwh_per_gal * p.hours_per_time_step * m[Symbol("binGenIsOnInTS"*_n)][t, ts])
	)
	@constraint(m,
		sum(m[Symbol("dvFuelUsage"*_n)][t, ts] for t in p.techs.gen, ts in p.time_steps) <=
		p.s.generator.fuel_avail_gal * p.s.generator.fuel_higher_heating_value_kwh_per_gal
	)
end


function add_binGenIsOnInTS_constraints(m,p; _n="")
	# Generator must be on for nonnegative output
	@constraint(m, [t in p.techs.gen, ts in p.time_steps],
		m[Symbol("dvRatedProduction"*_n)][t, ts] <= p.max_sizes[t] * m[Symbol("binGenIsOnInTS"*_n)][t, ts]
	)
	# Note: min_turn_down_fraction is only enforced when `off_grid_flag` is true and in p.time_steps_with_grid, but not for grid outages for on-grid analyses
	if p.s.settings.off_grid_flag 
		@constraint(m, [t in p.techs.gen, ts in p.time_steps_without_grid],
			p.s.generator.min_turn_down_fraction * m[Symbol("dvSize"*_n)][t] - m[Symbol("dvRatedProduction"*_n)][t, ts] <=
			p.max_sizes[t] * (1 - m[Symbol("binGenIsOnInTS"*_n)][t, ts])
		)
	else 
		@constraint(m, [t in p.techs.gen, ts in p.time_steps_with_grid],
			p.s.generator.min_turn_down_fraction * m[Symbol("dvSize"*_n)][t] - m[Symbol("dvRatedProduction"*_n)][t, ts] <=
			p.max_sizes[t] * (1 - m[Symbol("binGenIsOnInTS"*_n)][t, ts])
		)
	end 
end


function add_gen_can_run_constraints(m,p; _n="")
	if p.s.generator.only_runs_during_grid_outage
		for ts in p.time_steps_with_grid, t in p.techs.gen
			fix(m[Symbol("dvRatedProduction"*_n)][t, ts], 0.0, force=true)
		end
	end

	if !(p.s.generator.sells_energy_back_to_grid)
		for t in p.techs.gen, u in p.export_bins_by_tech[t], ts in p.time_steps
			fix(m[Symbol("dvProductionToGrid"*_n)][t, u, ts], 0.0, force=true)
		end
	end
end


function add_gen_rated_prod_constraint(m, p; _n="")
	@constraint(m, [t in p.techs.gen, ts in p.time_steps],
		m[Symbol("dvSize"*_n)][t] >= m[Symbol("dvRatedProduction"*_n)][t, ts]
	)
end


"""
    add_gen_constraints(m, p)

Add Generator operational constraints and cost expressions.
"""
function add_gen_constraints(m, p; _n="")
    add_fuel_burn_constraints(m,p, _n=_n)
    add_binGenIsOnInTS_constraints(m,p, _n=_n)
    add_gen_can_run_constraints(m,p, _n=_n)
    add_gen_rated_prod_constraint(m,p, _n=_n)

    m[Symbol("TotalGenPerUnitProdOMCosts"*_n)] = @expression(m, p.third_party_factor * p.pwf_om *
        sum(p.s.generator.om_cost_per_kwh * p.hours_per_time_step *
        m[Symbol("dvRatedProduction"*_n)][t, ts] for t in p.techs.gen, ts in p.time_steps)
    )
    m[Symbol("TotalGenFuelCosts"*_n)] = @expression(m, 
		sum(p.pwf_fuel[t] * m[Symbol("dvFuelUsage"*_n)][t,ts] * p.fuel_cost_per_kwh[t][ts] for t in p.techs.gen, ts in p.time_steps) 
	)
end
