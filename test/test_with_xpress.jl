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

@testset "CHP Sizing" begin
    # Sizing CHP with non-constant efficiency, no cost curve, no unavailability_periods
    data_sizing = JSON.parsefile("./scenarios/chp_sizing.json")
    s = Scenario(data_sizing)
    inputs = REoptInputs(s)
    m = Model(optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 0.01, "OUTPUTLOG" => 0))
    results = run_reopt(m, inputs)

    @test round(results["CHP"]["size_kw"], digits=0) ≈ 468.7 atol=1.0
    @test round(results["Financial"]["lcc"], digits=0) ≈ 1.3476e7 atol=1.0e7
end

@testset "CHP Cost Curve and Min Allowable Size" begin
    # Fixed size CHP with cost curve, no unavailability_periods
    data_cost_curve = JSON.parsefile("./scenarios/chp_sizing.json")
    data_cost_curve["CHP"] = Dict()
    data_cost_curve["CHP"]["prime_mover"] = "recip_engine"
    data_cost_curve["CHP"]["size_class"] = 2
    data_cost_curve["CHP"]["fuel_cost_per_mmbtu"] = 8.0
    data_cost_curve["CHP"]["min_kw"] = 0
    data_cost_curve["CHP"]["min_allowable_kw"] = 555.5
    data_cost_curve["CHP"]["max_kw"] = 1000
    data_cost_curve["CHP"]["installed_cost_per_kw"] = 1800.0
    data_cost_curve["CHP"]["installed_cost_per_kw"] = [2300.0, 1800.0, 1500.0]
    data_cost_curve["CHP"]["tech_sizes_for_cost_curve"] = [100.0, 300.0, 1140.0]

    data_cost_curve["CHP"]["federal_itc_pct"] = 0.1
    data_cost_curve["CHP"]["macrs_option_years"] = 0
    data_cost_curve["CHP"]["macrs_bonus_pct"] = 0.0
    data_cost_curve["CHP"]["macrs_itc_reduction"] = 0.0

    expected_x = data_cost_curve["CHP"]["min_allowable_kw"]
    cap_cost_y = data_cost_curve["CHP"]["installed_cost_per_kw"]
    cap_cost_x = data_cost_curve["CHP"]["tech_sizes_for_cost_curve"]
    slope = (cap_cost_x[3] * cap_cost_y[3] - cap_cost_x[2] * cap_cost_y[2]) / (cap_cost_x[3] - cap_cost_x[2])
    init_capex_chp_expected = cap_cost_x[2] * cap_cost_y[2] + (expected_x - cap_cost_x[2]) * slope
    lifecycle_capex_chp_expected = init_capex_chp_expected - 
        REoptLite.npv(data_cost_curve["Financial"]["offtaker_discount_pct"], 
        [0, init_capex_chp_expected * data_cost_curve["CHP"]["federal_itc_pct"]])

    #PV
    data_cost_curve["PV"]["min_kw"] = 1500
    data_cost_curve["PV"]["max_kw"] = 1500
    data_cost_curve["PV"]["installed_cost_per_kw"] = 1600
    data_cost_curve["PV"]["federal_itc_pct"] = 0.26
    data_cost_curve["PV"]["macrs_option_years"] = 0
    data_cost_curve["PV"]["macrs_bonus_pct"] = 0.0
    data_cost_curve["PV"]["macrs_itc_reduction"] = 0.0

    init_capex_pv_expected = data_cost_curve["PV"]["max_kw"] * data_cost_curve["PV"]["installed_cost_per_kw"]
    lifecycle_capex_pv_expected = init_capex_pv_expected - 
        REoptLite.npv(data_cost_curve["Financial"]["offtaker_discount_pct"], 
        [0, init_capex_pv_expected * data_cost_curve["PV"]["federal_itc_pct"]])

    s = Scenario(data_cost_curve)
    inputs = REoptInputs(s)
    m = Model(optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 0.01, "OUTPUTLOG" => 0))
    results = run_reopt(m, inputs)

    init_capex_total_expected = init_capex_chp_expected + init_capex_pv_expected
    lifecycle_capex_total_expected = lifecycle_capex_chp_expected + lifecycle_capex_pv_expected

    init_capex_total = results["Financial"]["initial_capital_costs"]
    lifecycle_capex_total = results["Financial"]["initial_capital_costs_after_incentives"]


    # Check initial CapEx (pre-incentive/tax) and life cycle CapEx (post-incentive/tax) cost with expect
    @test init_capex_total_expected ≈ init_capex_total atol=0.0001*init_capex_total_expected
    @test lifecycle_capex_total_expected ≈ lifecycle_capex_total atol=0.0001*lifecycle_capex_total_expected

    # Test CHP.min_allowable_kw - the size would otherwise be ~100 kW less by setting min_allowable_kw to zero
    @test results["CHP"]["size_kw"] ≈ data_cost_curve["CHP"]["min_allowable_kw"] atol=0.1
