# *********************************************************************************
# REopt, Copyright (c) 2019-2020, Alliance for Sustainable Energy, LLC.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list
# of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice, this
# list of conditions and the following disclaimer in the documentation and/or other
# materials provided with the distribution.
#
# Neither the name of the copyright holder nor the names of its contributors may be
# used to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
# LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
# *********************************************************************************
using Xpress

@testset "Thermal loads" begin
    m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    results = run_reopt(m, "./scenarios/thermal_load.json")

    @test round(results["ExistingBoiler"]["year_one_boiler_fuel_consumption_mmbtu"], digits=0) ≈ 2905
    
    data = JSON.parsefile("./scenarios/thermal_load.json")
    data["DomesticHotWaterLoad"]["fuel_loads_mmbtu_per_hour"] = repeat([0.5], 8760)
    data["SpaceHeatingLoad"]["fuel_loads_mmbtu_per_hour"] = repeat([0.5], 8760)
    s = Scenario(data)
    inputs = REoptInputs(s)
    m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    results = run_reopt(m, inputs)

    @test round(results["ExistingBoiler"]["year_one_boiler_fuel_consumption_mmbtu"], digits=0) ≈ 8760
end
#=
add a time-of-export rate that is greater than retail rate for the month of January,
check to make sure that PV does NOT export unless the site load is met first for the month of January.
=#
@testset "Do not allow_simultaneous_export_import" begin
    model = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    data = JSON.parsefile("./scenarios/monthly_rate.json")

    # create wholesale_rate with compensation in January > retail rate
    jan_rate = data["ElectricTariff"]["monthly_energy_rates"][1]
    data["ElectricTariff"]["wholesale_rate"] =
        append!(repeat([jan_rate + 0.1], 31 * 24), repeat([0.0], 8760 - 31*24))
    data["ElectricTariff"]["monthly_demand_rates"] = repeat([0], 12)
    data["ElectricUtility"] = Dict("allow_simultaneous_export_import" => false)

    s = Scenario(data)
    inputs = REoptInputs(s)
    results = run_reopt(model, inputs)

    @test all(x == 0.0 for (i,x) in enumerate(results["ElectricUtility"]["year_one_to_load_series_kw"][1:744]) 
              if results["PV"]["year_one_to_grid_series_kw"][i] > 0)
end

@testset "Solar and Storage w/BAU" begin
    m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    results = run_reopt([m1,m2], "./scenarios/pv_storage.json")

    @test results["PV"]["size_kw"] ≈ 216.6667 atol=0.01
    @test results["PV"]["lcoe_per_kwh"] ≈ 0.0483 atol = 0.001
    @test results["Financial"]["lcc"] ≈ 1.240037e7 rtol=1e-5
    @test results["Financial"]["lcc_bau"] ≈ 12766397 rtol=1e-5
    @test results["Storage"]["size_kw"] ≈ 55.9 atol=0.1
    @test results["Storage"]["size_kwh"] ≈ 78.9 atol=0.1
    proforma_npv = REoptLite.npv(results["Financial"]["offtaker_annual_free_cashflows"] - 
        results["Financial"]["offtaker_annual_free_cashflows_bau"], 0.081)
    @test results["Financial"]["npv"] ≈ proforma_npv rtol=0.0001
end

@testset "Outage with Generator, outate simulator, BAU critical load outputs" begin
    m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    p = REoptInputs("./scenarios/generator.json")
    results = run_reopt([m1,m2], p)
    @test results["Generator"]["size_kw"] ≈ 8.13 atol=0.01
    @test (sum(results["Generator"]["year_one_to_load_series_kw"][i] for i in 1:9) + 
           sum(results["Generator"]["year_one_to_load_series_kw"][i] for i in 13:8760)) == 0
    @test results["ElectricLoad"]["bau_critical_load_met"] == false
    @test results["ElectricLoad"]["bau_critical_load_met_time_steps"] == 0
    
    simresults = simulate_outages(results, p)
    @test simresults["resilience_hours_max"] == 11
end

