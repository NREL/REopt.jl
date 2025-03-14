# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
using HiGHS
using DelimitedFiles

@testset "OffGrid" begin
    ## Scenario 1: Solar, Storage, Fixed Generator
    post_name = "off_grid.json" 
    post = JSON.parsefile("./scenarios/$post_name")
    m = Model(optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false, "log_to_console" => false))
    scen = Scenario(post)
    r = run_reopt(m, scen)
    open("debug_results.json","w") do f
        JSON.print(f, r, 4)
    end
    
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

    m = Model(optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false, "log_to_console" => false))
    r = run_reopt(m, post)

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

    m = Model(optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false, "log_to_console" => false))
    r = run_reopt(m, post)

    # Test generator outputs
    @test typeof(r) == Model # this is true when the model is infeasible

    ### Scenario 3: Indonesia. Wind (custom prod) and Generator only
    m = Model(optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false, "log_to_console" => false, "mip_rel_gap" => 0.01, "presolve" => "on"))
    post_name = "wind_intl_offgrid.json" 
    post = JSON.parsefile("./scenarios/$post_name")
    post["ElectricLoad"]["loads_kw"] = [10.0 for i in range(1,8760)]
    post["ElectricLoad"]["year"] = 2022
    scen = Scenario(post)
    post["Wind"]["production_factor_series"] =  reduce(vcat, readdlm("./data/example_wind_prod_factor_kw.csv", '\n', header=true)[1])

    results = run_reopt(m, post)
    
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


# @testset "AC and DC PVs create baseline scenarios to test against" begin

#     inputs = JSON.parsefile("./scenarios/ac_dc_pvs_existing_baseline_loads_net.json")
#     inputs["ElectricLoad"]["loads_kw"] = 100 .* ones(8760)
#     inputs["ElectricTariff"]["tou_energy_rates_per_kwh"] = repeat(cat(0.2*ones(15), 0.4*ones(5), 0.2*ones(4), dims=1), outer=365)
#     m = Model(optimizer_with_attributes(HiGHS.Optimizer))
#     results = run_reopt(m, inputs)
#     open("ac_dc_pvs_results_baseline_existing_can_charge_loads_net.json","w") do f
#         JSON.print(f, results, 4)
#     end

#     inputs = JSON.parsefile("./scenarios/ac_dc_pvs_existing_baseline.json")
#     inputs["ElectricLoad"]["loads_kw"] = 100 .* ones(8760)
#     inputs["ElectricTariff"]["tou_energy_rates_per_kwh"] = repeat(cat(0.2*ones(15), 0.4*ones(5), 0.2*ones(4), dims=1), outer=365)
#     m = Model(optimizer_with_attributes(HiGHS.Optimizer))
#     results = run_reopt(m, inputs)
#     open("ac_dc_pvs_results_baseline_existing_can_charge.json","w") do f
#         JSON.print(f, results, 4)
#     end
#     pv_ac = results["PV"][findfirst(pv -> pv["name"] == "pv_ac", results["PV"])]
#     existing_prod_series = pv_ac["production_factor_series"] * 30
#     inputs["ElectricLoad"]["loads_kw"] = inputs["ElectricLoad"]["loads_kw"] .- existing_prod_series
#     inputs["PV"][findfirst(pv -> pv["name"] == "pv_ac", results["PV"])]["existing_kw"] = 0
#     open("scenarios/ac_dc_pvs_existing_subtracted_and_removed_baseline.json","w") do f
#         JSON.print(f, inputs, 4)
#     end
#     m = Model(optimizer_with_attributes(HiGHS.Optimizer))
#     results = run_reopt(m, inputs)
#     open("ac_dc_pvs_results_baseline_existing_cannot_charge.json","w") do f
#         JSON.print(f, results, 4)
#     end

#     inputs = JSON.parsefile("./scenarios/ac_dc_pvs_baseline.json")
#     inputs["ElectricLoad"]["loads_kw"] = 100 .* ones(8760)
#     inputs["ElectricTariff"]["tou_energy_rates_per_kwh"] = repeat(cat(0.2*ones(15), 0.4*ones(5), 0.2*ones(4), dims=1), outer=365)
#     m = Model(optimizer_with_attributes(HiGHS.Optimizer))
#     results = run_reopt(m, inputs)
#     open("ac_dc_pvs_results_baseline_single_pv.json","w") do f
#         JSON.print(f, results, 4)
#     end
# end

# @testset "AC and DC PVs compare to baseline" begin
#     # Intended to pass up to commit 9124b1d9b38d165b2eeef79bf9a14890a61460af, 
#     # after which application of different effic for ac and dc coupled techs makes scenarios no longer equivalent