end

@testset "CHP Unavailability and Outage" begin
    """
    Validation to ensure that:
        1) CHP meets load during outage without exporting
        2) CHP never exports if chp.can_wholesale and chp.can_net_meter inputs are False (default)
        3) CHP does not "curtail", i.e. send power to a load bank when chp.can_curtail is False (default)
        4) CHP min_turn_down_pct is ignored during an outage
        5) **Not until cooling is added:** Cooling load gets zeroed out during the outage period
        6) Unavailability intervals that intersect with grid-outages get ignored
        7) Unavailability intervals that do not intersect with grid-outages result in no CHP production
    """
    # Sizing CHP with non-constant efficiency, no cost curve, no unavailability_periods
    data = JSON.parsefile("./scenarios/chp_unavailability_outage.json")

    # Add unavailability periods that 1) intersect (ignored) and 2) don't intersect with outage period
    data["CHP"]["unavailability_periods"] = [Dict([("month", 1), ("start_week_of_month", 2),
            ("start_day_of_week", 1), ("start_hour", 1), ("duration_hours", 8)]),
            Dict([("month", 1), ("start_week_of_month", 2),
            ("start_day_of_week", 3), ("start_hour", 9), ("duration_hours", 8)])]

    # Manually doing the math from the unavailability defined above
    unavail_1_start = 24 + 1
    unavail_1_end = unavail_1_start + 8 - 1
    unavail_2_start = 24*3 + 9
    unavail_2_end = unavail_2_start + 8 - 1
    
    # Specify the CHP.min_turn_down_pct which is NOT used during an outage
    data["CHP"]["min_turn_down_pct"] = 0.5
    # Specify outage period; outage timesteps are 1-indexed
    outage_start = unavail_1_start
    data["ElectricUtility"]["outage_start_time_step"] = outage_start
    outage_end = unavail_1_end
    data["ElectricUtility"]["outage_end_time_step"] = outage_end
    data["ElectricLoad"]["critical_load_pct"] = 0.25

    s = Scenario(data)
    inputs = REoptInputs(s)
    m = Model(optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 0.01, "OUTPUTLOG" => 0))
    results = run_reopt(m, inputs)

    tot_elec_load = results["ElectricLoad"]["load_series_kw"]
    chp_total_elec_prod = results["CHP"]["year_one_electric_production_series_kw"]
    chp_to_load = results["CHP"]["year_one_to_load_series_kw"]
    chp_export = results["CHP"]["year_one_to_grid_series_kw"]
    #cooling_elec_load = results["LoadProfileChillerThermal"]["year_one_chiller_electric_load_kw"]

    # The values compared to the expected values
    #@test sum([(chp_to_load[i] - tot_elec_load[i]) for i in outage_start:outage_end])) == 0.0
    critical_load = tot_elec_load[outage_start:outage_end] * data["ElectricLoad"]["critical_load_pct"]
    @test sum(chp_to_load[outage_start:outage_end]) ≈ sum(critical_load) atol=0.1
    @test sum(chp_export) == 0.0
    @test sum(chp_total_elec_prod) ≈ sum(chp_to_load) atol=1.0e-5*sum(chp_total_elec_prod)
    #@test sum(cooling_elec_load[outage_start:outage_end]) == 0.0 
    @test sum(chp_total_elec_prod[unavail_2_start:unavail_2_end]) == 0.0  
