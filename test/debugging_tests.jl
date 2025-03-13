# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
using HiGHS
using DelimitedFiles

@testset "MPC" begin
    model = Model(optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false, "log_to_console" => false))
    r = run_mpc(model, "./scenarios/mpc.json")
    @test maximum(r["ElectricUtility"]["to_load_series_kw"][1:15]) <= 98.0 
    @test maximum(r["ElectricUtility"]["to_load_series_kw"][16:24]) <= 97.0
    @test sum(r["PV"]["to_grid_series_kw"]) ≈ 0
    grid_draw = r["ElectricUtility"]["to_load_series_kw"] .+ r["ElectricUtility"]["to_battery_series_kw"]
    # the grid draw limit in the 10th time step is set to 90
    # without the 90 limit the grid draw is 98 in the 10th time step
    @test grid_draw[10] <= 90
end

@testset "Solar and ElectricStorage w/BAU and degradation" begin
    m1 = Model(optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false, "log_to_console" => false))
    m2 = Model(optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false, "log_to_console" => false))
    d = JSON.parsefile("scenarios/pv_storage.json");
    d["Settings"] = Dict{Any,Any}("add_soc_incentive" => false)
    results = run_reopt([m1,m2], d)
    open("debug_results1.json","w") do f
        JSON.print(f, results, 4)
    end

    @test results["PV"]["size_kw"] ≈ 216.6667 atol=0.01
    @test results["PV"]["lcoe_per_kwh"] ≈ 0.0468 atol = 0.001
    @test results["Financial"]["lcc"] ≈ 1.239179e7 rtol=1e-5
    @test results["Financial"]["lcc_bau"] ≈ 12766397 rtol=1e-5
    @test results["ElectricStorage"]["size_kw"] ≈ 49.02 atol=0.1
    @test results["ElectricStorage"]["size_kwh"] ≈ 83.3 atol=0.1
    proforma_npv = REopt.npv(results["Financial"]["offtaker_annual_free_cashflows"] - 
        results["Financial"]["offtaker_annual_free_cashflows_bau"], 0.081)
    @test results["Financial"]["npv"] ≈ proforma_npv rtol=0.0001

    # compare avg soc with and without degradation, 
    # using default augmentation battery maintenance strategy
    avg_soc_no_degr = sum(results["ElectricStorage"]["soc_series_fraction"]) / 8760

    d = JSON.parsefile("scenarios/pv_storage.json");
    d["ElectricStorage"]["model_degradation"] = true
    m = Model(optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false, "log_to_console" => false))
    r_degr = run_reopt(m, d)
    open("debug_results2.json","w") do f
        JSON.print(f, r_degr, 4)
    end
    avg_soc_degr = sum(r_degr["ElectricStorage"]["soc_series_fraction"]) / 8760
    @test avg_soc_no_degr > avg_soc_degr

    # test the replacement strategy ## Cannot test with open source solvers.
    # d["ElectricStorage"]["degradation"] = Dict("maintenance_strategy" => "replacement")
    # m = Model(optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false, "log_to_console" => false))
    # set_optimizer_attribute(m, "mip_rel_gap", 0.01)
    # r = run_reopt(m, d)
    # @test occursin("not supported by the solver", string(r["Messages"]["errors"]))
    # #optimal SOH at end of horizon is 80\% to prevent any replacement
    # @test sum(value.(m[:dvSOHChangeTimesEnergy])) ≈ 68.48 atol=0.01
    # # @test r["ElectricStorage"]["maintenance_cost"] ≈ 2972.66 atol=0.01 
    # # the maintenance_cost comes out to 3004.39 on Actions, so we test the LCC since it should match
    # @test r["Financial"]["lcc"] ≈ 1.240096e7  rtol=0.01
    # @test last(value.(m[:SOH])) ≈ 42.95 rtol=0.01
    # @test r["ElectricStorage"]["size_kwh"] ≈ 68.48 rtol=0.01

    # test minimum_avg_soc_fraction
    d["ElectricStorage"]["minimum_avg_soc_fraction"] = 0.72
    m = Model(optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false, "log_to_console" => false))
    set_optimizer_attribute(m, "mip_rel_gap", 0.01)
    r = run_reopt(m, d)
    open("debug_results3.json","w") do f
        JSON.print(f, r, 4)
    end
    @test round(sum(r["ElectricStorage"]["soc_series_fraction"])/8760, digits=2) >= 0.72
end


