
using Revise
using REopt
using JSON
using DelimitedFiles
using PlotlyJS
using Dates
using Test
using JuMP
using HiGHS
using DotEnv
DotEnv.load!()

###############   CHP Binary Creation Tests    ###################
# Tests to verify that binCHPIsOnInTS is only created when needed

@testset "CHP Binary Creation Tests" begin
    
    @testset "CHP with min_turn_down_fraction > 0 (binary SHOULD be created)" begin
        # Test that binCHPIsOnInTS gets created when min_turn_down_fraction > 0
        data = JSON.parsefile("./scenarios/chp_unavailability_outage.json")
        
        # Set min_turn_down_fraction to a non-zero value
        data["CHP"]["min_turn_down_fraction"] = 0.5
        
        # Remove outage to simplify the test
        delete!(data, "ElectricUtility")
        data["ElectricUtility"] = Dict("net_metering_limit_kw" => 0.0, "co2_from_avert" => true)
        
        s = Scenario(data)
        inputs = REoptInputs(s)
        m = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, 
            "log_to_console" => false, 
            "mip_rel_gap" => 0.01))
        results = run_reopt(m, inputs)
        
        # Verify the binary variable was created
        @test haskey(m.obj_dict, :binCHPIsOnInTS)
        binary_var = m[:binCHPIsOnInTS]
        
        # Verify model solved successfully
        @test results["CHP"]["size_kw"] > 0.0
        
        println("✓ Test 1 passed: Binary created with min_turn_down_fraction = 0.5")
        finalize(backend(m))
        empty!(m)
    end
    
    @testset "CHP with min_turn_down_fraction = 0 (binary should NOT be created)" begin
        # Test that binCHPIsOnInTS is NOT created when all conditions are zero/equal
        data = JSON.parsefile("./scenarios/chp_unavailability_outage.json")
        
        # Set min_turn_down_fraction to zero
        data["CHP"]["min_turn_down_fraction"] = 0.0
        
        # Ensure no intercepts by making efficiencies equal (no part-load curve)
        # When electric_efficiency_full_load == electric_efficiency_half_load, intercept = 0
        data["CHP"]["electric_efficiency_full_load"] = 0.35
        data["CHP"]["electric_efficiency_half_load"] = 0.35
        data["CHP"]["thermal_efficiency_full_load"] = 0.45
        data["CHP"]["thermal_efficiency_half_load"] = 0.45
        
        # Ensure no hourly O&M cost
        data["CHP"]["om_cost_per_hr_per_kw_rated"] = 0.0
        
        # Remove outage to simplify
        delete!(data, "ElectricUtility")
        data["ElectricUtility"] = Dict("net_metering_limit_kw" => 0.0, "co2_from_avert" => true)
        
        s = Scenario(data)
        inputs = REoptInputs(s)
        m = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, 
            "log_to_console" => false, 
            "mip_rel_gap" => 0.01))
        results = run_reopt(m, inputs)
        
        # Verify the binary variable was NOT created
        @test !haskey(m.obj_dict, :binCHPIsOnInTS)
        
        # Verify model still solved successfully
        @test results["CHP"]["size_kw"] > 0.0
        
        println("✓ Test 2 passed: Binary NOT created with min_turn_down_fraction = 0 and no intercepts")
        finalize(backend(m))
        empty!(m)
    end
    
    @testset "CHP with fuel_burn_intercept > 0 (binary SHOULD be created)" begin
        # Test that binary is created when fuel burn has non-zero intercept
        data = JSON.parsefile("./scenarios/chp_unavailability_outage.json")
        
        # Set min_turn_down_fraction to zero
        data["CHP"]["min_turn_down_fraction"] = 0.0
        
        # Create non-zero fuel burn intercept by having different efficiencies
        data["CHP"]["electric_efficiency_full_load"] = 0.40
        data["CHP"]["electric_efficiency_half_load"] = 0.30  # Different from full load
        data["CHP"]["thermal_efficiency_full_load"] = 0.45
        data["CHP"]["thermal_efficiency_half_load"] = 0.45  # Keep thermal same to isolate fuel burn
        
        # Ensure no hourly O&M cost
        data["CHP"]["om_cost_per_hr_per_kw_rated"] = 0.0
        
        delete!(data, "ElectricUtility")
        data["ElectricUtility"] = Dict("net_metering_limit_kw" => 0.0, "co2_from_avert" => true)
        
        s = Scenario(data)
        inputs = REoptInputs(s)
        m = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, 
            "log_to_console" => false, 
            "mip_rel_gap" => 0.01))
        results = run_reopt(m, inputs)
        
        # Verify the binary variable was created
        @test haskey(m.obj_dict, :binCHPIsOnInTS)
        
        # verify model solved successfully
        @test results["Financial"]["lcc"] != 0.0
        
        println("✓ Test 3 passed: Binary created with non-zero fuel_burn_intercept")
        finalize(backend(m))
        empty!(m)
    end
    
    @testset "CHP with thermal_prod_intercept > 0 (binary SHOULD be created)" begin
        # Test that binary is created when thermal production has non-zero intercept
        data = JSON.parsefile("./scenarios/chp_unavailability_outage.json")
        
        # Set min_turn_down_fraction to zero
        data["CHP"]["min_turn_down_fraction"] = 0.0
        
        # Create non-zero thermal prod intercept by having different thermal efficiencies
        data["CHP"]["electric_efficiency_full_load"] = 0.35
        data["CHP"]["electric_efficiency_half_load"] = 0.35  # Keep electric same
        data["CHP"]["thermal_efficiency_full_load"] = 0.40
        data["CHP"]["thermal_efficiency_half_load"] = 0.50  # Different from full load
        
        # Ensure no hourly O&M cost
        data["CHP"]["om_cost_per_hr_per_kw_rated"] = 0.0
        
        delete!(data, "ElectricUtility")
        data["ElectricUtility"] = Dict("net_metering_limit_kw" => 0.0, "co2_from_avert" => true)
        
        s = Scenario(data)
        inputs = REoptInputs(s)
        m = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, 
            "log_to_console" => false, 
            "mip_rel_gap" => 0.01))
        results = run_reopt(m, inputs)
        
        # Verify the binary variable was created
        @test haskey(m.obj_dict, :binCHPIsOnInTS)
        
        # Verify model solved successfully
        @test results["Financial"]["lcc"] != 0.0
        
        println("✓ Test 4 passed: Binary created with non-zero thermal_prod_intercept")
        finalize(backend(m))
        empty!(m)
    end
    
    @testset "CHP with om_cost_per_hr_per_kw_rated > 0 (binary SHOULD be created)" begin
        # Test that binary is created when hourly O&M cost is non-zero
        data = JSON.parsefile("./scenarios/chp_unavailability_outage.json")
        
        # Set min_turn_down_fraction to zero
        data["CHP"]["min_turn_down_fraction"] = 0.0
        
        # Make efficiencies equal (no intercepts)
        data["CHP"]["electric_efficiency_full_load"] = 0.35
        data["CHP"]["electric_efficiency_half_load"] = 0.35
        data["CHP"]["thermal_efficiency_full_load"] = 0.45
        data["CHP"]["thermal_efficiency_half_load"] = 0.45
        
        # Set non-zero hourly O&M cost
        data["CHP"]["om_cost_per_hr_per_kw_rated"] = 0.01
        
        delete!(data, "ElectricUtility")
        data["ElectricUtility"] = Dict("net_metering_limit_kw" => 0.0, "co2_from_avert" => true)
        
        s = Scenario(data)
        inputs = REoptInputs(s)
        m = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, 
            "log_to_console" => false, 
            "mip_rel_gap" => 0.01))
        results = run_reopt(m, inputs)
        
        # Verify the binary variable was created
        @test haskey(m.obj_dict, :binCHPIsOnInTS)
        
        # Verify model solved successfully
        @test results["Financial"]["lcc"] != 0.0
        
        println("✓ Test 5 passed: Binary created with om_cost_per_hr_per_kw_rated = 0.01")
        finalize(backend(m))
        empty!(m)
    end
    
    println("\n===== All CHP Binary Creation Tests Passed! =====\n")
end