#     ## With single PV
#     inputs = JSON.parsefile("./scenarios/ac_dc_pvs.json")
#     inputs["ElectricLoad"]["loads_kw"] = 100 .* ones(8760)
#     inputs["ElectricTariff"]["tou_energy_rates_per_kwh"] = repeat(cat(0.2*ones(15), 0.4*ones(5), 0.2*ones(4), dims=1), outer=365)

#     m = Model(optimizer_with_attributes(HiGHS.Optimizer))
#     results = run_reopt(m, inputs)
#     open("ac_dc_pvs_results_single_pv.json","w") do f
#         JSON.print(f, results, 4)
#     end
#     # results = JSON.parsefile("./ac_dc_pvs_results_single_pv.json")

#     results_baseline = JSON.parsefile("./ac_dc_pvs_results_baseline_single_pv.json")

#     @test results["ElectricStorage"]["size_kw"] ≈ results_baseline["ElectricStorage"]["size_kw"] rtol=.005
#     @test results["ElectricStorage"]["size_kwh"] ≈ results_baseline["ElectricStorage"]["size_kwh"] rtol=.005
#     # @test results["ElectricStorage"]["dc_coupled_inverter_size_kw"] ≈  atol=0.1

#     pv_dc = results["PV"][findfirst(pv -> pv["name"] == "pv_dc", results["PV"])]
#     pv_dc_baseline = results_baseline["PV"][findfirst(pv -> pv["name"] == "pv_dc", results_baseline["PV"])]

#     @test pv_dc["size_kw"] ≈ pv_dc_baseline["size_kw"] rtol=.005
#     @test pv_dc["annual_energy_produced_kwh"] ≈ pv_dc_baseline["annual_energy_produced_kwh"] rtol=.0001
#     @test sum(pv_dc["electric_to_storage_series_kw"]) ≈ sum(pv_dc_baseline["electric_to_storage_series_kw"]) rtol=.0001

#     @test results["Financial"]["lcc"] ≈ results_baseline["Financial"]["lcc"] rtol=.001


#     ## With existing ac-coupled PV
#     inputs = JSON.parsefile("./scenarios/ac_dc_pvs_existing.json")
#     inputs["ElectricLoad"]["loads_kw"] = 100 .* ones(8760)
#     inputs["ElectricTariff"]["tou_energy_rates_per_kwh"] = repeat(cat(0.2*ones(15), 0.4*ones(5), 0.2*ones(4), dims=1), outer=365)

#     m = Model(optimizer_with_attributes(HiGHS.Optimizer))
#     results = run_reopt(m, inputs)
#     open("ac_dc_pvs_results_existing.json","w") do f
#         JSON.print(f, results, 4)
#     end
#     # results = JSON.parsefile("./ac_dc_pvs_results_existing.json")

#     # switch comparison from can charge to cannot charge once ac coupled techs not allowed to chanrge dc coupled storage
#     results_baseline_ac_can_charge = JSON.parsefile("./ac_dc_pvs_results_baseline_existing_can_charge.json")
#     results_baseline_ac_cannot_charge = JSON.parsefile("./ac_dc_pvs_results_baseline_existing_cannot_charge.json") #existing is subtracted out of load and removed from PV inputs so sizes and o&m don't include it
#     results_baseline = results_baseline_ac_cannot_charge
    
#     @test results["ElectricStorage"]["size_kw"] ≈ results_baseline["ElectricStorage"]["size_kw"] rtol=.001
#     @test results["ElectricStorage"]["size_kwh"] ≈ results_baseline["ElectricStorage"]["size_kwh"] rtol=.001
#     # @test results["ElectricStorage"]["dc_coupled_inverter_size_kw"] ≈  atol=0.1

#     pv_ac = results["PV"][findfirst(pv -> pv["name"] == "pv_ac", results["PV"])]
#     pv_dc = results["PV"][findfirst(pv -> pv["name"] == "pv_dc", results["PV"])]
#     pv_ac_baseline = results_baseline["PV"][findfirst(pv -> pv["name"] == "pv_ac", results_baseline["PV"])]
#     pv_dc_baseline = results_baseline["PV"][findfirst(pv -> pv["name"] == "pv_dc", results_baseline["PV"])]

#     @test pv_ac["size_kw"] ≈ 30.0 rtol=.005
#     @test pv_dc["size_kw"] ≈ pv_dc_baseline["size_kw"] + pv_ac_baseline["size_kw"] rtol=.005
#     @test sum(pv_ac["electric_to_storage_series_kw"]) ≈ 0.0 rtol=.0001
#     @test sum(pv_dc["electric_to_storage_series_kw"]) ≈ sum(pv_ac_baseline["electric_to_storage_series_kw"]) + sum(pv_dc_baseline["electric_to_storage_series_kw"]) rtol=.0001
    
#     expected_om_diff = results["Financial"]["lifecycle_om_costs_after_tax"] - results_baseline["Financial"]["lifecycle_om_costs_after_tax"]
#     @test results["Financial"]["lcc"] ≈ results_baseline["Financial"]["lcc"] + expected_om_diff rtol=.001
# end

