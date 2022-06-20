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
using Random
Random.seed!(42)  # for test consistency, random prices used in FlexibleHVAC tests


@testset "Thermal loads" begin
    m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    results = run_reopt(m, "./scenarios/thermal_load.json")

    @test round(results["ExistingBoiler"]["year_one_fuel_consumption_mmbtu"], digits=0) ≈ 2905
    
    data = JSON.parsefile("./scenarios/thermal_load.json")
    data["DomesticHotWaterLoad"]["fuel_loads_mmbtu_per_hour"] = repeat([0.5], 8760)
    data["SpaceHeatingLoad"]["fuel_loads_mmbtu_per_hour"] = repeat([0.5], 8760)
    s = Scenario(data)
    inputs = REoptInputs(s)
    m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
    results = run_reopt(m, inputs)

    @test round(results["ExistingBoiler"]["year_one_fuel_consumption_mmbtu"], digits=0) ≈ 8760
    # TODO chiller tests
end

# @testset "CHP" begin
#     @testset "CHP Sizing" begin
#         # Sizing CHP with non-constant efficiency, no cost curve, no unavailability_periods
#         data_sizing = JSON.parsefile("./scenarios/chp_sizing.json")
#         s = Scenario(data_sizing)
#         inputs = REoptInputs(s)
#         m = Model(optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 0.01, "OUTPUTLOG" => 0))
#         results = run_reopt(m, inputs)
    
#         @test round(results["CHP"]["size_kw"], digits=0) ≈ 468.7 atol=1.0
#         @test round(results["Financial"]["lcc"], digits=0) ≈ 1.3476e7 atol=1.0e7
#     end

#     @testset "CHP Cost Curve and Min Allowable Size" begin
#         # Fixed size CHP with cost curve, no unavailability_periods
#         data_cost_curve = JSON.parsefile("./scenarios/chp_sizing.json")
#         data_cost_curve["CHP"] = Dict()
#         data_cost_curve["CHP"]["prime_mover"] = "recip_engine"
#         data_cost_curve["CHP"]["size_class"] = 2
#         data_cost_curve["CHP"]["fuel_cost_per_mmbtu"] = 8.0
#         data_cost_curve["CHP"]["min_kw"] = 0
#         data_cost_curve["CHP"]["min_allowable_kw"] = 555.5
#         data_cost_curve["CHP"]["max_kw"] = 1000
#         data_cost_curve["CHP"]["installed_cost_per_kw"] = 1800.0
#         data_cost_curve["CHP"]["installed_cost_per_kw"] = [2300.0, 1800.0, 1500.0]
#         data_cost_curve["CHP"]["tech_sizes_for_cost_curve"] = [100.0, 300.0, 1140.0]
    
#         data_cost_curve["CHP"]["federal_itc_pct"] = 0.1
#         data_cost_curve["CHP"]["macrs_option_years"] = 0
#         data_cost_curve["CHP"]["macrs_bonus_pct"] = 0.0
#         data_cost_curve["CHP"]["macrs_itc_reduction"] = 0.0
    
#         expected_x = data_cost_curve["CHP"]["min_allowable_kw"]
#         cap_cost_y = data_cost_curve["CHP"]["installed_cost_per_kw"]
#         cap_cost_x = data_cost_curve["CHP"]["tech_sizes_for_cost_curve"]
#         slope = (cap_cost_x[3] * cap_cost_y[3] - cap_cost_x[2] * cap_cost_y[2]) / (cap_cost_x[3] - cap_cost_x[2])
#         init_capex_chp_expected = cap_cost_x[2] * cap_cost_y[2] + (expected_x - cap_cost_x[2]) * slope
#         lifecycle_capex_chp_expected = init_capex_chp_expected - 
#             REopt.npv(data_cost_curve["Financial"]["offtaker_discount_pct"], 
#             [0, init_capex_chp_expected * data_cost_curve["CHP"]["federal_itc_pct"]])
    
#         #PV
#         data_cost_curve["PV"]["min_kw"] = 1500
#         data_cost_curve["PV"]["max_kw"] = 1500
#         data_cost_curve["PV"]["installed_cost_per_kw"] = 1600
#         data_cost_curve["PV"]["federal_itc_pct"] = 0.26
#         data_cost_curve["PV"]["macrs_option_years"] = 0
#         data_cost_curve["PV"]["macrs_bonus_pct"] = 0.0
#         data_cost_curve["PV"]["macrs_itc_reduction"] = 0.0
    
#         init_capex_pv_expected = data_cost_curve["PV"]["max_kw"] * data_cost_curve["PV"]["installed_cost_per_kw"]
#         lifecycle_capex_pv_expected = init_capex_pv_expected - 
#             REopt.npv(data_cost_curve["Financial"]["offtaker_discount_pct"], 
#             [0, init_capex_pv_expected * data_cost_curve["PV"]["federal_itc_pct"]])
    
#         s = Scenario(data_cost_curve)
#         inputs = REoptInputs(s)
#         m = Model(optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 0.01, "OUTPUTLOG" => 0))
#         results = run_reopt(m, inputs)
    
#         init_capex_total_expected = init_capex_chp_expected + init_capex_pv_expected
#         lifecycle_capex_total_expected = lifecycle_capex_chp_expected + lifecycle_capex_pv_expected
    
#         init_capex_total = results["Financial"]["initial_capital_costs"]
#         lifecycle_capex_total = results["Financial"]["initial_capital_costs_after_incentives"]
    
    
#         # Check initial CapEx (pre-incentive/tax) and life cycle CapEx (post-incentive/tax) cost with expect
#         @test init_capex_total_expected ≈ init_capex_total atol=0.0001*init_capex_total_expected
#         @test lifecycle_capex_total_expected ≈ lifecycle_capex_total atol=0.0001*lifecycle_capex_total_expected
    
#         # Test CHP.min_allowable_kw - the size would otherwise be ~100 kW less by setting min_allowable_kw to zero
#         @test results["CHP"]["size_kw"] ≈ data_cost_curve["CHP"]["min_allowable_kw"] atol=0.1
#     end

#     @testset "CHP Unavailability and Outage" begin
#         """
#         Validation to ensure that:
#             1) CHP meets load during outage without exporting
#             2) CHP never exports if chp.can_wholesale and chp.can_net_meter inputs are False (default)
#             3) CHP does not "curtail", i.e. send power to a load bank when chp.can_curtail is False (default)
#             4) CHP min_turn_down_pct is ignored during an outage
#             5) **Not until cooling is added:** Cooling load gets zeroed out during the outage period
#             6) Unavailability intervals that intersect with grid-outages get ignored
#             7) Unavailability intervals that do not intersect with grid-outages result in no CHP production
#         """
#         # Sizing CHP with non-constant efficiency, no cost curve, no unavailability_periods
#         data = JSON.parsefile("./scenarios/chp_unavailability_outage.json")
    
#         # Add unavailability periods that 1) intersect (ignored) and 2) don't intersect with outage period
#         data["CHP"]["unavailability_periods"] = [Dict([("month", 1), ("start_week_of_month", 2),
#                 ("start_day_of_week", 1), ("start_hour", 1), ("duration_hours", 8)]),
#                 Dict([("month", 1), ("start_week_of_month", 2),
#                 ("start_day_of_week", 3), ("start_hour", 9), ("duration_hours", 8)])]
    
#         # Manually doing the math from the unavailability defined above
#         unavail_1_start = 24 + 1
#         unavail_1_end = unavail_1_start + 8 - 1
#         unavail_2_start = 24*3 + 9
#         unavail_2_end = unavail_2_start + 8 - 1
        
