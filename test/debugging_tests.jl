# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
using Xpress
using DelimitedFiles

@testset "AC and DC PVs" begin
    m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    inputs = JSON.parsefile("./scenarios/ac_dc_pvs.json")
    inputs["ElectricTariff"]["tou_energy_rates_per_kwh"] = repeat(cat(0.2*ones(15), 0.4*ones(5), 0.2*ones(4), dims=1), outer=365)

    results = run_reopt([m1,m2], inputs)
    open("ac_dc_pvs_results.json","w") do f
        JSON.print(f, results, 4)
    end   

    @test results["ElectricStorage"]["size_kw"] ≈ 26.23 atol=0.1
    @test results["ElectricStorage"]["size_kwh"] ≈ 172.95 atol=0.1
    @test results["ElectricStorage"]["dc_couple_inverter_size_kw"] ≈ 26.23 atol=0.1

    ground_pv = results["PV"][findfirst(pv -> pv["name"] == "ground", results["PV"])]
    roof_west = results["PV"][findfirst(pv -> pv["name"] == "roof_west", results["PV"])]
    roof_east = results["PV"][findfirst(pv -> pv["name"] == "roof_east", results["PV"])]

    @test ground_pv["size_kw"] ≈ 81.6667 atol=0.1
    @test roof_west["size_kw"] ≈ 30.0 atol=0.1
    @test roof_east["size_kw"] ≈ 10.0 atol=0.1
    @test ground_pv["lifecycle_om_cost_after_tax_bau"] ≈ 6256.0 atol=0.1
    @test roof_west["lifecycle_om_cost_after_tax_bau"] ≈ 4692.0 atol=0.1
    @test ground_pv["annual_energy_produced_kwh_bau"] ≈ 71463.73 atol=0.1
    @test roof_west["annual_energy_produced_kwh_bau"] ≈ 45938.58 atol=0.1
    @test ground_pv["annual_energy_produced_kwh"] ≈ 145904.83 atol=0.1
    @test roof_west["annual_energy_produced_kwh"] ≈ 45938.58 atol=0.1
    @test roof_east["annual_energy_produced_kwh"] ≈ 16714.41 atol=0.1
    @test sum(ground_pv["electric_to_storage_series_kw"]) ≈ 52362.828 atol=0.1
    @test sum(roof_west["electric_to_storage_series_kw"]) ≈ 0 atol=0.1
    @test sum(roof_east["electric_to_storage_series_kw"]) ≈ 0 atol=0.1
end