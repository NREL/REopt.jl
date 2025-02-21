using REopt
using JuMP
# using Cbc
# using HiGHS
using Xpress
using JSON
# using Plots
using Test

ENV["NREL_DEVELOPER_API_KEY"]="ogQAO0gClijQdYn7WOKeIS02zTUYLbwYJJczH9St"

@testset "Electric Heater" begin
    d = JSON.parsefile("./scenarios/electric_heater.json")
    d["SpaceHeatingLoad"]["annual_mmbtu"] = 0.4 * 8760
    d["DomesticHotWaterLoad"]["annual_mmbtu"] = 0.4 * 8760
    d["ProcessHeatLoad"]["annual_mmbtu"] = 0.2 * 8760
    s = Scenario(d)
    p = REoptInputs(s)
    m = Model(optimizer_with_attributes(Xpress.Optimizer))
    results = run_reopt(m, p)
    println(results["Messages"])

    #first run: Boiler produces the required heat instead of the electric heater - electric heater should not be purchased
    @test results["ElectricHeater"]["size_mmbtu_per_hour"] ≈ 0.0 atol=0.1
    @test results["ElectricHeater"]["annual_thermal_production_mmbtu"] ≈ 0.0 atol=0.1
    @test results["ElectricHeater"]["annual_electric_consumption_kwh"] ≈ 0.0 atol=0.1
    @test results["ElectricUtility"]["annual_energy_supplied_kwh"] ≈ 87600.0 atol=0.1
    
    d["ExistingBoiler"]["fuel_cost_per_mmbtu"] = 100
    d["ElectricHeater"]["installed_cost_per_mmbtu_per_hour"] = 1.0
    d["ElectricTariff"]["monthly_energy_rates"] = [0,0,0,0,0,0,0,0,0,0,0,0]
    s = Scenario(d)
    p = REoptInputs(s)
    m = Model(optimizer_with_attributes(Xpress.Optimizer))
    results = run_reopt(m, p)
    println(results["Messages"])

    annual_thermal_prod = 0.8 * 8760  #80% efficient boiler --> 0.8 MMBTU of heat load per hour
    annual_electric_heater_consumption = annual_thermal_prod * REopt.KWH_PER_MMBTU  #1.0 COP
    annual_energy_supplied = 87600 + annual_electric_heater_consumption

    #Second run: ElectricHeater produces the required heat with free electricity
    @test results["ElectricHeater"]["size_mmbtu_per_hour"] ≈ 0.8 atol=0.1
    @test results["ElectricHeater"]["annual_thermal_production_mmbtu"] ≈ annual_thermal_prod rtol=1e-4
    @test results["ElectricHeater"]["annual_electric_consumption_kwh"] ≈ annual_electric_heater_consumption rtol=1e-4
    @test results["ElectricUtility"]["annual_energy_supplied_kwh"] ≈ annual_energy_supplied rtol=1e-4

end