#         # Specify the CHP.min_turn_down_pct which is NOT used during an outage
#         data["CHP"]["min_turn_down_pct"] = 0.5
#         # Specify outage period; outage time_steps are 1-indexed
#         outage_start = unavail_1_start
#         data["ElectricUtility"]["outage_start_time_step"] = outage_start
#         outage_end = unavail_1_end
#         data["ElectricUtility"]["outage_end_time_step"] = outage_end
#         data["ElectricLoad"]["critical_load_pct"] = 0.25
    
#         s = Scenario(data)
#         inputs = REoptInputs(s)
#         m = Model(optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 0.01, "OUTPUTLOG" => 0))
#         results = run_reopt(m, inputs)
    
#         tot_elec_load = results["ElectricLoad"]["load_series_kw"]
#         chp_total_elec_prod = results["CHP"]["year_one_electric_production_series_kw"]
#         chp_to_load = results["CHP"]["year_one_to_load_series_kw"]
#         chp_export = results["CHP"]["year_one_to_grid_series_kw"]
#         #cooling_elec_load = results["LoadProfileChillerThermal"]["year_one_chiller_electric_load_kw"]
    
#         # The values compared to the expected values
#         #@test sum([(chp_to_load[i] - tot_elec_load[i]) for i in outage_start:outage_end])) == 0.0
#         critical_load = tot_elec_load[outage_start:outage_end] * data["ElectricLoad"]["critical_load_pct"]
#         @test sum(chp_to_load[outage_start:outage_end]) ≈ sum(critical_load) atol=0.1
#         @test sum(chp_export) == 0.0
#         @test sum(chp_total_elec_prod) ≈ sum(chp_to_load) atol=1.0e-5*sum(chp_total_elec_prod)
#         #@test sum(cooling_elec_load[outage_start:outage_end]) == 0.0 
#         @test sum(chp_total_elec_prod[unavail_2_start:unavail_2_end]) == 0.0  
#     end

#     @testset "CHP Supplementary firing and standby" begin
#         """
#         Test to ensure that supplementary firing and standby charges work as intended.  The thermal and 
#         electrical loads are constant, and the CHP system size is fixed; the supplementary firing has a
#         similar cost to the boiler and is purcahsed and used when the boiler efficiency is set to a lower 
#         value than that of the supplementary firing. The test also ensures that demand charges are  
#         correctly calculated when CHP is and is not allowed to reduce demand charges.
#         """
#         data = JSON.parsefile("./scenarios/chp_supplementary_firing.json")
#         data["CHP"]["supplementary_firing_capital_cost_per_kw"] = 10000
#         data["ElectricLoad"]["loads_kw"] = repeat([800.0], 8760)
#         data["DomesticHotWaterLoad"]["fuel_loads_mmbtu_per_hour"] = repeat([6.0], 8760)
#         data["SpaceHeatingLoad"]["fuel_loads_mmbtu_per_hour"] = repeat([6.0], 8760)
#         #part 1: supplementary firing not used when less efficient than the boiler and expensive 
#         m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#         s = Scenario(data)
#         inputs = REoptInputs(s)
#         results = run_reopt(m1, inputs)
#         @test results["CHP"]["size_kw"] == 800
#         @test results["CHP"]["size_supplemental_firing_kw"] == 0
#         @test results["CHP"]["year_one_electric_energy_produced_kwh"] ≈ 800*8760 rtol=1e-5
#         @test results["CHP"]["year_one_thermal_energy_produced_mmbtu"] ≈ 800*(0.4418/0.3573)*8760/293.07107 rtol=1e-5
#         @test results["ElectricTariff"]["lifecycle_demand_cost_after_tax"] == 0
    
#         #part 2: supplementary firing used when more efficient than the boiler and low-cost; demand charges not reduced by CHP
#         data["CHP"]["supplementary_firing_capital_cost_per_kw"] = 10
#         data["CHP"]["reduces_demand_charges"] = false
#         data["ExistingBoiler"]["efficiency"] = 0.85
#         m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#         s = Scenario(data)
#         inputs = REoptInputs(s)
#         results = run_reopt(m2, inputs)
#         @test results["CHP"]["size_supplemental_firing_kw"] ≈ 278.73 atol=0.1
#         @test results["CHP"]["year_one_thermal_energy_produced_mmbtu"] ≈ 138624 rtol=1e-5
#         @test results["ElectricTariff"]["lifecycle_demand_cost_after_tax"] ≈ 5212.7 rtol=1e-5
#     end
# end

# @testset "FlexibleHVAC" begin

#     @testset "Single RC Model heating only" begin
#         #=
#         Single RC model:
#         1 state/control node
#         2 inputs: Ta and Qheat
#         A = [1/(RC)], B = [1/(RC) 1/C], u = [Ta; Q]
#         NOTE exogenous_inputs (u) allows for parasitic heat, but it is input as zeros here

#         We start with no technologies except ExistingBoiler and ExistingChiller. 
#         FlexibleHVAC is only worth purchasing if its cost is neglible (i.e. below the lcc_bau * MIPTOL) 
#         or if there is a time-varying fuel and/or electricity cost 
#         (and the FlexibleHVAC installed_cost is less than the achievable savings).
#         =#

#         # Austin, TX -> existing_chiller and existing_boiler added with FlexibleHVAC
#         tamb = REopt.get_ambient_temperature(30.2672, -97.7431);
#         R = 0.00025  # K/kW
#         C = 1e5   # kJ/K
#         # the starting scenario has flat fuel and electricty costs
#         d = JSON.parsefile("./scenarios/thermal_load.json");
#         A = reshape([-1/(R*C)], 1,1)
#         B = [1/(R*C) 1/C]
#         u = [tamb zeros(8760)]';
#         d["FlexibleHVAC"] = Dict(
#             "control_node" => 1,
#             "initial_temperatures" => [21],
#             "temperature_upper_bound_degC" => 22.0,
#             "temperature_lower_bound_degC" => 19.8,
#             "installed_cost" => 300.0, # NOTE cost must be more then the MIPTOL * LCC 5e-5 * 5.79661e6 ≈ 290 to make FlexibleHVAC not worth it
#             "system_matrix" => A,
#             "input_matrix" => B,
#             "exogenous_inputs" => u
#         )

#         m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#         m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#         r = run_reopt([m1,m2], d)
#         @test Meta.parse(r["FlexibleHVAC"]["purchased"]) === false
#         @test r["Financial"]["npv"] == 0

#         # put in a time varying fuel cost, which should make purchasing the FlexibleHVAC system economical
#         # with flat ElectricTariff the ExistingChiller does not benefit from FlexibleHVAC
#         d["ExistingBoiler"]["fuel_cost_per_mmbtu"] = rand(Float64, (8760))*(50-5).+5;
#         m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#         m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#         r = run_reopt([m1,m2], d)
#         # all of the savings are from the ExistingBoiler fuel costs
#         @test Meta.parse(r["FlexibleHVAC"]["purchased"]) === true
#         fuel_cost_savings = r["ExistingBoiler"]["lifecycle_fuel_cost_after_tax_bau"] - r["ExistingBoiler"]["lifecycle_fuel_cost_after_tax"]
#         @test fuel_cost_savings - d["FlexibleHVAC"]["installed_cost"] ≈ r["Financial"]["npv"] atol=0.1

#         # now increase the FlexibleHVAC installed_cost to the fuel costs savings + 100 and expect that the FlexibleHVAC is not purchased
#         d["FlexibleHVAC"]["installed_cost"] = fuel_cost_savings + 100
#         m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#         m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#         r = run_reopt([m1,m2], d)
#         @test Meta.parse(r["FlexibleHVAC"]["purchased"]) === false
#         @test r["Financial"]["npv"] == 0

#         # add TOU ElectricTariff and expect to benefit from using ExistingChiller intelligently
#         d["ElectricTariff"] = Dict("urdb_label" => "5ed6c1a15457a3367add15ae")

#         m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#         m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#         r = run_reopt([m1,m2], d)

