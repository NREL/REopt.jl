# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

function add_existing_hydropower_constraints(m,p)
	@info "Adding constraints for existing hydropower"
		
	if p.s.existing_hydropower.computation_type == "quadratic_partially_discretized"	
		@info "Adding quadratic_partially_discretized constraint type for the hydropower power output: model with with a discretized hydropower efficiency"
		
		@variable(m, reservoir_head[ts in p.time_steps] >= 0)
		@variable(m, turbine_efficiency[t in p.techs.existing_hydropower, ts in p.time_steps] >= 0)
		@variable(m, efficiency_reservoir_head_product[t in p.techs.existing_hydropower, ts in p.time_steps] >= 0)

		Hydro_techs = p.techs.existing_hydropower
		
		for t in 1:Int(length(Hydro_techs))
			@constraint(m, [ts in p.time_steps],
				m[:dvRatedProduction][Hydro_techs[t],ts] == 9810*0.001 * m[:dvWaterOutFlow][Hydro_techs[t],ts] * (m[:efficiency_reservoir_head_product][Hydro_techs[t],ts] - (t/1000) ) # the (t/1000) term establishes priority of turbine usage by having a slight efficiency difference for each turbine
						)
		end

		@constraint(m, [ts in p.time_steps], m[:reservoir_head][ts] >= 0)
		@constraint(m, [ts in p.time_steps], m[:reservoir_head][ts] <= 1000) # TODO: enter the maximum reservoir head as an input into the model
		@constraint(m, [ts in p.time_steps], m[:reservoir_head][ts] == (p.s.existing_hydropower.coefficient_e_reservoir_head* m[:dvWaterVolume][ts]) + p.s.existing_hydropower.coefficient_f_reservoir_head )
		
		# represent the product of the reservoir head and turbine efficiency as a separate variable (Gurobi can only multiply two variables together)
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:efficiency_reservoir_head_product][t, ts] <= 500) # TODO, switch this to a more intentional value
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:efficiency_reservoir_head_product][t, ts] ==  m[:reservoir_head][ts] * m[:turbine_efficiency][t, ts])
		
		# Descritization of the efficiency, based on the water flow range
		efficiency_bins = collect(1:p.s.existing_hydropower.number_of_efficiency_bins) 
		waterflow_increments = (p.s.existing_hydropower.maximum_water_output_cubic_meter_per_second_per_turbine - p.s.existing_hydropower.minimum_water_output_cubic_meter_per_second_per_turbine) / p.s.existing_hydropower.number_of_efficiency_bins #[0, 15, 30, 75]
		
		# Generate a vector of the water flow bin limits
		water_flow_bin_limits = zeros(1 + p.s.existing_hydropower.number_of_efficiency_bins)
		water_flow_bin_limits[1] = p.s.existing_hydropower.minimum_water_output_cubic_meter_per_second_per_turbine
		for i in efficiency_bins
			water_flow_bin_limits[1+i] = round(p.s.existing_hydropower.minimum_water_output_cubic_meter_per_second_per_turbine + (i * waterflow_increments), digits=3)
		end
		
		#redefine the last bin limit as the max water flow through a turbine
		water_flow_bin_limits[1 + p.s.existing_hydropower.number_of_efficiency_bins] = p.s.existing_hydropower.maximum_water_output_cubic_meter_per_second_per_turbine
		
		# Print some data to double check the computations:
		print("\n Efficiency bins are:")
		print(efficiency_bins)
		print("\n The waterflow bin limits are:")
		print(water_flow_bin_limits)
		print("\n The hydro techs are: ")
		print(Hydro_techs)

		# Compute the average turbine efficiency for each water flow bin:
		descritized_efficiency = zeros(p.s.existing_hydropower.number_of_efficiency_bins)
		for i in efficiency_bins
			# compute the efficiency at the beginning and end of the bin 
			x1 = (p.s.existing_hydropower.coefficient_a_efficiency * water_flow_bin_limits[i] * water_flow_bin_limits[i]) + (p.s.existing_hydropower.coefficient_b_efficiency * water_flow_bin_limits[i]) + p.s.existing_hydropower.coefficient_c_efficiency
			x2 = (p.s.existing_hydropower.coefficient_a_efficiency * water_flow_bin_limits[i+1] * water_flow_bin_limits[i+1]) + (p.s.existing_hydropower.coefficient_b_efficiency * water_flow_bin_limits[i+1]) + p.s.existing_hydropower.coefficient_c_efficiency
			# compute the average and store it in the discretized_efficiency vector
			descritized_efficiency[i] = (x1 + x2)/2
		end
		
		# define a binary variable for the turbine efficiencies
		@variable(m, waterflow_range_binary[ts in p.time_steps, t in p.techs.existing_hydropower, i in efficiency_bins], Bin)
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:turbine_efficiency][t, ts] <= 1.0) # the maximum efficiency fraction is 100%
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:turbine_efficiency][t, ts] == sum(m[:waterflow_range_binary][ts,t,i]*descritized_efficiency[i] for i in efficiency_bins))                  #(p.s.existing_hydropower.coefficient_a_efficiency* m[:dvWaterOutFlow][t,ts]) + p.s.existing_hydropower.coefficient_b_efficiency )
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:dvWaterOutFlow][t,ts] <= sum(m[:waterflow_range_binary][ts,t,i] * water_flow_bin_limits[i+1] for i in efficiency_bins) )
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:dvWaterOutFlow][t,ts] >= sum(m[:waterflow_range_binary][ts,t,i] * water_flow_bin_limits[i] for i in efficiency_bins) )
		
		# only have one binary active at a time
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], sum(m[:waterflow_range_binary][ts,t,i] for i in efficiency_bins) <= 1)

	elseif p.s.existing_hydropower.computation_type == "fixed_efficiency_linearized_reservoir_head"
		@info "Adding hydropower power output constraint using a fixed efficiency and linearized reservoir head"

        @variable(m, reservoir_head[ts in p.time_steps] >= 0)

		Hydro_techs = p.techs.existing_hydropower
		for t in 1:Int(length(Hydro_techs))
        @constraint(m, [ts in p.time_steps],
            m[:dvRatedProduction][Hydro_techs[t],ts] == 9810*0.001 * m[:dvWaterOutFlow][Hydro_techs[t],ts] * m[:reservoir_head][ts] * (p.s.existing_hydropower.fixed_turbine_efficiency- (t/1000) )
        )
		end

        @constraint(m, [ts in p.time_steps], m[:reservoir_head][ts] >= 0)
        @constraint(m, [ts in p.time_steps], m[:reservoir_head][ts] <= 1000) # TODO: enter the maximum reservoir head as an input into the model
        @constraint(m, [ts in p.time_steps], m[:reservoir_head][ts] == (p.s.existing_hydropower.coefficient_e_reservoir_head* m[:dvWaterVolume][ts]) + p.s.existing_hydropower.coefficient_f_reservoir_head )


	elseif p.s.existing_hydropower.computation_type == "average_power_conversion"
		# This is a simplified constraint that uses an average conversion for water flow and kW output
		@info "Adding hydropower power output constraint using the average power conversion"

		Hydro_techs = p.techs.existing_hydropower
		for t in 1:Int(length(Hydro_techs))
			@constraint(m, [ts in p.time_steps],
					m[:dvRatedProduction][Hydro_techs[t],ts] == m[:dvWaterOutFlow][Hydro_techs[t],ts] * (1/p.s.existing_hydropower.average_cubic_meters_per_second_per_kw)* (1- (t/1000))  # convert to kW/time step, for instance: m3/15min  * kwh/m3 * (0.25 hrs/1hr)
						)
		end

	elseif p.s.existing_hydropower.computation_type == "quadratic_unsimplified" # This equation has not been tested directly
		@info "Adding quadratic1 constraint for the hydropower power output"
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
		m[:dvRatedProduction][t,ts] == 9810*0.001 * m[:dvWaterOutFlow][t,ts] *
											(p.s.existing_hydropower.coefficient_a_efficiency*((m[:dvWaterOutFlow][t,ts]*m[:dvWaterOutFlow][t,ts])) + (p.s.existing_hydropower.coefficient_b_efficiency* m[:dvWaterOutFlow][t,ts]) + p.s.existing_hydropower.coefficient_c_efficiency ) *
											(p.s.existing_hydropower.coefficient_d_reservoir_head*((m[:dvWaterVolume][ts]*m[:dvWaterVolume][ts])) + (p.s.existing_hydropower.coefficient_e_reservoir_head* m[:dvWaterVolume][ts]) + p.s.existing_hydropower.coefficient_f_reservoir_head )
					)
	
	#elseif p.s.existing_hydropower.computation_type == "linearized_constraints"
		#TODO: add version with completely linearized constraints

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

	# Limit power output from the hydropower turbines to the existing kW capacity:
	@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:dvRatedProduction][t,ts] <= m[:binTurbineActive][t,ts]*p.s.existing_hydropower.existing_kw_per_turbine)

	# Limit the water flow through the spillway, if a value was input
	if !isnothing(p.s.existing_hydropower.spillway_maximum_cubic_meter_per_second)
		@constraint(m, [ts in p.time_steps], m[:dvSpillwayWaterFlow][ts] <= p.s.existing_hydropower.spillway_maximum_cubic_meter_per_second)
	end 

	# Define the minimum operating time (in time steps) for the hydropower turbine
		# TODO: debug and confirm that this code works	
	if p.s.existing_hydropower.minimum_operating_time_steps_individual_turbine > 1
		print("\n Adding minimum operating time constraint \n")
		@variable(m, indicator_min_operating_time[t in p.techs.existing_hydropower, ts in p.time_steps], Bin)
		#@constraint(m, m[:indicator_min_operating_time]["ExistingHydropower_Turbine1", 2175] == 1) # temporary line for debugging
		for t in p.techs.existing_hydropower, ts in 1:8750 #(length(p.time_steps)- p.s.existing_hydropower.minimum_operating_time_steps_individual_turbine - 1 )
			@constraint(m, m[:indicator_min_operating_time][t, ts] => { m[:binTurbineActive][t,ts+1] + m[:binTurbineActive][t,ts+2] + m[:binTurbineActive][t,ts+3] + m[:binTurbineActive][t,ts+4] + m[:binTurbineActive][t,ts+5] >= 5 })# { sum(m[:binTurbineActive][t,ts+i] for i in 1:p.s.existing_hydropower.minimum_operating_time_steps_individual_turbine) >= p.s.existing_hydropower.minimum_operating_time_steps_individual_turbine} )
			@constraint(m, !m[:indicator_min_operating_time][t, ts] => { m[:binTurbineActive][t,ts+1] - m[:binTurbineActive][t,ts] <= 0  } )
		end
	end
	
	# TODO: remove this constraint that prevents a spike in the spillway use during the first time step
	@constraint(m, [ts in p.time_steps], m[:dvSpillwayWaterFlow][1] == 0)

	@info "Completed adding constraints for existing hydropower"

end

