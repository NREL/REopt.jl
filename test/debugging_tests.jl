# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
using HiGHS
using DelimitedFiles

@testset "AC and DC PVs" begin
    m1 = Model(optimizer_with_attributes(HiGHS.Optimizer))
    m2 = Model(optimizer_with_attributes(HiGHS.Optimizer))
    # m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0, "MAXIIS" => -1))
    # m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0, "MAXIIS" => -1))
    
    inputs = JSON.parsefile("./scenarios/ac_dc_pvs.json")
    inputs["ElectricTariff"]["tou_energy_rates_per_kwh"] = repeat(cat(0.2*ones(15), 0.4*ones(5), 0.2*ones(4), dims=1), outer=365)

    # results = run_reopt([m1,m2], inputs)
    results = run_reopt(m2, inputs)
    open("ac_dc_pvs_results.json","w") do f
        JSON.print(f, results, 4)
    end

    results_baseline = JSON.parsefile("./ac_dc_pvs_results_baseline_existing_loads_net.json")

    @test results["ElectricStorage"]["size_kw"] ≈ results_baseline["ElectricStorage"]["size_kw"] atol=0.1
    @test results["ElectricStorage"]["size_kwh"] ≈ results_baseline["ElectricStorage"]["size_kwh"] atol=0.1
    # @test results["ElectricStorage"]["dc_couple_inverter_size_kw"] ≈ 82.18 atol=0.1

    pv_ac = results["PV"][findfirst(pv -> pv["name"] == "pv_ac", results["PV"])]
    pv_dc = results["PV"][findfirst(pv -> pv["name"] == "pv_dc", results["PV"])]
    pv_ac_baseline = results_baseline["PV"][findfirst(pv -> pv["name"] == "pv_ac", results["PV"])]
    pv_dc_baseline = results_baseline["PV"][findfirst(pv -> pv["name"] == "pv_dc", results["PV"])]

    @test pv_ac["size_kw"] ≈ pv_ac_baseline["size_kw"] atol=0.1
    @test pv_dc["size_kw"] ≈ pv_dc_baseline["size_kw"] atol=0.1
    @test pv_ac["annual_energy_produced_kwh"] ≈ pv_ac_baseline["annual_energy_produced_kwh"] atol=1
    @test pv_dc["annual_energy_produced_kwh"] ≈ pv_dc_baseline["annual_energy_produced_kwh"] atol=1
    @test sum(pv_ac["electric_to_storage_series_kw"]) ≈ sum(pv_ac_baseline["electric_to_storage_series_kw"]) atol=1
    @test sum(pv_dc["electric_to_storage_series_kw"]) ≈ sum(pv_dc_baseline["electric_to_storage_series_kw"]) atol=1
end