#         elec_cost_savings = r["ElectricTariff"]["lifecycle_demand_cost_after_tax_bau"] + 
#                             r["ElectricTariff"]["lifecycle_energy_cost_after_tax_bau"] - 
#                             r["ElectricTariff"]["lifecycle_demand_cost_after_tax"] - 
#                             r["ElectricTariff"]["lifecycle_energy_cost_after_tax"]

#         fuel_cost_savings = r["ExistingBoiler"]["lifecycle_fuel_cost_after_tax_bau"] - r["ExistingBoiler"]["lifecycle_fuel_cost_after_tax"]
#         @test fuel_cost_savings + elec_cost_savings - d["FlexibleHVAC"]["installed_cost"] ≈ r["Financial"]["npv"] atol=0.1

#         # now increase the FlexibleHVAC installed_cost to the fuel costs savings + elec_cost_savings 
#         # + 100 and expect that the FlexibleHVAC is not purchased
#         d["FlexibleHVAC"]["installed_cost"] = fuel_cost_savings + elec_cost_savings + 100
#         m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#         m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#         r = run_reopt([m1,m2], d)
#         @test Meta.parse(r["FlexibleHVAC"]["purchased"]) === false
#         @test r["Financial"]["npv"] == 0

#     end

#     # TODO test with hot/cold TES
#     # TODO test with PV and Storage?

#     # TODO plot deadband (BAU_HVAC) temperatures vs. optimal flexed temperatures
#     #=
#     using Plots
#     plotlyjs()
#     plot(r["FlexibleHVAC"]["temperatures_degC_node_by_time_bau"][1,:], label="bau")
#     plot!(r["FlexibleHVAC"]["temperatures_degC_node_by_time"][1,:], line=(:dot))
#     =#

#     # @testset "placeholder 5 param RC model" begin
#     #     # these tests pass locally but not on Actions ???
#     #     d = JSON.parsefile("./scenarios/thermal_load.json");
#     #     d["FlexibleHVAC"] = JSON.parsefile("./scenarios/placeholderFlexibleHVAC.json")["FlexibleHVAC"]
#     #     s = Scenario(d; flex_hvac_from_json=true);
#     #     p = REoptInputs(s);

#     #     m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     #     m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))

#     #     r = run_reopt([m1,m2], p)
#     #     @test Meta.parse(r["FlexibleHVAC"]["purchased"]) === false
#     #     @test r["Financial"]["npv"] == 0

#     #     #= put in a time varying fuel cost, which should make purchasing the FlexibleHVAC system economical
#     #        with flat ElectricTariff the ExistingChiller does not benefit from FlexibleHVAC =#
#     #     d["ExistingBoiler"]["fuel_cost_per_mmbtu"] = rand(Float64, (8760))*(50-25).+25;
#     #     m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     #     m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     #     r = run_reopt([m1,m2], REoptInputs(Scenario(d; flex_hvac_from_json=true)))
#     #     # all of the savings are from the ExistingBoiler fuel costs
#     #     @test Meta.parse(r["FlexibleHVAC"]["purchased"]) === true
#     #     fuel_cost_savings = r["ExistingBoiler"]["lifecycle_fuel_cost_bau"] - r["ExistingBoiler"]["lifecycle_fuel_cost"]
#     #     @test fuel_cost_savings - d["FlexibleHVAC"]["installed_cost"] ≈ r["Financial"]["npv"] atol=0.1
       
#     #     # now increase the FlexibleHVAC installed_cost to the fuel costs savings + 100 and expect that the FlexibleHVAC is not purchased
#     #     d["FlexibleHVAC"]["installed_cost"] = fuel_cost_savings + 100
#     #     m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     #     m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     #     r = run_reopt([m1,m2], REoptInputs(Scenario(d; flex_hvac_from_json=true)))
#     #     @test Meta.parse(r["FlexibleHVAC"]["purchased"]) === false
#     #     @test r["Financial"]["npv"] == 0

#     #     # add TOU ElectricTariff and expect to benefit from using ExistingChiller intelligently
#     #     d["ElectricTariff"] = Dict("tou_energy_rates_per_kwh" => rand(Float64, (8760))*(0.80-0.45).+0.45)
#     #     d["FlexibleHVAC"]["temperature_upper_bound_degC"] = 18.0  # lower the upper bound to give Chiller more cost savings opportunity
#     #     d["FlexibleHVAC"]["installed_cost"] = 300
#     #     m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     #     m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     #     r = run_reopt([m1,m2], REoptInputs(Scenario(d; flex_hvac_from_json=true)))

#     #     elec_cost_savings = r["ElectricTariff"]["lifecycle_demand_cost_bau"] + 
#     #                         r["ElectricTariff"]["lifecycle_energy_cost_bau"] - 
#     #                         r["ElectricTariff"]["lifecycle_demand_cost"] - 
#     #                         r["ElectricTariff"]["lifecycle_energy_cost"]

#     #     fuel_cost_savings = r["ExistingBoiler"]["lifecycle_fuel_cost_bau"] - r["ExistingBoiler"]["lifecycle_fuel_cost"]
#     #     @test fuel_cost_savings + elec_cost_savings - d["FlexibleHVAC"]["installed_cost"] ≈ r["Financial"]["npv"] atol=0.1

#     #     # now increase the FlexibleHVAC installed_cost to the fuel costs savings + elec_cost_savings 
#     #     # + 100 and expect that the FlexibleHVAC is not purchased
#     #     d["FlexibleHVAC"]["installed_cost"] = fuel_cost_savings + elec_cost_savings + 100
#     #     m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     #     m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     #     r = run_reopt([m1,m2], REoptInputs(Scenario(d; flex_hvac_from_json=true)))
#     #     @test Meta.parse(r["FlexibleHVAC"]["purchased"]) === false
#     #     @test r["Financial"]["npv"] == 0
#     # end
# end

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

# @testset "Solar and ElectricStorage w/BAU and degradation" begin
#     m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     d = JSON.parsefile("scenarios/pv_storage.json");
#     d["Settings"] = Dict{Any,Any}("add_soc_incentive" => false)
#     results = run_reopt([m1,m2], d)

#     @test results["PV"]["size_kw"] ≈ 216.6667 atol=0.01
#     @test results["PV"]["lcoe_per_kwh"] ≈ 0.0483 atol = 0.001
#     @test results["Financial"]["lcc"] ≈ 1.240037e7 rtol=1e-5
#     @test results["Financial"]["lcc_bau"] ≈ 12766397 rtol=1e-5
#     @test results["ElectricStorage"]["size_kw"] ≈ 55.9 atol=0.1
#     @test results["ElectricStorage"]["size_kwh"] ≈ 78.9 atol=0.1
#     proforma_npv = REopt.npv(results["Financial"]["offtaker_annual_free_cashflows"] - 
#         results["Financial"]["offtaker_annual_free_cashflows_bau"], 0.081)
#     @test results["Financial"]["npv"] ≈ proforma_npv rtol=0.0001

#     # compare avg soc with and without degradation, 
#     # using default augmentation battery maintenance strategy
#     avg_soc_no_degr = sum(results["ElectricStorage"]["year_one_soc_series_pct"]) / 8760
#     d["ElectricStorage"]["model_degradation"] = true
#     m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     r_degr = run_reopt(m, d)
#     avg_soc_degr = sum(r_degr["ElectricStorage"]["year_one_soc_series_pct"]) / 8760
#     @test avg_soc_no_degr > avg_soc_degr

