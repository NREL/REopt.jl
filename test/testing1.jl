using REopt
using JuMP
# using Cbc
# using HiGHS
using Xpress
using JSON
# using Plots
using Test

ENV["NREL_DEVELOPER_API_KEY"]="ogQAO0gClijQdYn7WOKeIS02zTUYLbwYJJczH9St"

@testset "OffGrid" begin
    ## Scenario 1: Solar, Storage, Fixed Generator
    post_name = "off_grid.json" 
    post = JSON.parsefile("./scenarios/$post_name")
    m = Model(optimizer_with_attributes(Xpress.Optimizer))
    scen = Scenario(post)
    r = run_reopt(m, scen)
    println(r["Messages"])
    
    # Test default values 
    @test scen.electric_utility.outage_start_time_step ≈ 1
    @test scen.electric_utility.outage_end_time_step ≈ 8760 * scen.settings.time_steps_per_hour
    @test scen.storage.attr["ElectricStorage"].soc_init_fraction ≈ 1
    @test scen.storage.attr["ElectricStorage"].can_grid_charge ≈ false
    @test scen.generator.fuel_avail_gal ≈ 1.0e9
    @test scen.generator.min_turn_down_fraction ≈ 0.15
    @test sum(scen.electric_load.loads_kw) - sum(scen.electric_load.critical_loads_kw) ≈ 0 # critical loads should equal loads_kw
    @test scen.financial.microgrid_upgrade_cost_fraction ≈ 0

    # Test outputs
    @test r["ElectricUtility"]["annual_energy_supplied_kwh"] ≈ 0 # no interaction with grid
    @test r["Financial"]["lifecycle_offgrid_other_capital_costs"] ≈ 2617.092 atol=0.01 # Check straight line depreciation calc
    @test sum(r["ElectricLoad"]["offgrid_annual_oper_res_provided_series_kwh"]) >= sum(r["ElectricLoad"]["offgrid_annual_oper_res_required_series_kwh"]) # OR provided >= required
    @test r["ElectricLoad"]["offgrid_load_met_fraction"] >= scen.electric_load.min_load_met_annual_fraction
    @test r["PV"]["size_kw"] ≈ 5050.0
    f = r["Financial"]
    @test f["lifecycle_generation_tech_capital_costs"] + f["lifecycle_storage_capital_costs"] + f["lifecycle_om_costs_after_tax"] +
            f["lifecycle_fuel_costs_after_tax"] + f["lifecycle_chp_standby_cost_after_tax"] + f["lifecycle_elecbill_after_tax"] + 
            f["lifecycle_offgrid_other_annual_costs_after_tax"] + f["lifecycle_offgrid_other_capital_costs"] + 
            f["lifecycle_outage_cost"] + f["lifecycle_MG_upgrade_and_fuel_cost"] - 
            f["lifecycle_production_incentive_after_tax"] ≈ f["lcc"] atol=1.0
    
    ## Scenario 2: Fixed Generator only
    post["ElectricLoad"]["annual_kwh"] = 100.0
    post["PV"]["max_kw"] = 0.0
    post["ElectricStorage"]["max_kw"] = 0.0
    post["Generator"]["min_turn_down_fraction"] = 0.0

    m = Model(optimizer_with_attributes(Xpress.Optimizer))
    r = run_reopt(m, post)
    println(r["Messages"])

    # Test generator outputs
    @test r["Generator"]["annual_fuel_consumption_gal"] ≈ 7.52 # 99 kWh * 0.076 gal/kWh
    @test r["Generator"]["annual_energy_produced_kwh"] ≈ 99.0
    @test r["Generator"]["year_one_fuel_cost_before_tax"] ≈ 22.57
    @test r["Generator"]["lifecycle_fuel_cost_after_tax"] ≈ 205.35 
    @test r["Financial"]["initial_capital_costs"] ≈ 100*(700) 
    @test r["Financial"]["lifecycle_capital_costs"] ≈ 100*(700+324.235442*(1-0.26)) atol=0.1 # replacement in yr 10 is considered tax deductible
    @test r["Financial"]["initial_capital_costs_after_incentives"] ≈ 700*100 atol=0.1
    @test r["Financial"]["replacements_future_cost_after_tax"] ≈ 700*100
    @test r["Financial"]["replacements_present_cost_after_tax"] ≈ 100*(324.235442*(1-0.26)) atol=0.1 

    ## Scenario 3: Fixed Generator that can meet load, but cannot meet load operating reserve requirement
    ## This test ensures the load operating reserve requirement is being enforced
    post["ElectricLoad"]["doe_reference_name"] = "FlatLoad"
    post["ElectricLoad"]["annual_kwh"] = 876000.0 # requires 100 kW gen
    post["ElectricLoad"]["min_load_met_annual_fraction"] = 1.0 # requires additional generator capacity
    post["PV"]["max_kw"] = 0.0
    post["ElectricStorage"]["max_kw"] = 0.0
    post["Generator"]["min_turn_down_fraction"] = 0.0

    m = Model(optimizer_with_attributes(Xpress.Optimizer))
    r = run_reopt(m, post)
    println(r["Messages"])

    # Test generator outputs
    @test typeof(r) == Model # this is true when the model is infeasible

    ### Scenario 3: Indonesia. Wind (custom prod) and Generator only
    m = Model(optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 0.01))
    post_name = "wind_intl_offgrid.json" 
    post = JSON.parsefile("./scenarios/$post_name")
    post["ElectricLoad"]["loads_kw"] = [10.0 for i in range(1,8760)]
    post["ElectricLoad"]["year"] = 2022
    scen = Scenario(post)
    post["Wind"]["production_factor_series"] =  reduce(vcat, readdlm("./data/example_wind_prod_factor_kw.csv", '\n', header=true)[1])

    results = run_reopt(m, post)
    println(results["Messages"])
    
    @test results["ElectricLoad"]["offgrid_load_met_fraction"] >= scen.electric_load.min_load_met_annual_fraction
    f = results["Financial"]
    @test f["lifecycle_generation_tech_capital_costs"] + f["lifecycle_storage_capital_costs"] + f["lifecycle_om_costs_after_tax"] +
            f["lifecycle_fuel_costs_after_tax"] + f["lifecycle_chp_standby_cost_after_tax"] + f["lifecycle_elecbill_after_tax"] + 
            f["lifecycle_offgrid_other_annual_costs_after_tax"] + f["lifecycle_offgrid_other_capital_costs"] + 
            f["lifecycle_outage_cost"] + f["lifecycle_MG_upgrade_and_fuel_cost"] - 
            f["lifecycle_production_incentive_after_tax"] ≈ f["lcc"] atol=1.0

    windOR = sum(results["Wind"]["electric_to_load_series_kw"]  * post["Wind"]["operating_reserve_required_fraction"])
    loadOR = sum(post["ElectricLoad"]["loads_kw"] * scen.electric_load.operating_reserve_required_fraction)
    @test sum(results["ElectricLoad"]["offgrid_annual_oper_res_required_series_kwh"]) ≈ loadOR  + windOR atol=1.0

end