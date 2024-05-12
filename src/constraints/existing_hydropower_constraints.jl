# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

function add_existing_hydropower_constraints(m,p)
	print("\n Adding constraints for existing hydropower")
	# Power out is flow rate times the efficiency
		# TODO: double check that this conversion is correct with the 1 hr to 15 min time steps
	@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
		#m[:dvHydroPowerOut][ts] == m[:dvWaterOutFlow][ts] * (p.s.existing_hydropower.efficiency_kwh_per_cubicmeter * p.hours_per_time_step) # convert to kW/time step, for instance: m3/15min  * kwh/m3 * (0.25 hrs/1hr)
		m[:dvRatedProduction][t,ts] == m[:dvWaterOutFlow][ts] * (p.s.existing_hydropower.efficiency_kwh_per_cubicmeter * p.hours_per_time_step) # convert to kW/time step, for instance: m3/15min  * kwh/m3 * (0.25 hrs/1hr)
	
	)

	#@constraint(m, [ts in p.time_steps],
	#		m[:dvWaterOutFlow][1] == 5
	#	)


	# Total water volume is between the max and min levels
	@constraint(m, [ts in p.time_steps],
		m[:dvWaterVolume][ts] <= p.s.existing_hydropower.cubic_meter_maximum
	)
	@constraint(m, [ts in p.time_steps],
		p.s.existing_hydropower.cubic_meter_minimum <= m[:dvWaterVolume][ts] 
	)

	# Temporary Constraint for preventing all production from hydropower's RatedProductionVariable
	#@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
	#	m[Symbol("dvRatedProduction")][t,ts] == 0 
	#	)

	# Water flow rate is between the maximum and minimum allowable levels
	@constraint(m, [ts in p.time_steps], #, t in p.techs.existing_hydropower],
		p.s.existing_hydropower.minimum_water_output_cubic_meter_per_second_per_turbine <= m[:dvWaterOutFlow][ts]
	)
	@constraint(m, [ts in p.time_steps], #, t in p.techs.existing_hydropower],
		m[:dvWaterOutFlow][ts] <= p.s.existing_hydropower.existing_kw_per_turbine / (p.s.existing_hydropower.efficiency_kwh_per_cubicmeter * p.hours_per_time_step)
	)

	# The total water volume changes based on the water flow rates
	@constraint(m, [ts in p.time_steps[2:end]], m[:dvWaterVolume][ts] == m[:dvWaterVolume][ts-1] + p.s.existing_hydropower.water_inflow_cubic_meter_per_second[ts] - m[:dvWaterOutFlow][ts]) # sum(m[:dvWaterOutFlow][t,ts] for t in p.techs.existing_hydropower))
	@constraint(m, m[:dvWaterVolume][1] == p.s.existing_hydropower.initial_reservoir_volume) 
	
	# Total power out must be less than or equal to 
	#@constraint(m,[ts in p.time_steps, t in p.techs.existing_hydropower],
		#m[:dvHydroPowerOut][ts] == m[:dvHydroToGrid][ts] + m[:dvHydroToStorage][ts] + m[:dvHydroToLoad][ts]
	#)

	# Limit power output from the hydropower plant to the existing kW capacity:
	@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:dvRatedProduction][t,ts] <= p.s.existing_hydropower.existing_kw_per_turbine)

end