#     # test the replacement strategy
#     d["ElectricStorage"]["degradation"] = Dict("maintenance_strategy" => "replacement")
#     m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     set_optimizer_attribute(m, "MIPRELSTOP", 0.01)
#     r = run_reopt(m, d)
#     #optimal SOH at end of horizon is 80\% to prevent any replacement
#     @test sum(value.(m[:bmth_BkWh])) ≈ 0 atol=0.1
#     # @test r["ElectricStorage"]["maintenance_cost"] ≈ 2972.66 atol=0.01 
#     # the maintenance_cost comes out to 3004.39 on Actions, so we test the LCC since it should match
#     @test r["Financial"]["lcc"] ≈ 1.240096e7  rtol=0.01
#     @test last(value.(m[:SOH])) ≈ 63.129  rtol=0.01
#     @test r["ElectricStorage"]["size_kwh"] ≈ 78.91  rtol=0.01

#     # test minimum_avg_soc_fraction
#     d["ElectricStorage"]["minimum_avg_soc_fraction"] = 0.72
#     m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     set_optimizer_attribute(m, "MIPRELSTOP", 0.01)
#     r = run_reopt(m, d)
#     @test round(sum(r["ElectricStorage"]["year_one_soc_series_pct"]), digits=2) / 8760 >= 0.72
# end

# @testset "Outage with Generator, outate simulator, BAU critical load outputs" begin
#     m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     p = REoptInputs("./scenarios/generator.json")
#     results = run_reopt([m1,m2], p)
#     @test results["Generator"]["size_kw"] ≈ 8.13 atol=0.01
#     @test (sum(results["Generator"]["year_one_to_load_series_kw"][i] for i in 1:9) + 
#            sum(results["Generator"]["year_one_to_load_series_kw"][i] for i in 13:8760)) == 0
#     @test results["ElectricLoad"]["bau_critical_load_met"] == false
#     @test results["ElectricLoad"]["bau_critical_load_met_time_steps"] == 0
    
#     simresults = simulate_outages(results, p)
#     @test simresults["resilience_hours_max"] == 11
# end

# @testset "Minimize Unserved Load" begin
#     m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     results = run_reopt(m, "./scenarios/outage.json")

#     @test results["Outages"]["expected_outage_cost"] ≈ 0
#     @test sum(results["Outages"]["unserved_load_per_outage_series"]) ≈ 0
#     @test value(m[:binMGTechUsed]["Generator"]) == 1
#     @test value(m[:binMGTechUsed]["PV"]) == 0
#     @test value(m[:binMGStorageUsed]) == 1
#     @test results["Financial"]["lcc"] ≈ 7.3879557e7 atol=5e4
    
#     #=
#     Scenario with $0/kWh value_of_lost_load_per_kwh, 12x169 hour outages, 1kW load/hour, and min_resil_time_steps = 168
#     - should meet 168 kWh in each outage such that the total unserved load is 12 kWh
#     =#
#     m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     results = run_reopt(m, "./scenarios/nogridcost_minresilhours.json")
#     @test sum(results["Outages"]["unserved_load_per_outage_series"]) ≈ 12
    
#     # testing dvUnserved load, which would output 100 kWh for this scenario before output fix
#     m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     results = run_reopt(m, "./scenarios/nogridcost_multiscenario.json")
#     @test sum(results["Outages"]["unserved_load_per_outage_series"]) ≈ 60
    
# end

# @testset "Multiple Sites" begin
#     m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     ps = [
#         REoptInputs("./scenarios/pv_storage.json"),
#         REoptInputs("./scenarios/monthly_rate.json"),
#     ];
#     results = run_reopt(m, ps)
#     @test results[3]["Financial"]["lcc"] + results[10]["Financial"]["lcc"] ≈ 1.240037e7 + 437169.0 rtol=1e-5
# end

# @testset "MPC" begin
#     model = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     r = run_mpc(model, "./scenarios/mpc.json")
#     @test maximum(r["ElectricUtility"]["to_load_series_kw"][1:15]) <= 98.0 
#     @test maximum(r["ElectricUtility"]["to_load_series_kw"][16:24]) <= 97.0
#     @test sum(r["PV"]["to_grid_series_kw"]) ≈ 0
#     grid_draw = r["ElectricUtility"]["to_load_series_kw"] .+ r["ElectricUtility"]["to_battery_series_kw"]
#     # the grid draw limit in the 10th time step is set to 90
#     # without the 90 limit the grid draw is 98 in the 10th time step
#     @test grid_draw[10] <= 90
# end

# @testset "Complex Incentives" begin
#     """
#     This test was compared against the API test:
#         reo.tests.test_reopt_url.EntryResourceTest.test_complex_incentives
#     when using the hardcoded levelization_factor in this package's REoptInputs function.
#     The two LCC's matched within 0.00005%. (The Julia pkg LCC is  1.0971991e7)
#     """
#     m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     results = run_reopt(m, "./scenarios/incentives.json")
#     @test results["Financial"]["lcc"] ≈ 1.094596365e7 atol=5e4  
# end

# @testset verbose = true "Rate Structures" begin

#     @testset "Tiered Energy" begin
#         m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#         results = run_reopt(m, "./scenarios/tiered_rate.json")
#         @test results["ElectricTariff"]["year_one_energy_cost_before_tax"] ≈ 2342.88
#     end

#     @testset "Lookback Demand Charges" begin
#         m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#         results = run_reopt(m, "./scenarios/lookback_rate.json")
#         @test results["ElectricTariff"]["year_one_demand_cost_before_tax"] ≈ 721.99
#     end

#     @testset "Blended tariff" begin
#         model = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#         results = run_reopt(model, "./scenarios/no_techs.json")
#         @test results["ElectricTariff"]["year_one_energy_cost_before_tax"] ≈ 1000.0
#         @test results["ElectricTariff"]["year_one_demand_cost_before_tax"] ≈ 136.99
#     end

#     @testset "Coincident Peak Charges" begin
#         model = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#         results = run_reopt(model, "./scenarios/coincident_peak.json")
#         @test results["ElectricTariff"]["year_one_coincident_peak_cost_before_tax"] ≈ 11.1
#     end

#     @testset "URDB sell rate" begin
#         #= The URDB contains at least one "Customer generation" tariff that only has a "sell" key in the energyratestructure (the tariff tested here)
#         =#
#         model = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#         p = REoptInputs("./scenarios/URDB_customer_generation.json")
#         results = run_reopt(model, p)
#         @test results["PV"]["size_kw"] ≈ p.max_sizes["PV"]
#     end

#     # # tiered monthly demand rate  TODO: expected results?
#     # m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     # data = JSON.parsefile("./scenarios/tiered_rate.json")
#     # data["ElectricTariff"]["urdb_label"] = "59bc22705457a3372642da67"
#     # s = Scenario(data)
#     # inputs = REoptInputs(s)
#     # results = run_reopt(m, inputs)

#     # TODO test for tiered TOU demand rates
# end

# @testset "Wind" begin
#     m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     results = run_reopt(m, "./scenarios/wind.json")
#     @test results["Wind"]["size_kw"] ≈ 3752 atol=0.1
#     @test results["Financial"]["lcc"] ≈ 8.591017e6 rtol=1e-5
#     #= 
#     0.5% higher LCC in this package as compared to API ? 8,591,017 vs 8,551,172
#     - both have zero curtailment
#     - same energy to grid: 5,839,317 vs 5,839,322
#     - same energy to load: 4,160,683 vs 4,160,677
#     - same city: Boulder
#     - same total wind prod factor
    
#     REopt.jl has:
#     - bigger turbine: 3752 vs 3735
#     - net_capital_costs_plus_om: 8,576,590 vs. 8,537,480

#     TODO: will these discrepancies be addressed once NMIL binaries are added?
#     =#
# end

# @testset "Multiple PVs" begin
#     m1 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     m2 = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     results = run_reopt([m1,m2], "./scenarios/multiple_pvs.json")

#     ground_pv = results["PV"][findfirst(pv -> pv["name"] == "ground", results["PV"])]
#     roof_west = results["PV"][findfirst(pv -> pv["name"] == "roof_west", results["PV"])]
#     roof_east = results["PV"][findfirst(pv -> pv["name"] == "roof_east", results["PV"])]