@testset "Emissions and Renewable Energy Percent" begin
    #renewable energy and emissions reduction targets
    include_exported_RE_in_total = [true,false,true]
    include_exported_ER_in_total = [true,false,true]
    RE_target = [0.8,nothing,nothing]
    ER_target = [nothing,0.8,nothing]
    with_outage = [true,false,false]

    for i in range(1, stop=3)
        if i == 3
            inputs = JSON.parsefile("./scenarios/re_emissions_with_thermal.json")
        else
            inputs = JSON.parsefile("./scenarios/re_emissions_elec_only.json")
        end
        if i == 1
            inputs["Site"]["latitude"] = 37.746
            inputs["Site"]["longitude"] = -122.448
            # inputs["ElectricUtility"]["emissions_region"] = "California"
        end
        inputs["Site"]["include_exported_renewable_electricity_in_total"] = include_exported_RE_in_total[i]
        inputs["Site"]["include_exported_elec_emissions_in_total"] = include_exported_ER_in_total[i]
        inputs["Site"]["renewable_electricity_min_fraction"] = if isnothing(RE_target[i]) 0.0 else RE_target[i] end
        inputs["Site"]["renewable_electricity_max_fraction"] = RE_target[i]
        inputs["Site"]["CO2_emissions_reduction_min_fraction"] = ER_target[i]
        inputs["Site"]["CO2_emissions_reduction_max_fraction"] = ER_target[i]
        if with_outage[i]
            outage_start_hour = 4032
            outage_duration = 2000 #hrs
            inputs["ElectricUtility"]["outage_start_time_step"] = outage_start_hour + 1
            inputs["ElectricUtility"]["outage_end_time_step"] = outage_start_hour + 1 + outage_duration
            inputs["Generator"]["max_kw"] = 20
            inputs["Generator"]["existing_kw"] = 2
            inputs["Generator"]["fuel_avail_gal"] = 1000 
        end

        m1 = Model(optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false, "log_to_console" => false, "presolve" => "on"))
        m2 = Model(optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false, "log_to_console" => false, "presolve" => "on"))
        results = run_reopt([m1, m2], inputs)

        open("debug_results4.json","w") do f
            JSON.print(f, results, 4)
        end

        if !isnothing(ER_target[i])  
            ER_fraction_out = results["Site"]["lifecycle_emissions_reduction_CO2_fraction"]
            @test ER_target[i] ≈ ER_fraction_out atol=1e-3
            lifecycle_emissions_tonnes_CO2_out = results["Site"]["lifecycle_emissions_tonnes_CO2"]
            lifecycle_emissions_bau_tonnes_CO2_out = results["Site"]["lifecycle_emissions_tonnes_CO2_bau"]
            ER_fraction_calced_out = (lifecycle_emissions_bau_tonnes_CO2_out-lifecycle_emissions_tonnes_CO2_out)/lifecycle_emissions_bau_tonnes_CO2_out
            ER_fraction_diff = abs(ER_fraction_calced_out-ER_fraction_out)
            @test ER_fraction_diff ≈ 0.0 atol=1e-2
        end

        annual_emissions_tonnes_CO2_out = results["Site"]["annual_emissions_tonnes_CO2"]
        yr1_fuel_emissions_tonnes_CO2_out = results["Site"]["annual_emissions_from_fuelburn_tonnes_CO2"]
        yr1_grid_emissions_tonnes_CO2_out = results["ElectricUtility"]["annual_emissions_tonnes_CO2"]
        yr1_total_emissions_calced_tonnes_CO2 = yr1_fuel_emissions_tonnes_CO2_out + yr1_grid_emissions_tonnes_CO2_out 
        @test annual_emissions_tonnes_CO2_out ≈ yr1_total_emissions_calced_tonnes_CO2 atol=1e-1
        if haskey(results["Financial"],"breakeven_cost_of_emissions_reduction_per_tonne_CO2")
            @test results["Financial"]["breakeven_cost_of_emissions_reduction_per_tonne_CO2"] >= 0.0
        end
        
        if i == 1
            @test results["PV"]["size_kw"] ≈ 59.7222 atol=1e-1
            @test results["ElectricStorage"]["size_kw"] ≈ 0.0 atol=1e-1
            @test results["ElectricStorage"]["size_kwh"] ≈ 0.0 atol=1e-1
            @test results["Generator"]["size_kw"] ≈ 9.13 atol=1e-1
            @test results["Site"]["onsite_renewable_energy_fraction_of_total_load"] ≈ 0.8
            @test results["Site"]["onsite_renewable_energy_fraction_of_total_load_bau"] ≈ 0.148375 atol=1e-4
            @test results["Site"]["lifecycle_emissions_reduction_CO2_fraction"] ≈ 0.587 rtol=0.01
            @test results["Financial"]["breakeven_cost_of_emissions_reduction_per_tonne_CO2"] ≈ 336.4 rtol=0.01
            @test results["Site"]["annual_emissions_tonnes_CO2"] ≈ 11.1 rtol=0.01
            @test results["Site"]["annual_emissions_from_fuelburn_tonnes_CO2"] ≈ 7.427 rtol=0.01
            @test results["Site"]["annual_emissions_from_fuelburn_tonnes_CO2_bau"] ≈ 0.0
            @test results["Site"]["lifecycle_emissions_tonnes_CO2"] ≈ 222.26 rtol=0.01
            @test results["Site"]["lifecycle_emissions_from_fuelburn_tonnes_CO2"] ≈ 148.54
            @test results["Site"]["lifecycle_emissions_from_fuelburn_tonnes_CO2_bau"] ≈ 0.0
            @test results["ElectricUtility"]["annual_emissions_tonnes_CO2_bau"] ≈ 26.9 rtol=0.01
            @test results["ElectricUtility"]["lifecycle_emissions_tonnes_CO2_bau"] ≈ 537.99 rtol=0.01
        elseif i == 2
            #commented out values are results using same levelization factor as API
            @test results["PV"]["size_kw"] ≈ 99.35 rtol=0.01
            @test results["ElectricStorage"]["size_kw"] ≈ 20.09 atol=1 # 20.29
            @test results["ElectricStorage"]["size_kwh"] ≈ 156.4 rtol=0.01
            @test !haskey(results, "Generator")
            # Renewable energy
            @test results["Site"]["onsite_renewable_electricity_fraction_of_elec_load"] ≈ 0.745 rtol=0.01
            @test results["Site"]["onsite_renewable_electricity_fraction_of_elec_load_bau"] ≈ 0.132118 atol=1e-3 #0.1354 atol=1e-3
            @test results["Site"]["annual_onsite_renewable_electricity_kwh_bau"] ≈ 13308.5 atol=10 # 13542.62 atol=10
            @test results["Site"]["onsite_renewable_energy_fraction_of_total_load_bau"] ≈ 0.132118 atol=1e-3 # 0.1354 atol=1e-3
            # CO2 emissions - totals ≈  from grid, from fuelburn, ER, $/tCO2 breakeven
            @test results["Site"]["lifecycle_emissions_reduction_CO2_fraction"] ≈ 0.8 atol=1e-3 # 0.8
            @test results["Site"]["annual_emissions_tonnes_CO2"] ≈ 11.79 rtol=0.01
            @test results["Site"]["annual_emissions_tonnes_CO2_bau"] ≈ 58.97 rtol=0.01
            @test results["Site"]["annual_emissions_from_fuelburn_tonnes_CO2"] ≈ 0.0 atol=1 # 0.0
            @test results["Financial"]["lifecycle_emissions_cost_climate"] ≈ 8496.6 rtol=0.01
            @test results["Site"]["lifecycle_emissions_from_fuelburn_tonnes_CO2"] ≈ 0.0 atol=1 # 0.0
            @test results["Site"]["lifecycle_emissions_from_fuelburn_tonnes_CO2_bau"] ≈ 0.0 atol=1 # 0.0
            @test results["ElectricUtility"]["lifecycle_emissions_tonnes_CO2"] ≈ 235.9 rtol=0.01


            #also test CO2 breakeven cost
            inputs["PV"]["min_kw"] = results["PV"]["size_kw"] - inputs["PV"]["existing_kw"]
            inputs["PV"]["max_kw"] = results["PV"]["size_kw"] - inputs["PV"]["existing_kw"]
            inputs["ElectricStorage"]["min_kw"] = results["ElectricStorage"]["size_kw"]
            inputs["ElectricStorage"]["max_kw"] = results["ElectricStorage"]["size_kw"]
            inputs["ElectricStorage"]["min_kwh"] = results["ElectricStorage"]["size_kwh"]
            inputs["ElectricStorage"]["max_kwh"] = results["ElectricStorage"]["size_kwh"]
            inputs["Financial"]["CO2_cost_per_tonne"] = results["Financial"]["breakeven_cost_of_emissions_reduction_per_tonne_CO2"]
            inputs["Settings"]["include_climate_in_objective"] = true
            m1 = Model(optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false, "log_to_console" => false, "presolve" => "on"))
            m2 = Model(optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false, "log_to_console" => false, "presolve" => "on"))
            results = run_reopt([m1, m2], inputs)

            open("debug_results5.json","w") do f
                JSON.print(f, results, 4)
            end
            @test results["Financial"]["breakeven_cost_of_emissions_reduction_per_tonne_CO2"] ≈ inputs["Financial"]["CO2_cost_per_tonne"] rtol=0.001
        elseif i == 3
            @test results["PV"]["size_kw"] ≈ 20.0 atol=1e-1
            @test !haskey(results, "Wind")
            @test !haskey(results, "ElectricStorage")
            @test !haskey(results, "Generator")
            @test results["CHP"]["size_kw"] ≈ 200.0 atol=1e-1
            @test results["AbsorptionChiller"]["size_ton"] ≈ 400.0 atol=1e-1
            @test results["HotThermalStorage"]["size_gal"] ≈ 50000 atol=1e1
            @test results["ColdThermalStorage"]["size_gal"] ≈ 30000 atol=1e1
            yr1_nat_gas_mmbtu = results["ExistingBoiler"]["annual_fuel_consumption_mmbtu"] + results["CHP"]["annual_fuel_consumption_mmbtu"]
            nat_gas_emissions_lb_per_mmbtu = Dict("CO2"=>117.03, "NOx"=>0.09139, "SO2"=>0.000578592, "PM25"=>0.007328833)
            TONNE_PER_LB = 1/2204.62
            @test results["Site"]["annual_emissions_from_fuelburn_tonnes_CO2"] ≈ nat_gas_emissions_lb_per_mmbtu["CO2"] * yr1_nat_gas_mmbtu * TONNE_PER_LB atol=1
            @test results["Site"]["annual_emissions_from_fuelburn_tonnes_NOx"] ≈ nat_gas_emissions_lb_per_mmbtu["NOx"] * yr1_nat_gas_mmbtu * TONNE_PER_LB atol=1e-2
            @test results["Site"]["annual_emissions_from_fuelburn_tonnes_SO2"] ≈ nat_gas_emissions_lb_per_mmbtu["SO2"] * yr1_nat_gas_mmbtu * TONNE_PER_LB atol=1e-2
            @test results["Site"]["annual_emissions_from_fuelburn_tonnes_PM25"] ≈ nat_gas_emissions_lb_per_mmbtu["PM25"] * yr1_nat_gas_mmbtu * TONNE_PER_LB atol=1e-2
            @test results["Site"]["lifecycle_emissions_tonnes_CO2"] ≈ results["Site"]["lifecycle_emissions_from_fuelburn_tonnes_CO2"] + results["ElectricUtility"]["lifecycle_emissions_tonnes_CO2"] rtol=0.001
            @test results["Site"]["lifecycle_emissions_tonnes_NOx"] ≈ results["Site"]["lifecycle_emissions_from_fuelburn_tonnes_NOx"] + results["ElectricUtility"]["lifecycle_emissions_tonnes_NOx"] rtol=0.001
            @test results["Site"]["lifecycle_emissions_tonnes_SO2"] ≈ results["Site"]["lifecycle_emissions_from_fuelburn_tonnes_SO2"] + results["ElectricUtility"]["lifecycle_emissions_tonnes_SO2"] rtol=0.01 # rounding causes difference
            @test results["Site"]["lifecycle_emissions_tonnes_PM25"] ≈ results["Site"]["lifecycle_emissions_from_fuelburn_tonnes_PM25"] + results["ElectricUtility"]["lifecycle_emissions_tonnes_PM25"] rtol=0.001
            @test results["Site"]["annual_onsite_renewable_electricity_kwh"] ≈ results["PV"]["annual_energy_produced_kwh"] + inputs["CHP"]["fuel_renewable_energy_fraction"] * results["CHP"]["annual_electric_production_kwh"] atol=1
            @test results["Site"]["onsite_renewable_electricity_fraction_of_elec_load"] ≈ results["Site"]["annual_onsite_renewable_electricity_kwh"] / results["ElectricLoad"]["annual_electric_load_with_thermal_conversions_kwh"] rtol=0.001
            annual_RE_kwh = inputs["CHP"]["fuel_renewable_energy_fraction"] * results["CHP"]["annual_thermal_production_mmbtu"] * REopt.KWH_PER_MMBTU + results["Site"]["annual_onsite_renewable_electricity_kwh"]
            annual_heat_kwh = (results["CHP"]["annual_thermal_production_mmbtu"] + results["ExistingBoiler"]["annual_thermal_production_mmbtu"]) * REopt.KWH_PER_MMBTU
            @test results["Site"]["onsite_renewable_energy_fraction_of_total_load"] ≈ annual_RE_kwh / (annual_heat_kwh + results["ElectricLoad"]["annual_electric_load_with_thermal_conversions_kwh"]) rtol=0.001
        end
    end
