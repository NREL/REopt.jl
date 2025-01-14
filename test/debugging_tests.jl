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

@testset "AC and DC PVs" begin
    # ## With single PV
    # inputs = JSON.parsefile("./scenarios/ac_dc_pvs.json")
    # inputs["ElectricLoad"]["loads_kw"] = 100 .* ones(8760)
    # inputs["ElectricTariff"]["tou_energy_rates_per_kwh"] = repeat(cat(0.2*ones(15), 0.4*ones(5), 0.2*ones(4), dims=1), outer=365)

    # m = Model(optimizer_with_attributes(HiGHS.Optimizer))
    # results = run_reopt(m, inputs)
    # open("ac_dc_pvs_results_single_pv.json","w") do f
    #     JSON.print(f, results, 4)
    # end
    # # results = JSON.parsefile("./ac_dc_pvs_results_single_pv.json")

    # results_baseline = JSON.parsefile("./ac_dc_pvs_results_baseline_single_pv.json")

    # @test results["ElectricStorage"]["size_kw"] ≈ results_baseline["ElectricStorage"]["size_kw"] atol=1
    # @test results["ElectricStorage"]["size_kwh"] ≈ results_baseline["ElectricStorage"]["size_kwh"] atol=1
    # # @test results["ElectricStorage"]["dc_couple_inverter_size_kw"] ≈  atol=0.1

    # pv_dc = results["PV"][findfirst(pv -> pv["name"] == "pv_dc", results["PV"])]
    # pv_dc_baseline = results_baseline["PV"][findfirst(pv -> pv["name"] == "pv_dc", results_baseline["PV"])]

    # @test pv_dc["size_kw"] ≈ pv_dc_baseline["size_kw"] atol=0.1
    # @test pv_dc["annual_energy_produced_kwh"] ≈ pv_dc_baseline["annual_energy_produced_kwh"] atol=1
    # @test sum(pv_dc["electric_to_storage_series_kw"]) ≈ sum(pv_dc_baseline["electric_to_storage_series_kw"]) atol=1

    # @test results["Financial"]["lcc"] ≈ results_baseline["Financial"]["lcc"] atol=1


    # ## With existing ac-coupled PV
    # inputs = JSON.parsefile("./scenarios/ac_dc_pvs_existing.json")
    # inputs["ElectricLoad"]["loads_kw"] = 100 .* ones(8760)
    # inputs["ElectricTariff"]["tou_energy_rates_per_kwh"] = repeat(cat(0.2*ones(15), 0.4*ones(5), 0.2*ones(4), dims=1), outer=365)

    # m = Model(optimizer_with_attributes(HiGHS.Optimizer))
    # results = run_reopt(m, inputs)
    # open("ac_dc_pvs_results_existing.json","w") do f
    #     JSON.print(f, results, 4)
    # end
    results = JSON.parsefile("./ac_dc_pvs_results_existing.json")

    # switch comparison from can charge to cannot charge once ac coupled techs not allowed to chanrge dc coupled storage
    results_baseline_ac_can_charge = JSON.parsefile("./ac_dc_pvs_results_baseline_existing_can_charge.json")
    results_baseline_ac_cannot_charge = JSON.parsefile("./ac_dc_pvs_results_baseline_existing_cannot_charge.json")
    results_baseline = results_baseline_ac_can_charge
    
    @test results["ElectricStorage"]["size_kw"] ≈ results_baseline["ElectricStorage"]["size_kw"] atol=1
    @test results["ElectricStorage"]["size_kwh"] ≈ results_baseline["ElectricStorage"]["size_kwh"] atol=1
    # @test results["ElectricStorage"]["dc_couple_inverter_size_kw"] ≈  atol=0.1

    pv_ac = results["PV"][findfirst(pv -> pv["name"] == "pv_ac", results["PV"])]
    pv_dc = results["PV"][findfirst(pv -> pv["name"] == "pv_dc", results["PV"])]
    pv_ac_baseline = results_baseline["PV"][findfirst(pv -> pv["name"] == "pv_ac", results_baseline["PV"])]
    pv_dc_baseline = results_baseline["PV"][findfirst(pv -> pv["name"] == "pv_dc", results_baseline["PV"])]

    @test pv_ac["size_kw"] ≈ pv_ac_baseline["size_kw"] atol=0.1
    @test pv_dc["size_kw"] ≈ pv_dc_baseline["size_kw"] atol=0.1
    @test sum(pv_ac["electric_to_storage_series_kw"]) ≈ sum(pv_ac_baseline["electric_to_storage_series_kw"]) atol=.1
    @test sum(pv_dc["electric_to_storage_series_kw"]) ≈ sum(pv_dc_baseline["electric_to_storage_series_kw"]) atol=1

    # @test pv_ac["size_kw"] ≈ 30.0 atol=0.1
    # @test pv_dc["size_kw"] ≈ pv_dc_baseline["size_kw"] + pv_ac_baseline["size_kw"] - 30.0 atol=0.1
    # @test sum(pv_ac["electric_to_storage_series_kw"]) ≈ 0.0 atol=.1
    # @test sum(pv_dc["electric_to_storage_series_kw"]) ≈ sum(pv_ac_baseline["electric_to_storage_series_kw"]) + sum(pv_dc_baseline["electric_to_storage_series_kw"]) atol=1
    
    @test results["Financial"]["lcc"] ≈ results_baseline["Financial"]["lcc"] atol=1
end