#     @test ground_pv["size_kw"] ≈ 15 atol=0.1
#     @test roof_west["size_kw"] ≈ 7 atol=0.1
#     @test roof_east["size_kw"] ≈ 4 atol=0.1
#     @test ground_pv["lifecycle_om_cost_after_tax_bau"] ≈ 782.0 atol=0.1
#     @test roof_west["lifecycle_om_cost_after_tax_bau"] ≈ 782.0 atol=0.1
#     @test ground_pv["average_annual_energy_produced_kwh_bau"] ≈ 8844.19 atol=0.1
#     @test roof_west["average_annual_energy_produced_kwh_bau"] ≈ 7440.1 atol=0.1
#     @test ground_pv["average_annual_energy_produced_kwh"] ≈ 26533.54 atol=0.1
#     @test roof_west["average_annual_energy_produced_kwh"] ≈ 10416.52 atol=0.1
#     @test roof_east["average_annual_energy_produced_kwh"] ≈ 6482.37 atol=0.1
# end

# @testset "Thermal Energy Storage" begin
#     model = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG"=>0))
#     data = JSON.parsefile("./scenarios/thermal_storage.json")
#     s = Scenario(data)
#     p = REoptInputs(s)
#     #Make every other hour zero fuel and electric cost; storage should charge and discharge in each period
#     for ts in p.time_steps
#         #heating and cooling loads only
#         if ts % 2 == 0  #in even periods, there is a nonzero load and energy is higher cost, and storage should discharge
#             p.s.electric_load.loads_kw[ts] = 10
#             p.s.dhw_load.loads_kw[ts] = 5
#             p.s.space_heating_load.loads_kw[ts] = 5
#             p.s.cooling_load.loads_kw_thermal[ts] = 10
#             p.s.existing_boiler.fuel_cost_series[ts] = 100
#             for tier in 1:p.s.electric_tariff.n_energy_tiers
#                 p.s.electric_tariff.energy_rates[ts, tier] = 100
#             end
#         else #in odd periods, there is no load and energy is cheaper - storage should charge 
#             p.s.electric_load.loads_kw[ts] = 0
#             p.s.dhw_load.loads_kw[ts] = 0
#             p.s.space_heating_load.loads_kw[ts] = 0
#             p.s.cooling_load.loads_kw_thermal[ts] = 0
#             p.s.existing_boiler.fuel_cost_series[ts] = 1
#             for tier in 1:p.s.electric_tariff.n_energy_tiers
#                 p.s.electric_tariff.energy_rates[ts, tier] = 100
#             end
#         end
#     end

#     r = run_reopt(model, p)

#     #dispatch to load should be 10kW every other period = 4,380 * 10
#     @test sum(r["HotThermalStorage"]["year_one_to_load_series_mmbtu_per_hour"]) ≈ 256.25 atol=0.1
#     @test sum(r["ColdThermalStorage"]["year_one_to_load_series_ton"]) ≈ 6224.39 atol=0.1
#     #size should be just over 10kW in gallons, accounting for efficiency losses and min SOC
#     @test r["HotThermalStorage"]["size_gal"] ≈ 390.61 atol=0.1
#     @test r["ColdThermalStorage"]["size_gal"] ≈ 189.91 atol=0.1
#     #No production from existing chiller, only absorption chiller, which is sized at ~5kW to manage electric demand charge & capital cost.
#     @test r["ExistingChiller"]["year_one_thermal_production_tonhour"] ≈ 0.0 atol=0.1
#     @test r["AbsorptionChiller"]["year_one_thermal_production_tonhour"] ≈ 12459.24 atol=0.1
#     @test r["AbsorptionChiller"]["size_ton"] ≈ 1.422 atol=0.01
# end

# @testset "Heat and cool energy balance" begin
#     """

#     This is an "energy balance" type of test which tests the model formulation/math as opposed
#         to a specific scenario. This test is robust to changes in the model "MIPRELSTOP" or "MAXTIME" setting

#     Validation to ensure that:
#         1) The electric chiller [TODO and absorption chiller] are supplying 100% of the cooling thermal load
#         2) The boiler is supplying the boiler heating load [TODO plus additional absorption chiller thermal load]
#         3) The Cold and Hot TES efficiency (charge loss and thermal decay) are being tracked properly

#     """
#     input_data = JSON.parsefile("./scenarios/heat_cool_energy_balance_inputs.json")
#     s = Scenario(input_data)
#     inputs = REoptInputs(s)
#     m = Model(optimizer_with_attributes(Xpress.Optimizer, "MIPRELSTOP" => 0.01, "OUTPUTLOG" => 0))
#     results = run_reopt(m, inputs)

#     # Annual cooling **thermal** energy load of CRB is based on annual cooling electric energy (from CRB models) and a conditional COP depending on the peak cooling thermal load
#     # When the user specifies inputs["ExistingChiller"]["cop"], this changes the **electric** consumption of the chiller to meet that cooling thermal load
#     cooling_thermal_load_ton_hr_total = 1427329.0 * inputs.s.cooling_load.existing_chiller_cop / REopt.KWH_THERMAL_PER_TONHOUR  # From CRB models, in heating_cooling_loads.jl, BuiltInCoolingLoad data for location (SanFrancisco Hospital)
#     cooling_electric_load_total_mod_cop = cooling_thermal_load_ton_hr_total / inputs.s.existing_chiller.cop

#     # Annual heating **thermal** energy load of CRB is based on annual boiler fuel energy (from CRB models) and assumed const EXISTING_BOILER_EFFICIENCY
#     # When the user specifies inputs["ExistingBoiler"]["efficiency"], this changes the **fuel** consumption of the boiler to meet that heating thermal load
#     boiler_thermal_load_mmbtu_total = (671.40531 + 11570.9155) * REopt.EXISTING_BOILER_EFFICIENCY # From CRB models, in heating_cooling_loads.jl, BuiltInDomesticHotWaterLoad + BuiltInSpaceHeatingLoad data for location (SanFrancisco Hospital)
#     boiler_fuel_consumption_total_mod_efficiency = boiler_thermal_load_mmbtu_total / inputs.s.existing_boiler.efficiency

#     # Cooling outputs
#     cooling_elecchl_tons_to_load_series = results["ExistingChiller"]["year_one_to_load_series_ton"]
#     cooling_elecchl_tons_to_tes_series = results["ExistingChiller"]["year_one_to_tes_series_ton"]
#     #cooling_absorpchl_tons_to_load_series = results["AbsorptionChiller"]["year_one_absorp_chl_thermal_to_load_series_ton"]
#     #cooling_absorpchl_tons_to_tes_series = results["AbsorptionChiller"]["year_one_absorp_chl_thermal_to_tes_series_ton"]
#     cooling_ton_hr_to_load_tech_total = sum(cooling_elecchl_tons_to_load_series) #+ sum(cooling_absorpchl_tons_to_load_series)
#     cooling_ton_hr_to_tes_total = sum(cooling_elecchl_tons_to_tes_series) #+ sum(cooling_absorpchl_tons_to_tes_series)
#     cooling_tes_tons_to_load_series = results["ColdThermalStorage"]["year_one_to_load_series_ton"]
#     cooling_extra_from_tes_losses = cooling_ton_hr_to_tes_total - sum(cooling_tes_tons_to_load_series)
#     tes_effic_with_decay = sum(cooling_tes_tons_to_load_series) / cooling_ton_hr_to_tes_total
#     cooling_total_prod_from_techs = cooling_ton_hr_to_load_tech_total + cooling_ton_hr_to_tes_total
#     cooling_load_plus_tes_losses = cooling_thermal_load_ton_hr_total + cooling_extra_from_tes_losses

