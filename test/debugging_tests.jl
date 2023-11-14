# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
using Xpress
using DelimitedFiles

@testset "AC and DC PVs" begin
    m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    results = run_reopt([m1,m2], "./scenarios/ac_dc_pvs.json")
    open("ac_dc_pvs_results.json","w") do f
        JSON.print(f, results, 4)
    end   

    @test results["ElectricStorage"]["size_kw"] ≈ 8.5 atol=0.1
    @test results["ElectricStorage"]["size_kwh"] ≈ 19.09 atol=0.1

    ground_pv = results["PV"][findfirst(pv -> pv["name"] == "ground", results["PV"])]
    roof_west = results["PV"][findfirst(pv -> pv["name"] == "roof_west", results["PV"])]
    roof_east = results["PV"][findfirst(pv -> pv["name"] == "roof_east", results["PV"])]

    @test ground_pv["size_kw"] ≈ 15 atol=0.1
    @test roof_west["size_kw"] ≈ 7 atol=0.1
    @test roof_east["size_kw"] ≈ 4 atol=0.1
    @test ground_pv["lifecycle_om_cost_after_tax_bau"] ≈ 782.0 atol=0.1
    @test roof_west["lifecycle_om_cost_after_tax_bau"] ≈ 782.0 atol=0.1
    @test ground_pv["annual_energy_produced_kwh_bau"] ≈ 8933.09 atol=0.1
    @test roof_west["annual_energy_produced_kwh_bau"] ≈ 7656.11 atol=0.1
    @test ground_pv["annual_energy_produced_kwh"] ≈ 26799.26 atol=0.1
    @test roof_west["annual_energy_produced_kwh"] ≈ 10719.51 atol=0.1
    @test roof_east["annual_energy_produced_kwh"] ≈ 6685.95 atol=0.1
end