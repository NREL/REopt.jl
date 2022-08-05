using Test
using Xpress
using JSON
using REopt
using DelimitedFiles
using GhpGhx

@testset "GHP" begin
    """

    This tests multiple unique aspects of GHP:
    1. REopt.jl calls GhpGhx.jl n times from within scenario.jl and creates a list of n GHP structs
    2. GHP with heating and cooling "..efficiency_thermal_factors" reduces the net thermal load
    3. GHP serves only the SpaceHeatingLoad by default unless it is allowed to serve DHW
    4. GHP serves all the Cooling load
    5. Input of a custom COP map for GHP and check the GHP performance to make sure it's using it correctly
    
    """
    # Load base inputs
    input_data = JSON.parsefile("scenarios/ghp_inputs.json")
    
    # Modify ["GHP"]["ghpghx_inputs"] for running GhpGhx.jl
    # Heat pump performance maps
    cop_map_mat_header = readdlm("scenarios/ghp_cop_map_custom.csv", ',', header=true)
    data = cop_map_mat_header[1]
    headers = cop_map_mat_header[2]
    # Generate a "records" style dictionary from the 
    cop_map_list = []
    for i in 1:length(data[:,1])
        dict_record = Dict(name=>data[i, col] for (col, name) in enumerate(headers))
        push!(cop_map_list, dict_record)
    end
    input_data["GHP"]["ghpghx_inputs"][1]["cop_map_eft_heating_cooling"] = cop_map_list
    
    # Could also load in a "ghpghx_responses" which is combined ghpghx_inputs (but processed to populate all), and ghpghx_results
    #input_data["GHP"]["ghpghx_responses"] = [JSON.parsefile("scenarios/ghpghx_response.json")]
    
    # Heating load
    input_data["SpaceHeatingLoad"]["doe_reference_name"] = "Hospital"
    input_data["SpaceHeatingLoad"]["monthly_mmbtu"] = fill(1000.0, 12)
    input_data["SpaceHeatingLoad"]["monthly_mmbtu"][1] = 500.0
    input_data["SpaceHeatingLoad"]["monthly_mmbtu"][end] = 1500.0
    
    # Call REopt
    s = Scenario(input_data)
    inputs = REoptInputs(s)
    m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 0.001, "OUTPUTLOG" => 0))
    m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 0.001, "OUTPUTLOG" => 0))
    results = run_reopt([m1,m2], inputs)
    
    ghp_option_chosen = results["GHP"]["ghp_option_chosen"]
    
    # Test GHP serving space heating with VAV thermal efficiency improvements
    heating_served_mmbtu = sum(s.ghp_option_list[ghp_option_chosen].heating_thermal_kw / REopt.KWH_PER_MMBTU)
    expected_heating_served_mmbtu = 12000 * 0.8 * 0.85  # (fuel_mmbtu * boiler_effic * space_heating_efficiency_thermal_factor)
    @test round(heating_served_mmbtu, digits=1) ≈ expected_heating_served_mmbtu atol=1.0
    
    # Boiler serves all of the DHW load, no DHW thermal reduction due to GHP retrofit
    boiler_served_mmbtu = sum(results["ExistingBoiler"]["year_one_thermal_production_mmbtu_per_hour"])
    expected_boiler_served_mmbtu = 3000 * 0.8 # (fuel_mmbtu * boiler_effic)
    @test round(boiler_served_mmbtu, digits=1) ≈ expected_boiler_served_mmbtu atol=1.0
    
    # LoadProfileChillerThermal cooling thermal is 1/cooling_efficiency_thermal_factor of GHP cooling thermal production
    bau_chiller_thermal_tonhour = sum(s.cooling_load.loads_kw_thermal / REopt.KWH_THERMAL_PER_TONHOUR)
    ghp_cooling_thermal_tonhour = sum(inputs.ghp_cooling_thermal_load_served_kw[1,:] / REopt.KWH_THERMAL_PER_TONHOUR)
    @test round(bau_chiller_thermal_tonhour) ≈ ghp_cooling_thermal_tonhour/0.6 atol=1.0
    
    # Custom heat pump COP map is used properly
    ghp_option_chosen = results["GHP"]["ghp_option_chosen"]
    heating_cop_avg = s.ghp_option_list[ghp_option_chosen].ghpghx_response["outputs"]["heating_cop_avg"]
    cooling_cop_avg = s.ghp_option_list[ghp_option_chosen].ghpghx_response["outputs"]["cooling_cop_avg"]
    # Average COP which includes pump power should be lower than Heat Pump only COP specified by the map
    @test heating_cop_avg <= 4.0
    @test cooling_cop_avg <= 8.0
end