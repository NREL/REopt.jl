# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

function add_existing_hydropower_constraints(m,p)

	# Power out is flow rate times the efficiency
		# TODO: double check that this conversion is correct with the 1 hr to 15 min time steps
	@constraint(m, [ts in p.time_steps],
		m[:dvHydroPowerOut][ts] == m[:dvWaterOutFlow] * (p.s.existing_hydropower.efficiency_kwh_per_cubicmeter * p.hours_per_time_step) # convert to kW/time step, for instance: m3/15min  * kwh/m3 * (0.25 hrs/1hr)
	
	)

	# Total water volume is between the max and min levels
	@constraint(m, [ts in p.time_steps],
		m[:dvWaterVolume][ts] <= p.s.existing_hydropower.cubic_meter_maximum
	)
	@constraint(m, [ts in p.time_steps],
		p.s.existing_hydropower.cubic_meter_minimum <= m[:dvWaterVolume][ts] 
	)

	# Water flow rate is between the maximum and minimum allowable levels
	@constraint(m, [ts in p.time_steps],
		minimum_water_output_cubic_meter_per_second <= m[:dvWaterOutFlow][ts]
	)
	@constraint(m, [ts in p.time_steps],
		m[:dvWaterOutFlow][ts] <= p.s.existing_hydropower.existing_kw / (p.s.existing_hydropower.efficiency_kwh_per_cubicmeter * p.hours_per_time_step)
	)

	# The total water volume changes based on the water flow rates
	@constraint(m, [ts in 2:p.time_steps], m[:dvWaterVolume][ts] == m[:dvWaterVolume][ts-1] + p.s.existing_hydropower.water_inflow_cubic_meter_per_second - m[:dvWaterOutFlow][ts])
	@constraint(m, m[:dvWaterVolume][1] == 15)
	
	# Total power out equals sum of all power outputs
	@constraint(m,[ts in p.time_steps],
		m[:dvHydroPowerOut][ts] == m[:dvHydroToGrid][ts] + m[:dvHydroToStorage][ts] + m[:dvHydroToLoad][ts]
	)

	# Limit power output from the hydropower plant to the existing kW capacity:
	@constraint(m, [ts in p.time_steps], m[:dvHydroPowerOut][ts] <= p.s.existing_hydropower.existing_kw)

end

