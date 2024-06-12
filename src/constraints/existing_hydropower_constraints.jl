# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

function add_existing_hydropower_constraints(m,p)
	print("\n Adding constraints for existing hydropower")
	# Power out is flow rate times the efficiency
	
	# define the efficiency based on the efficiency slope and y intercept
	if p.s.existing_hydropower.computation_type == "quadratic"
		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
			# the 0.001 below is for W to kW conversion
			
			# Test 1: linear test
			#m[:dvRatedProduction][t,ts] == 9810*0.95*0.001 * m[:dvWaterOutFlow][t,ts] * 5

			# Test 2: quadratic, with reservoir head calculation
			m[:dvRatedProduction][t,ts] == 9810*0.95*0.001 * m[:dvWaterOutFlow][t,ts] * ((m[:dvWaterVolume][t,ts] * p.s.existing_hydropower.linearized_stage_storage_slope_fraction) + p.s.existing_hydropower.linearized_stage_storage_y_intercept)
			
			#=
			# Test 3: quadratic, linear efficiency calculation
			m[:dvRatedProduction][t,ts] == 9810*0.001 * m[:dvWaterOutFlow][t,ts] *
											 ((0.00507* m[:dvWaterOutFlow][t,ts]) + 0.338 ) *
											((m[:dvWaterVolume][t,ts] * p.s.existing_hydropower.linearized_stage_storage_slope_fraction) + p.s.existing_hydropower.linearized_stage_storage_y_intercept)
			=#

			#=
			# Test 4: quadratic, polynomial efficiency calculation
			m[:dvRatedProduction][t,ts] == 9810*0.001 * m[:dvWaterOutFlow][t,ts] *
											 (-0.0000973*((m[:dvWaterOutFlow][t,ts])^2) + (0.0189* m[:dvWaterOutFlow][t,ts]) + 0.0358 ) *
											((m[:dvWaterVolume][t,ts] * p.s.existing_hydropower.linearized_stage_storage_slope_fraction) + p.s.existing_hydropower.linearized_stage_storage_y_intercept)
			=#
		)
	elseif p.s.existing_hydropower.computation_type == "linear_discretization" # not working currently, due to long solve time

		# Determine the discretized water levels
		DiscretizedStepSize = (p.s.existing_hydropower.cubic_meter_maximum - p.s.existing_hydropower.cubic_meter_minimum )/p.s.existing_hydropower.water_levels_discretization_number 
		DiscretizedReservoirHead = zeros(p.s.existing_hydropower.water_levels_discretization_number)
		WaterVolumes_Bin_Limits = zeros(1 + p.s.existing_hydropower.water_levels_discretization_number) # add 2 for the minimum and maximum water levels
		WaterVolumes_Bin_Limits[length(WaterVolumes_Bin_Limits)] = p.s.existing_hydropower.cubic_meter_maximum

		for i in 1:p.s.existing_hydropower.water_levels_discretization_number
			
			x1 =  (DiscretizedStepSize * (i-1)) #+ p.s.existing_hydropower.cubic_meter_minimum
			x2 =  (DiscretizedStepSize * i) #+ p.s.existing_hydropower.cubic_meter_minimum

			y1 = (x1 * p.s.existing_hydropower.linearized_stage_storage_slope_fraction) + p.s.existing_hydropower.linearized_stage_storage_y_intercept
			y2 = (x2 * p.s.existing_hydropower.linearized_stage_storage_slope_fraction) + p.s.existing_hydropower.linearized_stage_storage_y_intercept

			DiscretizedReservoirHead[i] = round(0.5*(y1 + y2), digits=2)
			
			WaterVolumes_Bin_Limits[i] = round((x1 + p.s.existing_hydropower.cubic_meter_minimum), digits = 1)

		end
		
		# Determine the discretized water flow rates
		DiscretizedStepSize_FlowRate = (p.s.existing_hydropower.maximum_water_output_cubic_meter_per_second_per_turbine - p.s.existing_hydropower.minimum_water_output_cubic_meter_per_second_per_turbine) / p.s.existing_hydropower.water_outflow_rate_discretization_number 
		DiscretizedFlowRates = zeros(Int(p.s.existing_hydropower.water_outflow_rate_discretization_number))
		FlowRates_Bin_Limits = zeros(1 + Int(p.s.existing_hydropower.water_outflow_rate_discretization_number)) # add 1 for the minimum and maximum water levels
		FlowRates_Bin_Limits[length(FlowRates_Bin_Limits)] = p.s.existing_hydropower.maximum_water_output_cubic_meter_per_second_per_turbine
		
		print(p.s.existing_hydropower.water_outflow_rate_discretization_number)
		for i in 1:p.s.existing_hydropower.water_outflow_rate_discretization_number
			
			x1 = (DiscretizedStepSize_FlowRate * (i-1)) + p.s.existing_hydropower.minimum_water_output_cubic_meter_per_second_per_turbine
			x2 = (DiscretizedStepSize_FlowRate * i) + p.s.existing_hydropower.minimum_water_output_cubic_meter_per_second_per_turbine
			
			DiscretizedFlowRates[i] = round(0.5*(x1+x2), digits = 2)

			FlowRates_Bin_Limits[i] = round(x1, digits = 1)

		end

		# Temporarily printing out data:
		#=
		print("\n The discretized reservoir heads are: \n")
		print(DiscretizedReservoirHead)
		print("\n")
		print("\n The discretized water volumes bin limits are are: \n")
		print(WaterVolumes_Bin_Limits)
		print("\n")
		print("The number of water level discretizations is: \n")
		print(p.s.existing_hydropower.water_levels_discretization_number)
		print("\n")

		print("\n The discretized water outflow rates are: \n")
		print(DiscretizedFlowRates)
		print("\n")
		print("\n The discretized water outflow rate bin limits are are: \n")
		print(FlowRates_Bin_Limits)
		print("\n")
		print("The number of water outflow rates discretizations is: \n")
		print(p.s.existing_hydropower.water_outflow_rate_discretization_number)
		print("\n")		
		=#

		WaterLevelsNumber = p.s.existing_hydropower.water_levels_discretization_number
		OutflowRatesNumber = p.s.existing_hydropower.water_outflow_rate_discretization_number

		m[Symbol("DiscretizedPowerOutput")] = @variable(m, [q in 1:OutflowRatesNumber, v in 1:WaterLevelsNumber, t in p.techs.existing_hydropower, ts in p.time_steps], Bin)		
			
		# Compute the actual values for the discretized power output, for each discretized combination of water flow rate and water level)
		DiscretizedPowerOutput_Value = zeros(OutflowRatesNumber, WaterLevelsNumber)
		for i in 1:OutflowRatesNumber
			for z in 1:WaterLevelsNumber
				DiscretizedPowerOutput_Value[i,z] = round(DiscretizedFlowRates[i] * DiscretizedReservoirHead[z], digits=3)
			end
		end

		print("\n The discretized power outpus are: \n")
		print(DiscretizedPowerOutput_Value)

		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
			# the 0.001 below is for W to kW conversion
			m[:dvRatedProduction][t,ts] == 9810*0.95*0.001*(sum((DiscretizedPowerOutput_Value[q,v] * m[Symbol("DiscretizedPowerOutput")][q,v,t,ts]) for q in 1:OutflowRatesNumber, v in 1:WaterLevelsNumber)) 
		)					  				

		# Sum of all reservoir head binary variables for a particular time step must be less than or equal to 1 
		@constraint(m, [t in p.techs.existing_hydropower, ts in p.time_steps], sum(sum(m[Symbol("DiscretizedPowerOutput")][q,v,t,ts] for q in 1:OutflowRatesNumber) for v in 1:WaterLevelsNumber) <= 1)
	
		# Discretized limits for the water volumes
		@constraint(m, [t in p.techs.existing_hydropower, ts in p.time_steps],
		m[:dvWaterVolume][ts] >= sum( sum( (WaterVolumes_Bin_Limits[i] * m[Symbol("DiscretizedPowerOutput")][y,i,t,ts]) for i in 1:WaterLevelsNumber)  for y in 1:OutflowRatesNumber)
		)

		@constraint(m, [t in p.techs.existing_hydropower, ts in p.time_steps],
		m[:dvWaterVolume][ts] >= sum( sum(WaterVolumes_Bin_Limits[i+1] * m[Symbol("DiscretizedPowerOutput")][y,i,t,ts] for i in 1:WaterLevelsNumber)  for y in 1:OutflowRatesNumber)
		) 

		# Discretized limits for the water outflow rates
		@constraint(m, [t in p.techs.existing_hydropower, ts in p.time_steps],
		m[:dvWaterOutFlow][t,ts] >= sum( sum( (FlowRates_Bin_Limits[y] * m[Symbol("DiscretizedPowerOutput")][y,i,t,ts]) for y in 1:OutflowRatesNumber) for i in 1:WaterLevelsNumber)  
		)

		@constraint(m, [t in p.techs.existing_hydropower, ts in p.time_steps],
		m[:dvWaterOutFlow][t,ts] >= sum( sum(FlowRates_Bin_Limits[y+1] * m[Symbol("DiscretizedPowerOutput")][y,i,t,ts] for y in 1:OutflowRatesNumber) for i in 1:WaterLevelsNumber)   
		) 

	elseif p.s.existing_hydropower.computation_type == "average_power_conversion"
		# This is a simplified constraint that uses an average conversion for water flow and kW output
		print("\n Using the average power conversion for hydropower")

		@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
				m[:dvRatedProduction][t,ts] == m[:dvWaterOutFlow][t,ts] * (1/p.s.existing_hydropower.average_cubic_meters_per_second_per_kw) # convert to kW/time step, for instance: m3/15min  * kwh/m3 * (0.25 hrs/1hr)
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