end

@testset "Prevent simultaneous charge and discharge" begin
    logger = SimpleLogger()
    results = nothing
    with_logger(logger) do
        model = Model(optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false, "log_to_console" => false))
        results = run_reopt(model, "./scenarios/simultaneous_charge_discharge.json")
        
    end
    @test any(.&(
            results["ElectricStorage"]["storage_to_load_series_kw"] .!= 0.0,
            (
                results["ElectricUtility"]["electric_to_storage_series_kw"] .+ 
                results["PV"]["electric_to_storage_series_kw"]
            ) .!= 0.0
        )
        ) ≈ false
    @test any(.&(
            results["Outages"]["storage_discharge_series_kw"] .!= 0.0,
            results["Outages"]["pv_to_storage_series_kw"] .!= 0.0
        )
        ) ≈ false
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

# @testset "AC and DC PVs ensure with each step output changes make sense" begin
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

#     results_baseline = JSON.parsefile("./ac_dc_pvs_results_single_pv_prev.json")

#     @test results["ElectricStorage"]["size_kw"] ≈ results_baseline["ElectricStorage"]["size_kw"] rtol=.005 # 100
#     @test results["ElectricStorage"]["size_kwh"] ≈ results_baseline["ElectricStorage"]["size_kwh"] rtol=.005 # 594.86
#     # @test results["ElectricStorage"]["dc_coupled_inverter_size_kw"] ≈  atol=0.1