@testset "AC and DC PVs ensure with each step output changes make sense" begin
    ## With single PV
    inputs = JSON.parsefile("./scenarios/ac_dc_pvs.json")
    inputs["ElectricLoad"]["loads_kw"] = 100 .* ones(8760)
    inputs["ElectricTariff"]["tou_energy_rates_per_kwh"] = repeat(cat(0.2*ones(15), 0.4*ones(5), 0.2*ones(4), dims=1), outer=365)

    m = Model(optimizer_with_attributes(HiGHS.Optimizer))
    results = run_reopt(m, inputs)
    open("ac_dc_pvs_results_single_pv.json","w") do f
        JSON.print(f, results, 4)
    end
    # results = JSON.parsefile("./ac_dc_pvs_results_single_pv.json")

    results_baseline = JSON.parsefile("./ac_dc_pvs_results_single_pv_prev.json")

    @test results["ElectricStorage"]["size_kw"] ≈ results_baseline["ElectricStorage"]["size_kw"] rtol=.005 # 100
    @test results["ElectricStorage"]["size_kwh"] ≈ results_baseline["ElectricStorage"]["size_kwh"] rtol=.005 # 594.86
    # @test results["ElectricStorage"]["dc_coupled_inverter_size_kw"] ≈  atol=0.1

    pv_dc = results["PV"][findfirst(pv -> pv["name"] == "pv_dc", results["PV"])]
    pv_dc_baseline = results_baseline["PV"][findfirst(pv -> pv["name"] == "pv_dc", results_baseline["PV"])]

    @test pv_dc["size_kw"] ≈ pv_dc_baseline["size_kw"] rtol=.005 # 332.0863
    @test pv_dc["annual_energy_produced_kwh"] ≈ pv_dc_baseline["annual_energy_produced_kwh"] rtol=.0001 # 555058.5
    @test sum(pv_dc["electric_to_storage_series_kw"]) ≈ sum(pv_dc_baseline["electric_to_storage_series_kw"]) rtol=.0001 # 175575.27

    @test results["Financial"]["lcc"] ≈ results_baseline["Financial"]["lcc"] rtol=.001 # 1.3867364184e6


    ## With existing ac-coupled PV
    inputs = JSON.parsefile("./scenarios/ac_dc_pvs_existing.json")
    inputs["ElectricLoad"]["loads_kw"] = 100 .* ones(8760)
    inputs["ElectricTariff"]["tou_energy_rates_per_kwh"] = repeat(cat(0.2*ones(15), 0.4*ones(5), 0.2*ones(4), dims=1), outer=365)

    m = Model(optimizer_with_attributes(HiGHS.Optimizer))
    results = run_reopt(m, inputs)
    open("ac_dc_pvs_results_existing.json","w") do f
        JSON.print(f, results, 4)
    end
    # results = JSON.parsefile("./ac_dc_pvs_results_existing.json")

    results_baseline = JSON.parsefile("./ac_dc_pvs_results_existing_prev.json")
    
    @test results["ElectricStorage"]["size_kw"] ≈ results_baseline["ElectricStorage"]["size_kw"] rtol=.001 # 100.0
    @test results["ElectricStorage"]["size_kwh"] ≈ results_baseline["ElectricStorage"]["size_kwh"] rtol=.001 # 597.92
    # @test results["ElectricStorage"]["dc_coupled_inverter_size_kw"] ≈  atol=0.1

    pv_ac = results["PV"][findfirst(pv -> pv["name"] == "pv_ac", results["PV"])]
    pv_dc = results["PV"][findfirst(pv -> pv["name"] == "pv_dc", results["PV"])]
    pv_ac_baseline = results_baseline["PV"][findfirst(pv -> pv["name"] == "pv_ac", results_baseline["PV"])]
    pv_dc_baseline = results_baseline["PV"][findfirst(pv -> pv["name"] == "pv_dc", results_baseline["PV"])]

    @test pv_ac["size_kw"] ≈ pv_ac_baseline["size_kw"] rtol=.005 # 30.0
    @test pv_dc["size_kw"] ≈ pv_dc_baseline["size_kw"] rtol=.005 # 302.9552
    @test sum(pv_ac["electric_to_storage_series_kw"]) ≈ 0.0 rtol=.0001 # 0
    @test sum(pv_dc["electric_to_storage_series_kw"]) ≈ sum(pv_ac_baseline["electric_to_storage_series_kw"]) + sum(pv_dc_baseline["electric_to_storage_series_kw"]) rtol=.0001 # 176038.056
    
    @test results["Financial"]["lcc"] ≈ results_baseline["Financial"]["lcc"] rtol=.001 # 1.3605789661e6
end