end


# Previous code

	# Temporary Constraint for preventing all production from hydropower's RatedProductionVariable
	#@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
	#	m[Symbol("dvRatedProduction")][t,ts] == 0 
	#	)


# Previous attempts for linearization:


		#=
		@constraint(m, [ts in p.time_steps],
		m[:dvWaterVolume][ts] >= sum( m[Symbol("PowerOut_ReservoirHead_Bin_"*string(i))][ts]*WaterVolumes_Bin_Limits[i] for i in 1:p.s.existing_hydropower.water_levels_discretization_number)
			)

		@constraint(m, [ts in p.time_steps],
			m[:dvWaterVolume][ts] <= sum( m[Symbol("PowerOut_ReservoirHead_Bin_"*string(i))][ts]*WaterVolumes_Bin_Limits[i+1] for i in 1:p.s.existing_hydropower.water_levels_discretization_number)
				)		
		
		# Sum of all reservoir head binary variables for a particular time step must be 1 (the reservoir head must always have a value in the power equation, but can only be one value)
		@constraint(m, [ts in p.time_steps], sum(m[Symbol("PowerOut_ReservoirHead_Bin_"*string(x))][ts] for x in 1:p.s.existing_hydropower.water_levels_discretization_number ) == 1)
		=#

		# Previous attempt
		#@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:dvRatedProduction][t,ts] <=  (sum((m[Symbol("PowerOut_ReservoirHead_Bin_"*string(i))][ts] * ReservoirHead[i] * 9810 *0.001 * 0.95 * 125) for i in 1:p.s.existing_hydropower.water_levels_discretization_number))) 
		#@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:dvRatedProduction][t,ts] <=  m[:dvWaterOutFlow][t,ts]*ReservoirHead[i] * 9810 *0.001 * 0.95) 

		#@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:dvRatedProduction][t,ts] <= m[:dvWaterOutFlow][t,ts] - (125*(1-m[Symbol("PowerOut_ReservoirHead_Bin_1")][ts])))
		#@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:dvRatedProduction][t,ts] >= 0)

		# Original
		#@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:dvRatedProduction][t,ts] <= 125 * m[Symbol("PowerOut_ReservoirHead_Bin_1")][ts])
		#@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:dvRatedProduction][t,ts] <= m[:dvWaterOutFlow][t,ts])

		#@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:dvRatedProduction][t,ts] <= m[:dvWaterOutFlow][t,ts] - (125*(1-m[Symbol("PowerOut_ReservoirHead_Bin_1")][ts])))
		#@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower], m[:dvRatedProduction][t,ts] >= 0)

		# change to indicator constraints
		#Temporarily commmented out:
		#@constraint(m, [ts in p.time_steps], m[Symbol("PowerOut_ReservoirHead_Bin_1")][ts] ==1)
		#=
		for t in p.time_steps
			for i in 1:p.s.existing_hydropower.water_levels_discretization_number
				@constraint(m, m[Symbol("PowerOut_ReservoirHead_Bin_1")][ts] => { m[:dvWaterVolume][ts] <= WaterVolumes_Limits } )
				@constraint(m, !m[Symbol("PowerOut_ReservoirHead_Bin_1")][ts] => { m[:dvWaterVolume][ts]  } )


				# Example from other project:
				@constraint(modelUC, u[i,t] => {g[1,t]+g[2,t] + solarD[t] <= Demand[t] })
			end 
		end 
		=#

		#if  WaterVolumes_Limits[1] < m[:dvWaterVolume][ts] < WaterVolumes_Limits[2]
		#	then m[Symbol("PowerOut_ReservoirHead_Bin_1") ==1

		# Old code:

		#@constraint(m, [t in p.techs.existing_hydropower, ts in p.time_steps], 
		#					m[:TurbineEfficiency][t,ts] == p.s.existing_hydropower.efficiency_fraction_y_intercept + (m[:dvWaterOutFlow][t,ts] * p.s.existing_hydropower.efficiency_slope_fraction_per_cubic_meter_per_second)
		#				) 
		
		#@constraint(m, [ts in p.time_steps], m[:ReservoirHead][ts] == m[:dvWaterVolume][ts] * p.s.existing_hydropower.linearized_stage_storage_slope) 

		#@constraint(m, [ts in p.time_steps, t in p.techs.existing_hydropower],
			#m[:dvHydroPowerOut][ts] == m[:dvWaterOutFlow][ts] * (p.s.existing_hydropower.efficiency_kwh_per_cubicmeter * p.hours_per_time_step) # convert to kW/time step, for instance: m3/15min  * kwh/m3 * (0.25 hrs/1hr)
		#	m[:dvRatedProduction][t,ts] == 5 #9810 * 0.001 * m[:dvWaterOutFlow]t,ts] * m[:TurbineEfficiency][t,ts] * m[:ReservoirHead][ts]  # p.hours_per_time_step) #(m[:TurbineEfficiency][t,ts]) convert to kW/time step, for instance: m3/15min  * kwh/m3 * (0.25 hrs/1hr)
		#)
