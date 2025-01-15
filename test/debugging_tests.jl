# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
using HiGHS
using DelimitedFiles

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
#     # @test results["ElectricStorage"]["dc_couple_inverter_size_kw"] ≈  atol=0.1

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
#     # @test results["ElectricStorage"]["dc_couple_inverter_size_kw"] ≈  atol=0.1

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

    results_baseline = JSON.parsefile("./ac_dc_pvs_results_prev.json")

    @test results["ElectricStorage"]["size_kw"] ≈ results_baseline["ElectricStorage"]["size_kw"] rtol=.005 # 100
    @test results["ElectricStorage"]["size_kwh"] ≈ results_baseline["ElectricStorage"]["size_kwh"] rtol=.005 # 594.86
    # @test results["ElectricStorage"]["dc_couple_inverter_size_kw"] ≈  atol=0.1

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
    # @test results["ElectricStorage"]["dc_couple_inverter_size_kw"] ≈  atol=0.1

    pv_ac = results["PV"][findfirst(pv -> pv["name"] == "pv_ac", results["PV"])]
    pv_dc = results["PV"][findfirst(pv -> pv["name"] == "pv_dc", results["PV"])]
    pv_ac_baseline = results_baseline["PV"][findfirst(pv -> pv["name"] == "pv_ac", results_baseline["PV"])]
    pv_dc_baseline = results_baseline["PV"][findfirst(pv -> pv["name"] == "pv_dc", results_baseline["PV"])]

    @test pv_ac["size_kw"] ≈ 30.0 rtol=.005 # 30.0
    @test pv_dc["size_kw"] ≈ pv_dc_baseline["size_kw"] + pv_ac_baseline["size_kw"] rtol=.005 # 302.9552
    @test sum(pv_ac["electric_to_storage_series_kw"]) ≈ 0.0 rtol=.0001 # 0
    @test sum(pv_dc["electric_to_storage_series_kw"]) ≈ sum(pv_ac_baseline["electric_to_storage_series_kw"]) + sum(pv_dc_baseline["electric_to_storage_series_kw"]) rtol=.0001 # 176038.056
    
    expected_om_diff = results["Financial"]["lifecycle_om_costs_after_tax"] - results_baseline["Financial"]["lifecycle_om_costs_after_tax"]
    @test results["Financial"]["lcc"] ≈ results_baseline["Financial"]["lcc"] + expected_om_diff rtol=.001 # 1.3605789661e6
end
