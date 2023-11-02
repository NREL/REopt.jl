# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
"""
    add_prod_incent_vars_and_constraints(m, p)

When pbi_techs is not empty this function is called to add the variables and constraints for modeling production based
incentives.
"""
function add_prod_incent_vars_and_constraints(m, p)

    @variable(m, dvProdIncent[p.techs.pbi] >= 0)
    @variable(m, binProdIncent[p.techs.pbi], Bin)

	##Constraint (6a)-1: Production Incentive Upper Bound
	@constraint(m, ProdIncentUBCon[t in p.techs.pbi],
		m[:dvProdIncent][t] <= m[:binProdIncent][t] * p.pbi_max_benefit[t] * p.pbi_pwf[t] * p.third_party_factor)

	##Constraint (6a)-2: Production Incentive According to Production
	@constraint(m, IncentByProductionCon[t in p.techs.pbi],
		m[:dvProdIncent][t] <= p.hours_per_time_step * p.pbi_benefit_per_kwh[t] * p.pbi_pwf[t] * p.third_party_factor *
			sum(p.production_factor[t, ts] * m[:dvRatedProduction][t,ts] for ts in p.time_steps)
	)
	##Constraint (6b): System size max to achieve production incentive
	@constraint(m, IncentBySystemSizeCon[t in p.techs.pbi],
		m[:dvSize][t]  <= p.pbi_max_kw[t] + p.max_sizes[t] * (1 - m[:binProdIncent][t])
    )

	m[:TotalProductionIncentive] = @expression(m, sum(m[:dvProdIncent][t] for t in p.techs.pbi))
end


"""
    add_timed_prod_incent_vars_and_constraints(m, p)

When timed_pbi_techs is not empty this function is called to add the variables and constraints for modeling timed production based
incentives. (for PV only)
"""
function add_timed_prod_incent_vars_and_constraints(m, p) # Added

    @variable(m, dvTimedProdIncent[p.techs.timed_pbi] >= 0)
    @variable(m, binTimedProdIncent[p.techs.timed_pbi], Bin)

	##Constraint (6a)-1: Production Incentive Upper Bound
	@constraint(m, TimedProdIncentUBCon[t in p.techs.timed_pbi],
		m[:dvTimedProdIncent][t] <= m[:binTimedProdIncent][t] * p.timed_pbi_max_benefit[t] * p.timed_pbi_pwf[t] * p.third_party_factor)

	# Determine time steps between 1-7pm 
	timed_pbi_time_steps = Int[]
	start_hr = 13 # 1pm
	end_hr = 19 # 7pm (noninclusive) (goes 1-7pm)
	datetime = DateTime(2017, 1, 1, 0) # starting at hour 0 because ts 1 = 12am = hour 0. Using 2017 bc not considering leap years
    for ts in p.time_steps
        hour = Hour(datetime).value
		if start_hr <= hour < end_hr
        	push!(timed_pbi_time_steps, ts)
		end
        datetime += Dates.Hour(1)
    end

	##Constraint (6a)-2: Production Incentive According to Production between 1-7pm 
	@constraint(m, TimedIncentByProductionCon[t in p.techs.timed_pbi],
		m[:dvTimedProdIncent][t] <= p.hours_per_time_step * p.timed_pbi_benefit_per_kwh[t] * p.timed_pbi_pwf[t] * p.third_party_factor *
			sum(p.production_factor[t, ts] * m[:dvRatedProduction][t,ts] for ts in timed_pbi_time_steps)
	)

	##Constraint (6b): System size max to achieve production incentive
	@constraint(m, TimedIncentBySystemSizeCon[t in p.techs.timed_pbi],
		m[:dvSize][t]  <= p.timed_pbi_max_kw[t] + p.max_sizes[t] * (1 - m[:binTimedProdIncent][t])
    )

	m[:TotalTimedProductionIncentive] = @expression(m, sum(m[:dvTimedProdIncent][t] for t in p.techs.timed_pbi))
end