#     # Absorption Chiller electric consumption addition
#     # absorpchl_total_cooling_produced_series_ton = [cooling_absorpchl_tons_to_load_series[i] + cooling_absorpchl_tons_to_tes_series[i] for i in range(8760)] 
#     # absorpchl_total_cooling_produced_ton_hour = sum(absorpchl_total_cooling_produced_series_ton)
#     # absorpchl_electric_consumption_total_kwh = results["AbsorptionChiller"]["year_one_absorp_chl_electric_consumption_kwh"]
#     # absorpchl_cop_elec = inputs["AbsorptionChiller"]["chiller_elec_cop"]

#     # Check if sum of electric and absorption chillers equals cooling thermal total
#     @test tes_effic_with_decay < 0.97
#     println("tes_effic_with_decay = ", tes_effic_with_decay)
#     @test round(cooling_total_prod_from_techs, digits=0) ≈ cooling_load_plus_tes_losses atol=5.0
#     #self.assertAlmostEqual(absorpchl_total_cooling_produced_ton_hour * REopt.KWH_THERMAL_PER_TONHOUR / absorpchl_cop_elec, absorpchl_electric_consumption_total_kwh, places=1)

#     # Heating outputs
#     boiler_fuel_consumption_calculated = results["ExistingBoiler"]["year_one_fuel_consumption_mmbtu"]
#     boiler_thermal_series = results["ExistingBoiler"]["year_one_thermal_production_mmbtu_per_hour"]
#     boiler_to_load_series = results["ExistingBoiler"]["year_one_thermal_to_load_series_mmbtu_per_hour"]
#     boiler_thermal_to_tes_series = results["ExistingBoiler"]["thermal_to_tes_series_mmbtu_per_hour"]
#     chp_thermal_to_load_series = results["CHP"]["year_one_thermal_to_load_series_mmbtu_per_hour"]
#     chp_thermal_to_tes_series = results["CHP"]["year_one_thermal_to_tes_series_mmbtu_per_hour"]
#     chp_thermal_to_waste_series = results["CHP"]["year_one_thermal_to_waste_series_mmbtu_per_hour"]
#     # absorpchl_thermal_series = results["AbsorptionChiller"]["year_one_absorp_chl_thermal_consumption_series_mmbtu_per_hour"]
#     hot_tes_mmbtu_per_hour_to_load_series = results["HotThermalStorage"]["year_one_to_load_series_mmbtu_per_hour"]
#     tes_inflows = sum(chp_thermal_to_tes_series) + sum(boiler_thermal_to_tes_series)
#     total_chp_production = sum(chp_thermal_to_load_series) + sum(chp_thermal_to_waste_series) + sum(chp_thermal_to_tes_series)
#     tes_outflows = sum(hot_tes_mmbtu_per_hour_to_load_series)
#     total_thermal_expected = boiler_thermal_load_mmbtu_total + sum(chp_thermal_to_waste_series) + tes_inflows # + sum(absorpchl_thermal_series)
#     boiler_fuel_expected = (total_thermal_expected - total_chp_production - tes_outflows) / inputs.s.existing_boiler.efficiency
#     total_thermal_mmbtu_calculated = sum(boiler_thermal_series) + total_chp_production + tes_outflows

#     @test round(boiler_fuel_consumption_calculated, digits=0) ≈ boiler_fuel_expected atol=8.0
#     @test round(total_thermal_mmbtu_calculated, digits=0) ≈ total_thermal_expected atol=8.0  

#     # Test CHP.cooling_thermal_factor = 0.8, AbsorptionChiller.chiller_cop = 0.7 (from test_cold_POST.json)
#     # absorpchl_heat_in_kwh = results["AbsorptionChiller"]["year_one_absorp_chl_thermal_consumption_mmbtu"] * 1.0E6 / 3412.0
#     # absorpchl_cool_out_kwh = results["AbsorptionChiller"]["year_one_absorp_chl_thermal_production_tonhr"] * REopt.KWH_THERMAL_PER_TONHOUR
#     #absorpchl_cop = absorpchl_cool_out_kwh / absorpchl_heat_in_kwh

#     #self.assertAlmostEqual(absorpchl_cop, 0.8*0.7, places=3)
# end

# @testset "Heating and cooling inputs" begin
#     """

#     This tests the various ways to input heating and cooling loads to make sure they are processed correctly.
#     There are no "new" technologies in this test, so heating is served by ExistingBoiler, and 
#         cooling is served by ExistingCooler. Since this is just inputs processing tests, no optimization is needed.

#     """
#     input_data = JSON.parsefile("./scenarios/heating_cooling_load_inputs.json")
#     s = Scenario(input_data)
#     inputs = REoptInputs(s)

#     # Heating
#     # Heating load data from CRB models is **fuel**; we convert fuel to thermal using a constant/fixed REopt.EXISTING_BOILER_EFFICIENCY,
#     #   so the thermal load is always the same for a standard CRB
#     # The **fuel** consumption to serve that thermal load may change if the user inputs a different ExistingBoiler["efficiency"]
#     total_boiler_heating_thermal_load_mmbtu = (sum(inputs.s.space_heating_load.loads_kw) + sum(inputs.s.dhw_load.loads_kw)) / REopt.KWH_PER_MMBTU
#     @test round(total_boiler_heating_thermal_load_mmbtu, digits=0) ≈ 2904 * REopt.EXISTING_BOILER_EFFICIENCY atol=1.0  # The input load is **fuel**, not thermal
#     total_boiler_heating_fuel_load_mmbtu = total_boiler_heating_thermal_load_mmbtu / inputs.s.existing_boiler.efficiency
#     @test round(total_boiler_heating_fuel_load_mmbtu, digits=0) ≈ 2904 * REopt.EXISTING_BOILER_EFFICIENCY / inputs.s.existing_boiler.efficiency atol=1.0
#     # The expected cooling load is based on the default **fraction of total electric** profile for the doe_reference_name when annual_tonhour is NOT input
#     #    the 320540.0 kWh number is from the default LargeOffice fraction of total electric profile applied to the Hospital default total electric profile
#     total_chiller_electric_consumption = sum(inputs.s.cooling_load.loads_kw_thermal) / inputs.s.existing_chiller.cop
#     @test round(total_chiller_electric_consumption, digits=0) ≈ 320544.0 atol=1.0  # loads_kw is **electric**, loads_kw_thermal is **thermal**

#     delete!(input_data, "SpaceHeatingLoad")
#     delete!(input_data, "DomesticHotWaterLoad")
#     annual_fraction_of_electric_load_input = 0.5
#     input_data["CoolingLoad"] = Dict{Any, Any}("annual_fraction_of_electric_load" => annual_fraction_of_electric_load_input)

#     s = Scenario(input_data)
#     inputs = REoptInputs(s)

#     expected_cooling_electricity = sum(inputs.s.electric_load.loads_kw) * annual_fraction_of_electric_load_input
#     total_chiller_electric_consumption = sum(inputs.s.cooling_load.loads_kw_thermal) / inputs.s.cooling_load.existing_chiller_cop
#     @test round(total_chiller_electric_consumption, digits=0) ≈ round(expected_cooling_electricity) atol=1.0
#     @test round(total_chiller_electric_consumption, digits=0) ≈ 3876410 atol=1.0

#     input_data["SpaceHeatingLoad"] = Dict{Any, Any}("monthly_mmbtu" => repeat([500.0], 12))
#     input_data["DomesticHotWaterLoad"] = Dict{Any, Any}("monthly_mmbtu" => repeat([500.0], 12))
#     input_data["CoolingLoad"] = Dict{Any, Any}("monthly_fractions_of_electric_load" => repeat([0.1], 12))

#     s = Scenario(input_data)
#     inputs = REoptInputs(s)

