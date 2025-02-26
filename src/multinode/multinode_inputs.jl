# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.

"""
`multinode` is an optional input with the following keys and default values:
```julia
    folder_location::String="",
    bus_coordinates::String="",  # Location of the csv document with the bus coordinates
    PMD_network_input::Any,
    multinode_type::String="BehindTheMeter",  # Options: "BehindTheMeter", "CommunityDistrict", or "Offgrid"
    nonlinear_solver::Bool=false,
    model_type::String="BasicLinear",  #Options: "BasicLinear", "PowerModelsDistribution",
    run_BAU_case::Bool=true,
    optimizer::Any, # Such as HiGHS.Optimizer
    optimizer_tolerance::Float64=0.001, # Only works for Xpress, HiGHS, and Gurobi
    log_solver_output_to_console::Bool=true, # Log the output from the solver to the console
    PMD_time_steps::Any=[1:24], # By default, apply the PMD model to the first 24 timesteps of the model
    REopt_inputs_list::Array=[],
    bus_phase_voltage_lower_bound_per_unit::Float64=0.95,
    bus_phase_voltage_upper_bound_per_unit::Float64=1.05,
    bus_neutral_voltage_upper_bound_per_unit::Float64=0.1, 
    facility_meter_node::String="",
    substation_node::String="",
    substation_line::String="",
    allow_export_beyond_substation::Bool=false,
    substation_export_limit::Real=0,
    substation_import_limit::Real=0,
    model_switches::Bool=false,
    model_line_upgrades::Bool=false,
    line_upgrade_options::Dict=Dict(), 
    model_transformer_upgrades::Bool=false,
    transformer_upgrade_options::Dict=Dict(),
    switch_open_timesteps::Dict=Dict(),
    single_outage_start_time_step::Real=0,
    single_outage_end_time_step::Real=0,
    model_outages_with_outages_vector::Bool=false,
    outages_vector::Array=[],
    run_outage_simulator::Bool=false,
    length_of_simulated_outages_time_steps::Array=[],
    critical_load_method::String="Fraction",
    critical_load_fraction::Real=0.0,
    critical_load_timeseries::Array=[],
    number_of_outages_to_simulate::Real=0,
    run_numbers_for_plotting_outage_simulator_results::Array=[], 
    time_steps_per_hour::Real=0,
    generator_fuel_gallon_available::Dict=Dict(),
    generators_only_run_during_grid_outage::Bool=false,
    generate_CSV_of_outputs::Bool=false,
    generate_results_plots::Bool=false,
    time_steps_for_results_dashboard::Array=[],
    voltage_plot_time_step::Real=0,
    generate_same_pv_production_profile_for_each_node::Bool=false,
    pv_inputs_for_standardized_pv_production_profile::Dict=Dict(), 
    display_results::Bool=true
"""