#     pv_dc = results["PV"][findfirst(pv -> pv["name"] == "pv_dc", results["PV"])]
#     pv_dc_baseline = results_baseline["PV"][findfirst(pv -> pv["name"] == "pv_dc", results_baseline["PV"])]

#     @test pv_dc["size_kw"] ≈ pv_dc_baseline["size_kw"] rtol=.005 # 332.0863
#     @test pv_dc["annual_energy_produced_kwh"] ≈ pv_dc_baseline["annual_energy_produced_kwh"] rtol=.0001 # 555058.5
#     @test sum(pv_dc["electric_to_storage_series_kw"]) ≈ sum(pv_dc_baseline["electric_to_storage_series_kw"]) rtol=.0001 # 175575.27

#     @test results["Financial"]["lcc"] ≈ results_baseline["Financial"]["lcc"] rtol=.001 # 1.3867364184e6


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

#     results_baseline = JSON.parsefile("./ac_dc_pvs_results_existing_prev.json")
    
#     @test results["ElectricStorage"]["size_kw"] ≈ results_baseline["ElectricStorage"]["size_kw"] rtol=.001 # 100.0
#     @test results["ElectricStorage"]["size_kwh"] ≈ results_baseline["ElectricStorage"]["size_kwh"] rtol=.001 # 597.92
#     # @test results["ElectricStorage"]["dc_coupled_inverter_size_kw"] ≈  atol=0.1

