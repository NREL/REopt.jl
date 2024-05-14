# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

function add_existing_hydropower_constraints(m,p)
	print("\n Adding constraints for existing hydropower")
	# Power out is flow rate times the efficiency
	
	# define the efficiency based on the efficiency slope and y intercept
	
	if p.s.existing_hydropower.use_average_power_conversion == "no"
		print("\n Adding nonlinear constraints for hydropower")
		# currently these equations require a nonlinear solver (and haven't been tested yet)
		# TODO: try to formulate these nonlinear equations using approximation methods that are linear
			# These equations would more accurately model the behavior of the hydropower
		@constraint(m, [t in p.techs.existing_hydropower, ts in p.time_steps], 
						m[:TurbineEfficiency][t,ts] == p.s.existing_hydropower.efficiency_fraction_y_intercept + (m[:dvWaterOutFlow][t,ts] * p.s.existing_hydropower.efficiency_slope_fraction_per_cubic_meter_per_second)
					) 
		
		@constraint(m, [ts in p.time_steps], m[:ReservoirHead][ts] == m[:dvWaterVolume][ts] * p.s.existing_hydropower.linearized_stage_storage_slope) 

		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
			#m[:dvHydroPowerOut][ts] == m[:dvWaterOutFlow][ts] * (p.s.existing_hydropower.efficiency_kwh_per_cubicmeter * p.hours_per_time_step) # convert to kW/time step, for instance: m3/15min  * kwh/m3 * (0.25 hrs/1hr)
			m[:dvRatedProduction][t,ts] == 9810 * 0.001 * m[:dvWaterOutFlow][t,ts] * m[:TurbineEfficiency][t,ts] * m[:ReservoirHead][ts]  # p.hours_per_time_step) #(m[:TurbineEfficiency][t,ts]) convert to kW/time step, for instance: m3/15min  * kwh/m3 * (0.25 hrs/1hr)
		)
	elseif p.s.existing_hydropower.use_average_power_conversion == "yes"
		# This is a simplified constraint that uses an average conversion for water flow and kW output
		print("\n Adding linear constraints for hydropower")
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
				#m[:dvHydroPowerOut][ts] == m[:dvWaterOutFlow][ts] * (p.s.existing_hydropower.efficiency_kwh_per_cubicmeter * p.hours_per_time_step) # convert to kW/time step, for instance: m3/15min  * kwh/m3 * (0.25 hrs/1hr)
				m[:dvRatedProduction][t,ts] == m[:dvWaterOutFlow][t,ts] * (1/p.s.existing_hydropower.average_cubic_meters_per_second_per_kw) # p.hours_per_time_step) #(m[:TurbineEfficiency][t,ts]) convert to kW/time step, for instance: m3/15min  * kwh/m3 * (0.25 hrs/1hr)
			)
	else 
		throw(@error("Invalid input for the use_average_power_conversion field"))
	end

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
	@constraint(m, [ts in p.time_steps], # t in p.techs.existing_hydropower],
		 sum(m[:dvWaterOutFlow][t, ts] for t in p.techs.existing_hydropower) >= p.s.existing_hydropower.minimum_water_output_cubic_meter_per_second_total_of_all_turbines   # m[:dvWaterOutFlow][t, ts]
	)
	 
	@constraint(m, [t in p.techs.existing_hydropower, ts in p.time_steps], 
			m[:dvWaterOutFlow][t, ts] >=  m[:binTurbineActive][t,ts]*p.s.existing_hydropower.minimum_water_output_cubic_meter_per_second_per_turbine    #p.s.existing_hydropower.existing_kw_per_turbine / (p.s.existing_hydropower.efficiency_kwh_per_cubicmeter * p.hours_per_time_step)
		)

	# The total water volume changes based on the water flow rates
	@constraint(m, [ts in p.time_steps[2:end]], m[:dvWaterVolume][ts] == m[:dvWaterVolume][ts-1] + ((3600/p.s.settings.time_steps_per_hour)* (p.s.existing_hydropower.water_inflow_cubic_meter_per_second[ts] - sum(m[:dvWaterOutFlow][t,ts] for t in p.techs.existing_hydropower)))) # m[:dvWaterOutFlow][ts]) 
	@constraint(m, m[:dvWaterVolume][1] == p.s.existing_hydropower.initial_reservoir_volume) 
	
	# Total power out must be less than or equal to 
	#@constraint(m,[ts in p.time_steps, t in p.techs.existing_hydropower],
		#m[:dvHydroPowerOut][ts] == m[:dvHydroToGrid][ts] + m[:dvHydroToStorage][ts] + m[:dvHydroToLoad][ts]
	#)

	# Limit power output from the hydropower turbines to the existing kW capacity:
	@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:dvRatedProduction][t,ts] <= m[:binTurbineActive][t,ts]*p.s.existing_hydropower.existing_kw_per_turbine)

end