mutable struct MultinodeInputs <: AbstractMultinode
    folder_location
    bus_coordinates
    PMD_network_input
    multinode_type
    model_type
    run_BAU_case
    optimizer
    optimizer_tolerance
    log_solver_output_to_console
    PMD_time_steps
    nonlinear_solver
    REopt_inputs_list
    bus_phase_voltage_lower_bound_per_unit
    bus_phase_voltage_upper_bound_per_unit
    bus_neutral_voltage_upper_bound_per_unit
    facility_meter_node
    substation_node
    substation_line
    allow_export_beyond_substation
    substation_export_limit
    substation_import_limit
    model_switches
    model_line_upgrades
    line_upgrade_options 
    model_transformer_upgrades
    transformer_upgrade_options
    switch_open_timesteps
    single_outage_start_time_step
    single_outage_end_time_step
    model_outages_with_outages_vector
    outages_vector
    run_outage_simulator
    length_of_simulated_outages_time_steps
    critical_load_method
    critical_load_fraction
    critical_load_timeseries
    number_of_outages_to_simulate
    run_numbers_for_plotting_outage_simulator_results
    time_steps_per_hour
    generator_fuel_gallon_available
    generators_only_run_during_grid_outage
    generate_CSV_of_outputs
    generate_results_plots
    time_steps_for_results_dashboard
    voltage_plot_time_step
    generate_same_pv_production_profile_for_each_node
    pv_inputs_for_standardized_pv_production_profile 
    display_results
    load_profiles_for_outage_sim_if_using_the_fraction_method

    function MultinodeInputs(;
        folder_location::String="",
        bus_coordinates::String="",  
        PMD_network_input::Any,
        multinode_type::String="BehindTheMeter", 
        model_type::String="PowerModelsDistribution",
        run_BAU_case::Bool=true, 
        optimizer::Any, 
        optimizer_tolerance::Float64=0.001,
        log_solver_output_to_console::Bool=true,
        PMD_time_steps::Any=[1:24],
        nonlinear_solver::Bool=false,
        REopt_inputs_list::Array=[],
        bus_phase_voltage_lower_bound_per_unit::Float64=0.95,
        bus_phase_voltage_upper_bound_per_unit::Float64=1.05,
        bus_neutral_voltage_upper_bound_per_unit::Float64=0.1,
        facility_meter_node::String="",
        substation_node::String="",
        substation_line::String="",
        allow_export_beyond_substation::Bool=false,
        substation_export_limit::Real=0,
        substation_import_limit::Real=0,
        model_switches::Bool=false,
        model_line_upgrades::Bool=false,
        line_upgrade_options::Dict=Dict(), 
        model_transformer_upgrades::Bool=false,
        transformer_upgrade_options::Dict=Dict(),
        switch_open_timesteps::Dict=Dict(),
        single_outage_start_time_step::Real=0,
        single_outage_end_time_step::Real=0,
        model_outages_with_outages_vector::Bool=false,
        outages_vector::Array=[],
        run_outage_simulator::Bool=false,
        length_of_simulated_outages_time_steps::Array=[],
        critical_load_method::String="Fraction",
        critical_load_fraction::Dict=Dict(),
        critical_load_timeseries::Dict=Dict(),
        number_of_outages_to_simulate::Real=0,
        run_numbers_for_plotting_outage_simulator_results::Array=[], 
        time_steps_per_hour::Real=0,
        generator_fuel_gallon_available::Dict=Dict(),
        generators_only_run_during_grid_outage::Bool=false,
        generate_CSV_of_outputs::Bool=false,
        generate_results_plots::Bool=false,
        time_steps_for_results_dashboard::Array=[],
        voltage_plot_time_step::Real=0,
        generate_same_pv_production_profile_for_each_node::Bool=false,
        pv_inputs_for_standardized_pv_production_profile::Dict=Dict(), 
        display_results::Bool=true,
        load_profiles_for_outage_sim_if_using_the_fraction_method::Array=[]
        )
    
    if generate_same_pv_production_profile_for_each_node == true

        pv_power_production_factor_series, ambient_temp_celcius = REopt.call_pvwatts_api(pv_inputs_for_standardized_pv_production_profile["latitude"], 
                                                                                        pv_inputs_for_standardized_pv_production_profile["longitude"]; 
                                                                                        tilt= pv_inputs_for_standardized_pv_production_profile["tilt"], 
                                                                                        azimuth= pv_inputs_for_standardized_pv_production_profile["azimuth"], 
                                                                                        module_type= pv_inputs_for_standardized_pv_production_profile["module_type"], 
                                                                                        array_type= pv_inputs_for_standardized_pv_production_profile["array_type"], 
                                                                                        losses= pv_inputs_for_standardized_pv_production_profile["losses"], 
                                                                                        dc_ac_ratio= pv_inputs_for_standardized_pv_production_profile["dc_ac_ratio"],
                                                                                        gcr= pv_inputs_for_standardized_pv_production_profile["gcr"], 
                                                                                        inv_eff= 100 * pv_inputs_for_standardized_pv_production_profile["inv_eff_fraction"], 
                                                                                        timeframe="hourly", 
                                                                                        radius=0, 
                                                                                        time_steps_per_hour=time_steps_per_hour)

        for node in collect(1:length(REopt_inputs_list))
            if "PV" in keys(REopt_inputs_list[node])
                if "production_factor_series" in keys(REopt_inputs_list[node]["PV"])
                    # do nothing because the power_factor_series is already defined
                else
                    REopt_inputs_list[node]["PV"]["production_factor_series"] = pv_power_production_factor_series
                end
            end
        end
    end

    new(
        folder_location,
        bus_coordinates,
        PMD_network_input,
        multinode_type,
        model_type,
        run_BAU_case,
        optimizer,
        optimizer_tolerance,
        log_solver_output_to_console,
        PMD_time_steps,
        nonlinear_solver,
        REopt_inputs_list,
        bus_phase_voltage_lower_bound_per_unit,
        bus_phase_voltage_upper_bound_per_unit,
        bus_neutral_voltage_upper_bound_per_unit,
        facility_meter_node,
        substation_node,
        substation_line,
        allow_export_beyond_substation,
        substation_export_limit,
        substation_import_limit,
        model_switches,
        model_line_upgrades,
        line_upgrade_options, 
        model_transformer_upgrades,
        transformer_upgrade_options,
        switch_open_timesteps,
        single_outage_start_time_step,
        single_outage_end_time_step,
        model_outages_with_outages_vector,
        outages_vector,
        run_outage_simulator,
        length_of_simulated_outages_time_steps,
        critical_load_method,
        critical_load_fraction,
        critical_load_timeseries,
        number_of_outages_to_simulate,
        run_numbers_for_plotting_outage_simulator_results,
        time_steps_per_hour,
        generator_fuel_gallon_available,
        generators_only_run_during_grid_outage,
        generate_CSV_of_outputs,
        generate_results_plots,
        time_steps_for_results_dashboard,
        voltage_plot_time_step,
        generate_same_pv_production_profile_for_each_node,
        pv_inputs_for_standardized_pv_production_profile, 
        display_results,
        load_profiles_for_outage_sim_if_using_the_fraction_method
    )
   
    end
end