#     pv_ac = results["PV"][findfirst(pv -> pv["name"] == "pv_ac", results["PV"])]
#     pv_dc = results["PV"][findfirst(pv -> pv["name"] == "pv_dc", results["PV"])]
#     pv_ac_baseline = results_baseline["PV"][findfirst(pv -> pv["name"] == "pv_ac", results_baseline["PV"])]
#     pv_dc_baseline = results_baseline["PV"][findfirst(pv -> pv["name"] == "pv_dc", results_baseline["PV"])]

#     @test pv_ac["size_kw"] ≈ pv_ac_baseline["size_kw"] rtol=.005 # 30.0
#     @test pv_dc["size_kw"] ≈ pv_dc_baseline["size_kw"] rtol=.005 # 302.9552
#     @test sum(pv_ac["electric_to_storage_series_kw"]) ≈ 0.0 rtol=.0001 # 0
#     @test sum(pv_dc["electric_to_storage_series_kw"]) ≈ sum(pv_ac_baseline["electric_to_storage_series_kw"]) + sum(pv_dc_baseline["electric_to_storage_series_kw"]) rtol=.0001 # 176038.056
    
#     @test results["Financial"]["lcc"] ≈ results_baseline["Financial"]["lcc"] rtol=.001 # 1.3605789661e6
# end