@testset "Minimize Unserved Load" begin
    m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    results = run_reopt(m, "./scenarios/outage.json")

    @test results["expected_outage_cost"] ≈ 0
    @test sum(results["unserved_load_per_outage"]) ≈ 0
    @test value(m[:binMGTechUsed]["Generator"]) == 1
    @test value(m[:binMGTechUsed]["PV"]) == 0
    @test value(m[:binMGStorageUsed]) == 1
    @test results["Financial"]["lcc"] ≈ 7.3879557e7 atol=5e4
    
    #=
    Scenario with $0/kWh value_of_lost_load_per_kwh, 12x169 hour outages, 1kW load/hour, and min_resil_timesteps = 168
    - should meet 168 kWh in each outage such that the total unserved load is 12 kWh
    =#
    m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    results = run_reopt(m, "./scenarios/nogridcost_minresilhours.json")
    @test sum(results["unserved_load_per_outage"]) ≈ 12
    
    # testing dvUnserved load, which would output 100 kWh for this scenario before output fix
    m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    results = run_reopt(m, "./scenarios/nogridcost_multiscenario.json")
    @test sum(results["unserved_load_per_outage"]) ≈ 60
    
end

@testset "Multiple Sites" begin
    m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    ps = [
        REoptInputs("./scenarios/pv_storage.json"),
        REoptInputs("./scenarios/monthly_rate.json"),
    ];
    results = run_reopt(m, ps)
    @test results[3]["Financial"]["lcc"] + results[10]["Financial"]["lcc"] ≈ 1.240037e7 + 437169.0 rtol=1e-5
end

@testset "MPC" begin
    model = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    r = run_mpc(model, "./scenarios/mpc.json")
    @test maximum(r["ElectricUtility"]["to_load_series_kw"][1:15]) <= 98.0 
    @test maximum(r["ElectricUtility"]["to_load_series_kw"][16:24]) <= 97.0
    @test sum(r["PV"]["to_grid_series_kw"]) ≈ 0
end

@testset "Complex Incentives" begin
    """
    This test was compared against the API test:
        reo.tests.test_reopt_url.EntryResourceTest.test_complex_incentives
    when using the hardcoded levelization_factor in this package's REoptInputs function.
    The two LCC's matched within 0.00005%. (The Julia pkg LCC is  1.0971991e7)
    """
    m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    results = run_reopt(m, "./scenarios/incentives.json")
    @test results["Financial"]["lcc"] ≈ 1.0968526e7 atol=5e4  
end

@testset verbose = true "Rate Structures" begin

    @testset "Tiered Energy" begin
        m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
        results = run_reopt(m, "./scenarios/tiered_rate.json")
        @test results["ElectricTariff"]["year_one_energy_cost"] ≈ 2342.88
    end

    @testset "Lookback Demand Charges" begin
        m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
        results = run_reopt(m, "./scenarios/lookback_rate.json")
        @test results["ElectricTariff"]["year_one_demand_cost"] ≈ 721.99
    end

    @testset "Blended tariff" begin
        model = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
        results = run_reopt(model, "./scenarios/no_techs.json")
        @test results["ElectricTariff"]["year_one_energy_cost"] ≈ 1000.0
        @test results["ElectricTariff"]["year_one_demand_cost"] ≈ 136.99
    end

    @testset "Coincident Peak Charges" begin
        model = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
        results = run_reopt(model, "./scenarios/coincident_peak.json")
        @test results["ElectricTariff"]["year_one_coincident_peak_cost"] ≈ 15.0
        @test results["ElectricTariff"]["lifecycle_coincident_peak_cost"] ≈ 15.0 * 12.94887 atol=0.1
    end

    # # tiered monthly demand rate  TODO: expected results?
    # m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    # data = JSON.parsefile("./scenarios/tiered_rate.json")
    # data["ElectricTariff"]["urdb_label"] = "59bc22705457a3372642da67"
    # s = Scenario(data)
    # inputs = REoptInputs(s)
    # results = run_reopt(m, inputs)

    # TODO test for tiered TOU demand rates
end

