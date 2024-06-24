# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

function add_existing_hydropower_constraints(m,p)
	@info "Adding constraints for existing hydropower"
		
	if p.s.existing_hydropower.computation_type == "quadratic1" # This doesn't solve
			@info "Adding quadratic1 constraint for the hydropower power output"
			@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
			m[:dvRatedProduction][t,ts] == 9810*0.001 * m[:dvWaterOutFlow][t,ts] *
											 (p.s.existing_hydropower.coefficient_a_efficiency*((m[:dvWaterOutFlow][t,ts]*m[:dvWaterOutFlow][t,ts])) + (p.s.existing_hydropower.coefficient_b_efficiency* m[:dvWaterOutFlow][t,ts]) + p.s.existing_hydropower.coefficient_c_efficiency ) *
											 #((p.s.existing_hydropower.coefficient_a_efficiency* m[:dvWaterOutFlow][t,ts]) + p.s.existing_hydropower.coefficient_b_efficiency ) *
											 (p.s.existing_hydropower.coefficient_c_reservoir_head*((m[:dvWaterVolume][ts]*m[:dvWaterVolume][ts])) + (p.s.existing_hydropower.coefficient_d_reservoir_head* m[:dvWaterVolume][ts]) + p.s.existing_hydropower.coefficient_e_reservoir_head )
			)
	
	# Linearize the reservoir head equation
	elseif p.s.existing_hydropower.computation_type == "quadratic2" # This doesn't solve
		@info "Adding quadratic2 constraint for the hydropower power output, updated version"
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
		m[:dvRatedProduction][t,ts] == 9810*0.001 * m[:dvWaterOutFlow][t,ts] *
										 ((p.s.existing_hydropower.coefficient_a_efficiency* m[:dvWaterOutFlow][t,ts]) + p.s.existing_hydropower.coefficient_b_efficiency ) *
										 ((p.s.existing_hydropower.coefficient_d_reservoir_head* m[:dvWaterVolume][ts]) + p.s.existing_hydropower.coefficient_e_reservoir_head )
		)

	# Test a basic quadratic with a fixed reservoir head
	elseif p.s.existing_hydropower.computation_type == "quadratic3"
		@info "Adding quadratic3 constraint for the hydropower power output"
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
		m[:dvRatedProduction][t,ts] == 9810*0.001 * m[:dvWaterOutFlow][t,ts] *
										 ((p.s.existing_hydropower.coefficient_a_efficiency* m[:dvWaterOutFlow][t,ts]) + p.s.existing_hydropower.coefficient_b_efficiency ) * 5
			)		

	# Test with the efficiency defined as a separate variable:	
	elseif p.s.existing_hydropower.computation_type == "quadratic4"
		@info "Adding quadratic4 constraint for the hydropower power output"
		@variable(m, turbine_efficiency[t in p.techs.existing_hydropower, ts in p.time_steps] >= 0)

		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
						m[:dvRatedProduction][t,ts] == 9810*0.001 * m[:dvWaterOutFlow][t,ts] * m[:turbine_efficiency][t, ts] * 5 # reservoir head fixed at 5m
					)
		
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:turbine_efficiency][t, ts] == (p.s.existing_hydropower.coefficient_a_efficiency* m[:dvWaterOutFlow][t,ts]) + p.s.existing_hydropower.coefficient_b_efficiency )
	
	# Test with the efficiency and reservoir head defined as a separate variable:	
	elseif p.s.existing_hydropower.computation_type == "quadratic5"
		@info "Adding quadratic5 constraint for the hydropower power output"

		@variable(m, turbine_efficiency[t in p.techs.existing_hydropower, ts in p.time_steps] >= 0)
		@variable(m, reservoir_head[ts in p.time_steps] >= 0)
		@variable(m, efficiency_reservoir_head_product[t in p.techs.existing_hydropower, ts in p.time_steps] >= 0)

		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
						m[:dvRatedProduction][t,ts] == 9810*0.001 * m[:dvWaterOutFlow][t,ts] * m[:efficiency_reservoir_head_product][t,ts]
					)
		
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:turbine_efficiency][t, ts] <= 150) # TODO, switch this to 1
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:turbine_efficiency][t, ts] == (p.s.existing_hydropower.coefficient_a_efficiency* m[:dvWaterOutFlow][t,ts]) + p.s.existing_hydropower.coefficient_b_efficiency )
		
		@constraint(m, [ts in p.time_steps], m[:reservoir_head][ts] <= 50) # TODO: enter the maximum reservoir head as an input into the model
		@constraint(m, [ts in p.time_steps], m[:reservoir_head][ts] == (p.s.existing_hydropower.coefficient_d_reservoir_head* m[:dvWaterVolume][ts]) + p.s.existing_hydropower.coefficient_e_reservoir_head )
		
		# represent the product of the reservoir head and turbine efficiency as a separate variable (Gurobi can only multiply two variables together)
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:efficiency_reservoir_head_product][t, ts] <= 500) # TODO, switch this to a more intentional value
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:efficiency_reservoir_head_product][t, ts] ==  m[:reservoir_head][ts] * m[:turbine_efficiency][t, ts])

	# Test with a fixed hydropower efficiency at 85%
	elseif p.s.existing_hydropower.computation_type == "quadratic6"
		@info "Adding quadratic6 constraint for the hydropower power output: model with a fixed hydropower efficiency at 85%"

		@variable(m, reservoir_head[ts in p.time_steps] >= 0)

		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
			m[:dvRatedProduction][t,ts] == 9810*0.001 * m[:dvWaterOutFlow][t,ts] * m[:reservoir_head][ts] * 0.85
		)

		@constraint(m, [ts in p.time_steps], m[:reservoir_head][ts] >= 0)
		@constraint(m, [ts in p.time_steps], m[:reservoir_head][ts] <= 1000) # TODO: enter the maximum reservoir head as an input into the model
		@constraint(m, [ts in p.time_steps], m[:reservoir_head][ts] == (p.s.existing_hydropower.coefficient_d_reservoir_head* m[:dvWaterVolume][ts]) + p.s.existing_hydropower.coefficient_e_reservoir_head )
		
	# Test with a discretized hydropower efficiency
	elseif p.s.existing_hydropower.computation_type == "quadratic7"
		@info "Adding quadratic7 constraint for the hydropower power output: model with with a discretized hydropower efficiency"
		
		@variable(m, reservoir_head[ts in p.time_steps] >= 0)
		@variable(m, turbine_efficiency[t in p.techs.existing_hydropower, ts in p.time_steps] >= 0)
		@variable(m, efficiency_reservoir_head_product[t in p.techs.existing_hydropower, ts in p.time_steps] >= 0)
		
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
			m[:dvRatedProduction][t,ts] == 9810*0.001 * m[:dvWaterOutFlow][t,ts] * m[:efficiency_reservoir_head_product][t,ts]
		)
		@constraint(m, [ts in p.time_steps], m[:reservoir_head][ts] >= 0)
		@constraint(m, [ts in p.time_steps], m[:reservoir_head][ts] <= 1000) # TODO: enter the maximum reservoir head as an input into the model
		@constraint(m, [ts in p.time_steps], m[:reservoir_head][ts] == (p.s.existing_hydropower.coefficient_d_reservoir_head* m[:dvWaterVolume][ts]) + p.s.existing_hydropower.coefficient_e_reservoir_head )
		
		# represent the product of the reservoir head and turbine efficiency as a separate variable (Gurobi can only multiply two variables together)
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:efficiency_reservoir_head_product][t, ts] <= 500) # TODO, switch this to a more intentional value
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:efficiency_reservoir_head_product][t, ts] ==  m[:reservoir_head][ts] * m[:turbine_efficiency][t, ts])
		
		# Descritization of the efficiency, based on the water flow range
		# TODO: change these values to inputs into the model:
		efficiency_bins = [1,2,3]
		descritized_efficiency = [0.5, 0.75, 0.85]
		water_flow_bin_limits = [0, 15, 30, 75]
		
		# define a binary variable for the turbine efficiencies
		@variable(m, waterflow_range_binary[ts in p.time_steps, t in p.techs.existing_hydropower, i in efficiency_bins], Bin)
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:turbine_efficiency][t, ts] <= 150) # TODO, switch this to 1
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:turbine_efficiency][t, ts] == sum(m[:waterflow_range_binary][ts,t,i]*descritized_efficiency[i] for i in efficiency_bins))                  #(p.s.existing_hydropower.coefficient_a_efficiency* m[:dvWaterOutFlow][t,ts]) + p.s.existing_hydropower.coefficient_b_efficiency )
		
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:dvWaterOutFlow][t,ts] <= sum(m[:waterflow_range_binary][ts,t,i] * water_flow_bin_limits[i+1] for i in efficiency_bins) )
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:dvWaterOutFlow][t,ts] >= sum(m[:waterflow_range_binary][ts,t,i] * water_flow_bin_limits[i] for i in efficiency_bins) )

		# only have one binary active at a time
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], sum(m[:waterflow_range_binary][ts,t,i] for i in efficiency_bins) <= 1)

		#water_flow <= binary_1 * water_flow_upper_limit_1
		#water_flow >= binary_1 * water_flow_lower_limit_1
		#water_flow <= sum(binary_x[i] * water_flow_upper_limit_x[i], for i in number_of_bins)
		#water_flow >= sum(binary_x[i] * water_flow_lower_limit_x[i], for i in number_of_bins)
		

	elseif p.s.existing_hydropower.computation_type == "quadratic8"	
		@info "Adding quadratic8 constraint for the hydropower power output: model with with a discretized hydropower efficiency with user-defined increments"
		
		@variable(m, reservoir_head[ts in p.time_steps] >= 0)
		@variable(m, turbine_efficiency[t in p.techs.existing_hydropower, ts in p.time_steps] >= 0)
		@variable(m, efficiency_reservoir_head_product[t in p.techs.existing_hydropower, ts in p.time_steps] >= 0)

		
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
			m[:dvRatedProduction][t,ts] == 9810*0.001 * m[:dvWaterOutFlow][t,ts] * m[:efficiency_reservoir_head_product][t,ts]
		)
		
		@constraint(m, [ts in p.time_steps], m[:reservoir_head][ts] >= 0)
		@constraint(m, [ts in p.time_steps], m[:reservoir_head][ts] <= 1000) # TODO: enter the maximum reservoir head as an input into the model
		@constraint(m, [ts in p.time_steps], m[:reservoir_head][ts] == (p.s.existing_hydropower.coefficient_d_reservoir_head* m[:dvWaterVolume][ts]) + p.s.existing_hydropower.coefficient_e_reservoir_head )
		print("\n Debug 1 \n")
		# represent the product of the reservoir head and turbine efficiency as a separate variable (Gurobi can only multiply two variables together)
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:efficiency_reservoir_head_product][t, ts] <= 500) # TODO, switch this to a more intentional value
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:efficiency_reservoir_head_product][t, ts] ==  m[:reservoir_head][ts] * m[:turbine_efficiency][t, ts])
		print("\n Debug 2 \n")

		# Descritization of the efficiency, based on the water flow range
		# TODO: change these values to inputs into the model:
		efficiency_bins = collect(1:p.s.existing_hydropower.number_of_efficiency_bins) 
		print("\n Efficiency bins are: \n")
		print(efficiency_bins)

		waterflow_increments = (maximumwaterflow-minimumwaterflow)/efficiency_bins #[0, 15, 30, 75]
		print("\n Debug 3 \n")

		# Generate a vector of the water flow bin limits
		water_flow_bin_limits = zeros(1 + p.s.existing_hydropower.number_of_efficiency_bins)
		water_flow_bin_limits[1] = p.s.existing_hydropower.minimum_water_output_cubic_meter_per_second_per_turbine
		print("\n Debug 4 \n")
		for i in efficiency_bins
			water_flow_bin_limits[1+i] = round(p.s.existing_hydropower.minimum_water_output_cubic_meter_per_second_per_turbine + waterflow_increments, digits=3)
		end
		print("\n Debug 5 \n")
		#redefine the last bin limit as the max water flow through a turbine
		water_flow_bin_limits[1 + p.s.existing_hydropower.number_of_efficiency_bins] = p.s.existing_hydropower.maximum_water_output_cubic_meter_per_second_per_turbine
		print("\n Debug 6 \n")
		print("\n The waterflow bin limits are: \n")
		print(water_flow_bin_limits)
		# Compute the average turbine efficiency for each water flow bin:
		descritized_efficiency = zeros(p.s.existing_hydropower.number_of_efficiency_bins)
		print("\n Debug 7 \n")
		for i in efficiency_bins
			# compute the efficiency at the beginning and end of the bin 
			x1 = (p.s.existing_hydropower.coefficient_a_efficiency * water_flow_bin_limits[i] * water_flow_bin_limits[i]) + (p.s.existing_hydropower.coefficient_b_efficiency * water_flow_bin_limits[i]) + p.s.existing_hydropower.coefficient_c_efficiency
			x2 = (p.s.existing_hydropower.coefficient_a_efficiency * water_flow_bin_limits[i+1] * water_flow_bin_limits[i+1]) + (p.s.existing_hydropower.coefficient_b_efficiency * water_flow_bin_limits[i+1]) + p.s.existing_hydropower.coefficient_c_efficiency
			print("\n Debug 8 \n")
			# compute the average and store it in the discretized_efficiency vector
			descritized_efficiency[i] = (x1 + x2)/2

		end
		print("\n Debug 9 \n")
		# define a binary variable for the turbine efficiencies
		@variable(m, waterflow_range_binary[ts in p.time_steps, t in p.techs.existing_hydropower, i in efficiency_bins], Bin)
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:turbine_efficiency][t, ts] <= 1.0) # the maximum efficiency fraction is 100%
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:turbine_efficiency][t, ts] == sum(m[:waterflow_range_binary][ts,t,i]*descritized_efficiency[i] for i in efficiency_bins))                  #(p.s.existing_hydropower.coefficient_a_efficiency* m[:dvWaterOutFlow][t,ts]) + p.s.existing_hydropower.coefficient_b_efficiency )
		print("\n Debug 10 \n")
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:dvWaterOutFlow][t,ts] <= sum(m[:waterflow_range_binary][ts,t,i] * water_flow_bin_limits[i+1] for i in efficiency_bins) )
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:dvWaterOutFlow][t,ts] >= sum(m[:waterflow_range_binary][ts,t,i] * water_flow_bin_limits[i] for i in efficiency_bins) )
		print("\n Debug 11 \n")
		# only have one binary active at a time
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], sum(m[:waterflow_range_binary][ts,t,i] for i in efficiency_bins) <= 1)

		#water_flow <= binary_1 * water_flow_upper_limit_1
		#water_flow >= binary_1 * water_flow_lower_limit_1

		#water_flow <= sum(binary_x[i] * water_flow_upper_limit_x[i], for i in number_of_bins)
		#water_flow >= sum(binary_x[i] * water_flow_lower_limit_x[i], for i in number_of_bins)
		
	

		

	#elseif p.s.existing_hydropower.computation_type == "linearized_constraints"
		#TODO: add linearized constraints

	elseif p.s.existing_hydropower.computation_type == "average_power_conversion"
		# This is a simplified constraint that uses an average conversion for water flow and kW output
		@info "Adding hydropower power output constraint using the average power conversion"

		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
				m[:dvRatedProduction][t,ts] == m[:dvWaterOutFlow][t,ts] * (1/p.s.existing_hydropower.average_cubic_meters_per_second_per_kw) # convert to kW/time step, for instance: m3/15min  * kwh/m3 * (0.25 hrs/1hr)
			)
	else 
		throw(@error("Invalid input for the computation_type field"))
	end

	# Total water volume is between the max and min levels
	@constraint(m, [ts in p.time_steps],
		m[:dvWaterVolume][ts] <= p.s.existing_hydropower.cubic_meter_maximum
	)
	@constraint(m, [ts in p.time_steps],
		p.s.existing_hydropower.cubic_meter_minimum <= m[:dvWaterVolume][ts] 
	)

	# Water flow rate is between the maximum and minimum allowable levels
	@constraint(m, [ts in p.time_steps], # t in p.techs.existing_hydropower],
		 sum(m[:dvWaterOutFlow][t, ts] for t in p.techs.existing_hydropower) + m[:dvSpillwayWaterFlow][ts] >= p.s.existing_hydropower.minimum_water_output_cubic_meter_per_second_total_of_all_turbines   # m[:dvWaterOutFlow][t, ts]
	)
	 
	@constraint(m, [t in p.techs.existing_hydropower, ts in p.time_steps], 
			m[:dvWaterOutFlow][t, ts] >=  m[:binTurbineActive][t,ts]*p.s.existing_hydropower.minimum_water_output_cubic_meter_per_second_per_turbine    #p.s.existing_hydropower.existing_kw_per_turbine / (p.s.existing_hydropower.efficiency_kwh_per_cubicmeter * p.hours_per_time_step)
		)

	# The total water volume changes based on the water flow rates
	@constraint(m, [ts in p.time_steps[2:end]], m[:dvWaterVolume][ts] == m[:dvWaterVolume][ts-1] + ((3600/p.s.settings.time_steps_per_hour)* (p.s.existing_hydropower.water_inflow_cubic_meter_per_second[ts] - m[:dvSpillwayWaterFlow][ts] - sum(m[:dvWaterOutFlow][t,ts] for t in p.techs.existing_hydropower)))) # m[:dvWaterOutFlow][ts]) 
	@constraint(m, m[:dvWaterVolume][1] == p.s.existing_hydropower.initial_reservoir_volume) 
	
	# Total water volume must be the same in the beginning and the end
	@constraint(m, m[:dvWaterVolume][1] == m[:dvWaterVolume][maximum(p.time_steps)])

	# Total power out must be less than or equal to 
	#@constraint(m,[ts in p.time_steps, t in p.techs.existing_hydropower],
		#m[:dvHydroPowerOut][ts] == m[:dvHydroToGrid][ts] + m[:dvHydroToStorage][ts] + m[:dvHydroToLoad][ts]
	#)

	# Limit power output from the hydropower turbines to the existing kW capacity:
	@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:dvRatedProduction][t,ts] <= m[:binTurbineActive][t,ts]*p.s.existing_hydropower.existing_kw_per_turbine)

	# Limit the water flow through the spillway, if a value was input
	if !isnothing(p.s.existing_hydropower.spillway_maximum_cubic_meter_per_second)
		@constraint(m, [ts in p.time_steps], m[:dvSpillwayWaterFlow][ts] <= p.s.existing_hydropower.spillway_maximum_cubic_meter_per_second)
	end 

	# Define the minimum operating time (in time steps) for the hydropower turbine
	
	if p.s.existing_hydropower.minimum_operating_time_steps_individual_turbine > 1
		print("\n Adding minimum operating time constraint \n")
		@variable(m, indicator_min_operating_time[t in p.techs.existing_hydropower, ts in p.time_steps], Bin)
		@constraint(m, m[:indicator_min_operating_time]["ExistingHydropower_Turbine1", 2175] == 1)
		for t in p.techs.existing_hydropower, ts in 1:8750 #(length(p.time_steps)- p.s.existing_hydropower.minimum_operating_time_steps_individual_turbine - 1 )
			@constraint(m, m[:indicator_min_operating_time][t, ts] => { m[:binTurbineActive][t,ts+1] + m[:binTurbineActive][t,ts+2] + m[:binTurbineActive][t,ts+3] + m[:binTurbineActive][t,ts+4] + m[:binTurbineActive][t,ts+5] >= 5 })# { sum(m[:binTurbineActive][t,ts+i] for i in 1:p.s.existing_hydropower.minimum_operating_time_steps_individual_turbine) >= p.s.existing_hydropower.minimum_operating_time_steps_individual_turbine} )
			@constraint(m, !m[:indicator_min_operating_time][t, ts] => { m[:binTurbineActive][t,ts+1] - m[:binTurbineActive][t,ts] <= 0  } )
		end
	end
	

	# TODO: remove this constraint that prevents a spike in the spillway use during the first time step
	@constraint(m, [ts in p.time_steps], m[:dvSpillwayWaterFlow][1] == 1)

	@info "Completed adding constraints for existing hydropower"

end