#     total_heating_fuel_load_mmbtu = (sum(inputs.s.space_heating_load.loads_kw) + 
#                                     sum(inputs.s.dhw_load.loads_kw)) / REopt.EXISTING_BOILER_EFFICIENCY / REopt.KWH_PER_MMBTU
#     @test round(total_heating_fuel_load_mmbtu, digits=0) ≈ 12000 atol=1.0
#     total_chiller_electric_consumption = sum(inputs.s.cooling_load.loads_kw_thermal) / inputs.s.cooling_load.existing_chiller_cop
#     @test round(total_chiller_electric_consumption, digits=0) ≈ 775282 atol=1.0

#     input_data["SpaceHeatingLoad"] = Dict{Any, Any}("fuel_loads_mmbtu_per_hour" => repeat([0.5], 8760))
#     input_data["DomesticHotWaterLoad"] = Dict{Any, Any}("fuel_loads_mmbtu_per_hour" => repeat([0.5], 8760))
#     input_data["CoolingLoad"] = Dict{Any, Any}("per_time_step_fractions_of_electric_load" => repeat([0.01], 8760))

#     s = Scenario(input_data)
#     inputs = REoptInputs(s)

#     total_heating_fuel_load_mmbtu = (sum(inputs.s.space_heating_load.loads_kw) + 
#                                     sum(inputs.s.dhw_load.loads_kw)) / REopt.EXISTING_BOILER_EFFICIENCY / REopt.KWH_PER_MMBTU
#     @test round(total_heating_fuel_load_mmbtu, digits=0) ≈ 8760 atol=0.1
#     @test round(sum(inputs.s.cooling_load.loads_kw_thermal) / inputs.s.cooling_load.existing_chiller_cop, digits=0) ≈ 77528.0 atol=1.0

#     # Make sure annual_tonhour is preserved with conditional existing_chiller_default logic, where guess-and-correct method is applied
#     input_data["SpaceHeatingLoad"] = Dict{Any, Any}()
#     input_data["DomesticHotWaterLoad"] = Dict{Any, Any}()
#     annual_tonhour = 25000.0
#     input_data["CoolingLoad"] = Dict{Any, Any}("doe_reference_name" => "Hospital",
#                                                 "annual_tonhour" => annual_tonhour)
#     input_data["ExistingChiller"] = Dict{Any, Any}()

#     s = Scenario(input_data)
#     inputs = REoptInputs(s)
    
#     @test round(sum(inputs.s.cooling_load.loads_kw_thermal) / REopt.KWH_THERMAL_PER_TONHOUR, digits=0) ≈ annual_tonhour atol=1.0 
# end

# @testset "Hybrid/blended heating and cooling loads" begin
#     """

#     This tests the hybrid/campus loads for heating and cooling, where a blended_doe_reference_names
#         and blended_doe_reference_percents are given and blended to create an aggregate load profile

#     """
#     input_data = JSON.parsefile("./scenarios/hybrid_loads_heating_cooling_inputs.json")

#     hospital_pct = 0.75
#     hotel_pct = 1.0 - hospital_pct

#     # Hospital only
#     input_data["ElectricLoad"]["annual_kwh"] = hospital_pct * 100
#     input_data["ElectricLoad"]["doe_reference_name"] = "Hospital"
#     input_data["SpaceHeatingLoad"]["annual_mmbtu"] = hospital_pct * 100
#     input_data["SpaceHeatingLoad"]["doe_reference_name"] = "Hospital"
#     input_data["DomesticHotWaterLoad"]["annual_mmbtu"] = hospital_pct * 100
#     input_data["DomesticHotWaterLoad"]["doe_reference_name"] = "Hospital"    
#     input_data["CoolingLoad"]["doe_reference_name"] = "Hospital"

#     s = Scenario(input_data)
#     inputs = REoptInputs(s)

#     elec_hospital = inputs.s.electric_load.loads_kw
#     space_hospital = inputs.s.space_heating_load.loads_kw  # thermal
#     dhw_hospital = inputs.s.dhw_load.loads_kw  # thermal
#     cooling_hospital = inputs.s.cooling_load.loads_kw_thermal  # thermal
#     cooling_elec_frac_of_total_hospital = cooling_hospital / inputs.s.cooling_load.existing_chiller_cop ./ elec_hospital

#     # Hotel only
#     input_data["ElectricLoad"]["annual_kwh"] = hotel_pct * 100
#     input_data["ElectricLoad"]["doe_reference_name"] = "LargeHotel"
#     input_data["SpaceHeatingLoad"]["annual_mmbtu"] = hotel_pct * 100
#     input_data["SpaceHeatingLoad"]["doe_reference_name"] = "LargeHotel"
#     input_data["DomesticHotWaterLoad"]["annual_mmbtu"] = hotel_pct * 100
#     input_data["DomesticHotWaterLoad"]["doe_reference_name"] = "LargeHotel"    
#     input_data["CoolingLoad"]["doe_reference_name"] = "LargeHotel"

#     s = Scenario(input_data)
#     inputs = REoptInputs(s)

#     elec_hotel = inputs.s.electric_load.loads_kw
#     space_hotel = inputs.s.space_heating_load.loads_kw  # thermal
#     dhw_hotel = inputs.s.dhw_load.loads_kw  # thermal
#     cooling_hotel = inputs.s.cooling_load.loads_kw_thermal  # thermal
#     cooling_elec_frac_of_total_hotel = cooling_hotel / inputs.s.cooling_load.existing_chiller_cop ./ elec_hotel

#     # Hybrid mix of hospital and hotel
#     # Remove previous assignment of doe_reference_name
#     for load in ["ElectricLoad", "SpaceHeatingLoad", "DomesticHotWaterLoad", "CoolingLoad"]
#         delete!(input_data[load], "doe_reference_name")
#     end
#     annual_energy = (hospital_pct + hotel_pct) * 100
#     building_list = ["Hospital", "LargeHotel"]
#     percent_share_list = [hospital_pct, hotel_pct]
#     input_data["ElectricLoad"]["annual_kwh"] = annual_energy
#     input_data["ElectricLoad"]["blended_doe_reference_names"] = building_list
#     input_data["ElectricLoad"]["blended_doe_reference_percents"] = percent_share_list

#     input_data["SpaceHeatingLoad"]["annual_mmbtu"] = annual_energy
#     input_data["SpaceHeatingLoad"]["blended_doe_reference_names"] = building_list
#     input_data["SpaceHeatingLoad"]["blended_doe_reference_percents"] = percent_share_list
#     input_data["DomesticHotWaterLoad"]["annual_mmbtu"] = annual_energy
#     input_data["DomesticHotWaterLoad"]["blended_doe_reference_names"] = building_list
#     input_data["DomesticHotWaterLoad"]["blended_doe_reference_percents"] = percent_share_list    

#     # CoolingLoad now use a weighted fraction of total electric profile if no annual_tonhour is provided
#     input_data["CoolingLoad"]["blended_doe_reference_names"] = building_list
#     input_data["CoolingLoad"]["blended_doe_reference_percents"] = percent_share_list    

#     s = Scenario(input_data)
#     inputs = REoptInputs(s)

#     elec_hybrid = inputs.s.electric_load.loads_kw
#     space_hybrid = inputs.s.space_heating_load.loads_kw  # thermal
#     dhw_hybrid = inputs.s.dhw_load.loads_kw  # thermal
#     cooling_hybrid = inputs.s.cooling_load.loads_kw_thermal   # thermal
#     cooling_elec_hybrid = cooling_hybrid / inputs.s.cooling_load.existing_chiller_cop  # electric
#     cooling_elec_frac_of_total_hybrid = cooling_hybrid / inputs.s.cooling_load.existing_chiller_cop ./ elec_hybrid

#     # Check that the combined/hybrid load is the same as the sum of the individual loads in each time_step