@testset "Wind" begin
    m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    results = run_reopt(m, "./scenarios/wind.json")
    @test results["Wind"]["size_kw"] ≈ 3752 atol=0.1
    @test results["Financial"]["lcc"] ≈ 8.591017e6 rtol=1e-5
    #= 
    0.5% higher LCC in this package as compared to API ? 8,591,017 vs 8,551,172
    - both have zero curtailment
    - same energy to grid: 5,839,317 vs 5,839,322
    - same energy to load: 4,160,683 vs 4,160,677
    - same city: Boulder
    - same total wind prod factor
    
    REoptLite.jl has:
    - bigger turbine: 3752 vs 3735
    - net_capital_costs_plus_om: 8,576,590 vs. 8,537,480

    TODO: will these discrepancies be addressed once NMIL binaries are added?
    =#
end

@testset "Multiple PVs" begin
    m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    results = run_reopt([m1,m2], "./scenarios/multiple_pvs.json")

    ground_pv = results["PV"][findfirst(pv -> pv["name"] == "ground", results["PV"])]
    roof_west = results["PV"][findfirst(pv -> pv["name"] == "roof_west", results["PV"])]
    roof_east = results["PV"][findfirst(pv -> pv["name"] == "roof_east", results["PV"])]

    @test ground_pv["size_kw"] ≈ 15 atol=0.1
    @test roof_west["size_kw"] ≈ 7 atol=0.1
    @test roof_east["size_kw"] ≈ 4 atol=0.1
    @test ground_pv["lifecycle_om_cost_bau"] ≈ 782.0 atol=0.1
    @test roof_west["lifecycle_om_cost_bau"] ≈ 782.0 atol=0.1
    @test ground_pv["average_annual_energy_produced_kwh_bau"] ≈ 8844.19 atol=0.1
    @test roof_west["average_annual_energy_produced_kwh_bau"] ≈ 7440.1 atol=0.1
    @test ground_pv["average_annual_energy_produced_kwh"] ≈ 26533.54 atol=0.1
    @test roof_west["average_annual_energy_produced_kwh"] ≈ 10416.52 atol=0.1
    @test roof_east["average_annual_energy_produced_kwh"] ≈ 6482.37 atol=0.1
end

## equivalent REopt Lite API Post for test 2:
#   NOTE have to hack in API levelization_factor to get LCC within 5e-5 (Mosel tol)
# {"Scenario": {
#     "Site": {
#         "longitude": -118.1164613,
#         "latitude": 34.5794343,
#         "roof_squarefeet": 5000.0,
#         "land_acres": 1.0,
#     "PV": {
#         "macrs_bonus_pct": 0.4,
#         "installed_cost_per_kw": 2000.0,
#         "tilt": 34.579,
#         "degradation_pct": 0.005,
#         "macrs_option_years": 5,
#         "federal_itc_pct": 0.3,
#         "module_type": 0,
#         "array_type": 1,
#         "om_cost_per_kw": 16.0,
#         "macrs_itc_reduction": 0.5,
#         "azimuth": 180.0,
#         "federal_rebate_per_kw": 350.0,
#         "dc_ac_ratio": 1.1
#     },
#     "LoadProfile": {
#         "doe_reference_name": "RetailStore",
#         "annual_kwh": 10000000.0,
#         "city": "LosAngeles"
#     },
#     "Storage": {
#         "total_rebate_per_kw": 100.0,
#         "macrs_option_years": 5,
#         "can_grid_charge": true,
#         "macrs_bonus_pct": 0.4,
#         "macrs_itc_reduction": 0.5,
#         "total_itc_pct": 0,
#         "installed_cost_per_kw": 1000.0,
#         "installed_cost_per_kwh": 500.0,
#         "replace_cost_per_kw": 460.0,
#         "replace_cost_per_kwh": 230.0
#     },
#     "ElectricTariff": {
#         "urdb_label": "5ed6c1a15457a3367add15ae"
#     },
#     "Financial": {
#         "escalation_pct": 0.026,
#         "offtaker_discount_pct": 0.081,
#         "owner_discount_pct": 0.081,
#         "analysis_years": 20,
#         "offtaker_tax_pct": 0.4,
#         "owner_tax_pct": 0.4,
#         "om_cost_escalation_pct": 0.025
#     }
# }}}