end

@testset "CHP Supplementary firing and standby" begin
    """
    Test to ensure that supplementary firing and standby charges work as intended.  The thermal and 
    electrical loads are constant, and the CHP system size is fixed; the supplementary firing has a
    similar cost to the boiler and is purcahsed and used when the boiler efficiency is set to a lower 
    value than that of the supplementary firing. The test also ensures that demand charges are  
    correctly calculated when CHP is and is not allowed to reduce demand charges.
    """
    data = JSON.parsefile("./scenarios/chp_supplementary_firing.json")
    data["CHP"]["supplementary_firing_capital_cost_per_kw"] = 10000
    data["ElectricLoad"]["loads_kw"] = repeat([800.0], 8760)
    data["DomesticHotWaterLoad"]["fuel_loads_mmbtu_per_hour"] = repeat([6.0], 8760)
    data["SpaceHeatingLoad"]["fuel_loads_mmbtu_per_hour"] = repeat([6.0], 8760)
    #part 1: supplementary firing not used when less efficient than the boiler and expensive 
    m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    s = Scenario(data)
    inputs = REoptInputs(s)
    results = run_reopt(m1, inputs)
    @test results["CHP"]["size_kw"] == 800
    @test results["CHP"]["size_supplemental_firing_kw"] == 0
    @test results["CHP"]["year_one_electric_energy_produced_kwh"] ≈ 800*8760 rtol=1e-5
    @test results["CHP"]["year_one_thermal_energy_produced_mmbtu"] ≈ 800*(0.4418/0.3573)*8760/293.07107 rtol=1e-5
    @test results["ElectricTariff"]["lifecycle_demand_cost"] == 0

    #part 2: supplementary firing used when more efficient than the boiler and low-cost; demand charges not reduced by CHP
    data["CHP"]["supplementary_firing_capital_cost_per_kw"] = 10
    data["CHP"]["reduces_demand_charges"] = false
    data["ExistingBoiler"]["efficiency"] = 0.85
    m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    s = Scenario(data)
    inputs = REoptInputs(s)
    results = run_reopt(m2, inputs)
    @test results["CHP"]["size_supplemental_firing_kw"] ≈ 278.73 atol=0.1
    @test results["CHP"]["year_one_thermal_energy_produced_mmbtu"] ≈ 138624 rtol=1e-5
    @test results["ElectricTariff"]["lifecycle_demand_cost"] ≈ 5212.7 rtol=1e-5
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

    @test results["Outages"]["expected_outage_cost"] ≈ 0
    @test sum(results["Outages"]["unserved_load_per_outage"]) ≈ 0
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
    @test sum(results["Outages"]["unserved_load_per_outage"]) ≈ 12
    
    # testing dvUnserved load, which would output 100 kWh for this scenario before output fix
    m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    results = run_reopt(m, "./scenarios/nogridcost_multiscenario.json")
    @test sum(results["Outages"]["unserved_load_per_outage"]) ≈ 60
    
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
    previous_peak_charges = 98 * 10 + 97 * 15
    next_month_peak_charges = maximum(r["ElectricUtility"]["to_load_series_kw"][21:24]) * 12
    @test r["ElectricTariff"]["demand_cost"] ≈ previous_peak_charges + next_month_peak_charges atol=0.01
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
    @test results["Financial"]["lcc"] ≈ 1.094596365e7 atol=5e4  
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

    @testset "URDB sell rate" begin
        #= The URDB contains at least one "Customer generation" tariff that only has a "sell" key in the energyratestructure (the tariff tested here)
        =#
        model = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
        p = REoptInputs("./scenarios/URDB_customer_generation.json")
        results = run_reopt(model, p)
        @test results["PV"]["size_kw"] ≈ p.max_sizes["PV"]
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