#     @test round(sum(elec_hybrid .- (elec_hospital .+ elec_hotel)), digits=1) ≈ 0.0 atol=0.1
#     @test round(sum(space_hybrid .- (space_hospital .+ space_hotel)), digits=1) ≈ 0.0 atol=0.1
#     @test round(sum(dhw_hybrid .- (dhw_hospital .+ dhw_hotel)), digits=1) ≈ 0.0 atol=0.1
#     # Check that the cooling load is the weighted average of the default CRB fraction of total electric profiles
#     cooling_electric_hybrid_expected = elec_hybrid .* (cooling_elec_frac_of_total_hospital * hospital_pct  .+ 
#                                             cooling_elec_frac_of_total_hotel * hotel_pct)
#     @test round(sum(cooling_electric_hybrid_expected .- cooling_elec_hybrid), digits=1) ≈ 0.0 atol=0.1
# end

# ## equivalent REopt API Post for test 2:
# #   NOTE have to hack in API levelization_factor to get LCC within 5e-5 (Mosel tol)
# # {"Scenario": {
# #     "Site": {
# #         "longitude": -118.1164613,
# #         "latitude": 34.5794343,
# #         "roof_squarefeet": 5000.0,
# #         "land_acres": 1.0,
# #     "PV": {
# #         "macrs_bonus_pct": 0.4,
# #         "installed_cost_per_kw": 2000.0,
# #         "tilt": 34.579,
# #         "degradation_pct": 0.005,
# #         "macrs_option_years": 5,
# #         "federal_itc_pct": 0.3,
# #         "module_type": 0,
# #         "array_type": 1,
# #         "om_cost_per_kw": 16.0,
# #         "macrs_itc_reduction": 0.5,
# #         "azimuth": 180.0,
# #         "federal_rebate_per_kw": 350.0,
# #         "dc_ac_ratio": 1.1
# #     },
# #     "LoadProfile": {
# #         "doe_reference_name": "RetailStore",
# #         "annual_kwh": 10000000.0,
# #         "city": "LosAngeles"
# #     },
# #     "ElectricStorage": {
# #         "total_rebate_per_kw": 100.0,
# #         "macrs_option_years": 5,
# #         "can_grid_charge": true,
# #         "macrs_bonus_pct": 0.4,
# #         "macrs_itc_reduction": 0.5,
# #         "total_itc_pct": 0,
# #         "installed_cost_per_kw": 1000.0,
# #         "installed_cost_per_kwh": 500.0,
# #         "replace_cost_per_kw": 460.0,
# #         "replace_cost_per_kwh": 230.0
# #     },
# #     "ElectricTariff": {
# #         "urdb_label": "5ed6c1a15457a3367add15ae"
# #     },
# #     "Financial": {
# #         "escalation_pct": 0.026,
# #         "offtaker_discount_pct": 0.081,
# #         "owner_discount_pct": 0.081,
# #         "analysis_years": 20,
# #         "offtaker_tax_pct": 0.4,
# #         "owner_tax_pct": 0.4,
# #         "om_cost_escalation_pct": 0.025
# #     }
# # }}}

# @testset "OffGrid" begin
#     ## Scenario 1: Solar, Storage, Fixed Generator
#     post_name = "off_grid.json" 
#     post = JSON.parsefile("./scenarios/$post_name")
#     m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     r = run_reopt(m, post)
#     scen = Scenario(post)
    
#     # Test default values 
#     @test scen.electric_utility.outage_start_time_step ≈ 1
#     @test scen.electric_utility.outage_end_time_step ≈ 8760 * scen.settings.time_steps_per_hour
#     @test scen.storage.attr["ElectricStorage"].soc_init_pct ≈ 1
#     @test scen.storage.attr["ElectricStorage"].can_grid_charge ≈ false
#     @test scen.generator.fuel_avail_gal ≈ 1.0e9
#     @test scen.generator.min_turn_down_pct ≈ 0.15
#     @test sum(scen.electric_load.loads_kw) - sum(scen.electric_load.critical_loads_kw) ≈ 0 # critical loads should equal loads_kw
#     @test scen.financial.microgrid_upgrade_cost_pct ≈ 0

#     # Test outputs
#     @test r["ElectricUtility"]["year_one_energy_supplied_kwh"] ≈ 0 # no interaction with grid
#     @test r["Financial"]["lifecycle_offgrid_other_capital_costs"] ≈ 2617.092 atol=0.01 # Check straight line depreciation calc
#     @test sum(r["ElectricLoad"]["offgrid_annual_oper_res_provided_series_kwh"]) >= sum(r["ElectricLoad"]["offgrid_annual_oper_res_required_series_kwh"]) # OR provided >= required
#     @test r["ElectricLoad"]["offgrid_load_met_pct"] >= scen.electric_load.min_load_met_annual_pct
#     @test r["PV"]["size_kw"] ≈ 5050.0
#     f = r["Financial"]
#     @test f["lifecycle_generation_tech_capital_costs"] + f["lifecycle_storage_capital_costs"] + f["lifecycle_om_costs_after_tax"] +
#              f["lifecycle_fuel_costs_after_tax"] + f["lifecycle_chp_standby_cost_after_tax"] + f["lifecycle_elecbill_after_tax"] + 
#              f["lifecycle_offgrid_other_annual_costs_after_tax"] + f["lifecycle_offgrid_other_capital_costs"] + 
#              f["lifecycle_outage_cost"] + f["lifecycle_MG_upgrade_and_fuel_cost"] - 
#              f["lifecycle_production_incentive_after_tax"] ≈ f["lcc"] atol=1.0
    
#     ## Scenario 2: Fixed Generator only
#     post["ElectricLoad"]["annual_kwh"] = 100.0
#     post["PV"]["max_kw"] = 0.0
#     post["ElectricStorage"]["max_kw"] = 0.0
#     post["Generator"]["min_turn_down_pct"] = 0.0

#     m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     r = run_reopt(m, post)

#     # Test generator outputs
#     @test r["Generator"]["average_annual_fuel_used_gal"] ≈ 7.52 # 99 kWh * 0.076 gal/kWh
#     @test r["Generator"]["average_annual_energy_produced_kwh"] ≈ 99.0
#     @test r["Generator"]["year_one_fuel_cost_before_tax"] ≈ 22.57
#     @test r["Generator"]["lifecycle_fuel_cost_after_tax"] ≈ 205.35 
#     @test r["Financial"]["initial_capital_costs"] ≈ 100*(700) 
#     @test r["Financial"]["lifecycle_capital_costs"] ≈ 100*(700+324.235442*(1-0.26)) atol=0.1 # replacement in yr 10 is considered tax deductible
#     @test r["Financial"]["initial_capital_costs_after_incentives"] ≈ 700*100 atol=0.1
#     @test r["Financial"]["replacements_future_cost_after_tax"] ≈ 700*100
#     @test r["Financial"]["replacements_present_cost_after_tax"] ≈ 100*(324.235442*(1-0.26)) atol=0.1 

#     ## Scenario 3: Fixed Generator that can meet load, but cannot meet load operating reserve requirement
#     ## This test ensures the load operating reserve requirement is being enforced
#     post["ElectricLoad"]["doe_reference_name"] = "FlatLoad"
#     post["ElectricLoad"]["annual_kwh"] = 876000.0 # requires 100 kW gen
#     post["ElectricLoad"]["min_load_met_annual_pct"] = 1.0 # requires additional generator capacity
#     post["PV"]["max_kw"] = 0.0
#     post["ElectricStorage"]["max_kw"] = 0.0
#     post["Generator"]["min_turn_down_pct"] = 0.0

#     m = Model(optimizer_with_attributes(Xpress.Optimizer, "OUTPUTLOG" => 0))
#     r = run_reopt(m, post)

#     # Test generator outputs
#     @test typeof(r) == Model # this is true when the model is infeasible

# end


