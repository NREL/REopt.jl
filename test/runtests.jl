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
using Test
using JuMP
using HiGHS
using JSON
using REopt


if "Xpress" in ARGS
    @testset "test_with_xpress" begin
        include("test_with_xpress.jl")
    end

elseif "CPLEX" in ARGS
    @testset "test_with_cplex" begin
        include("test_with_cplex.jl")
    end

else  # run HiGHS tests

    @testset "Inputs" begin
        @testset "hybrid profile" begin
            electric_load = REopt.ElectricLoad(; 
                blended_doe_reference_percents = [0.2, 0.2, 0.2, 0.2, 0.2],
                blended_doe_reference_names    = ["RetailStore", "LargeOffice", "MediumOffice", "SmallOffice", "Warehouse"],
                annual_kwh                     = 50000.0,
                year                           = 2017,
                city                           = "Atlanta",
                latitude                       = 35.2468, 
                longitude                      = -91.7337
            )
            @test sum(electric_load.loads_kw) ≈ 50000.0
        end
    end

    @testset "January Export Rates" begin
        model = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, "log_to_console" => false)
        )
        data = JSON.parsefile("./scenarios/monthly_rate.json")

        # create wholesale_rate with compensation in January > retail rate
        jan_rate = data["ElectricTariff"]["monthly_energy_rates"][1]
        data["ElectricTariff"]["wholesale_rate"] =
            append!(repeat([jan_rate + 0.1], 31 * 24), repeat([0.0], 8760 - 31*24))
        data["ElectricTariff"]["monthly_demand_rates"] = repeat([0], 12)

        s = Scenario(data)
        inputs = REoptInputs(s)
        results = run_reopt(model, inputs)

        @test results["PV"]["size_kw"] ≈ 70.3084 atol=0.01
        @test results["Financial"]["lcc"] ≈ 430747.0 rtol=1e-5 # with levelization_factor hack the LCC is within 5e-5 of REopt API LCC
        @test all(x == 0.0 for x in results["PV"]["year_one_to_load_series_kw"][1:744])
    end

    @testset "Blended tariff" begin
        model = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, "log_to_console" => false)
        )
        results = run_reopt(model, "./scenarios/no_techs.json")
        @test results["ElectricTariff"]["year_one_energy_cost_before_tax"] ≈ 1000.0
        @test results["ElectricTariff"]["year_one_demand_cost_before_tax"] ≈ 136.99
    end

    @testset "Solar and Storage" begin
        model = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, "log_to_console" => false)
        )
        r = run_reopt(model, "./scenarios/pv_storage.json")

        @test r["PV"]["size_kw"] ≈ 216.6667 atol=0.01
        @test r["Financial"]["lcc"] ≈ 1.240037e7 rtol=1e-5
        @test r["ElectricStorage"]["size_kw"] ≈ 55.9 atol=0.1
        @test r["ElectricStorage"]["size_kwh"] ≈ 78.9 atol=0.1
    end

    @testset "Outage with Generator" begin
        model = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, "log_to_console" => false)
        )
        results = run_reopt(model, "./scenarios/generator.json")
        @test results["Generator"]["size_kw"] ≈ 8.13 atol=0.01
        @test (sum(results["Generator"]["year_one_to_load_series_kw"][i] for i in 1:9) + 
            sum(results["Generator"]["year_one_to_load_series_kw"][i] for i in 13:8760)) == 0
        p = REoptInputs("./scenarios/generator.json")
        simresults = simulate_outages(results, p)
        @test simresults["resilience_hours_max"] == 11
    end

    # TODO test MPC with outages
    @testset "MPC" begin
        model = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, "log_to_console" => false)
        )
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
        The two LCC's matched within 0.00005%. (The Julia pkg LCC is 1.0971991e7)
        """
        model = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, "log_to_console" => false)
        )
        results = run_reopt(model, "./scenarios/incentives.json")
        @test results["Financial"]["lcc"] ≈ 1.096852612e7 atol=1e4  
    end

    @testset "Fifteen minute load" begin
        d = JSON.parsefile("scenarios/no_techs.json")
        d["ElectricLoad"] = Dict("loads_kw" => repeat([1.0], 35040))
        d["Settings"] = Dict("time_steps_per_hour" => 4)
        model = Model(optimizer_with_attributes(HiGHS.Optimizer, 
            "output_flag" => false, "log_to_console" => false)
        )
        results = run_reopt(model, d)
        @test results["ElectricLoad"]["annual_calculated_kwh"] ≈ 8760
    end

    try
        rm("Highs.log", force=true)
    catch
        @warn "Could not delete test/Highs.log"
    end

    @testset "PVspecs" begin
        ## Scenario 1: Palmdale, CA; array-type = 0 (Ground-mount)
        post_name = "pv.json" 
        post = JSON.parsefile("./scenarios/$post_name")
        scen = Scenario(post)
     
        @test scen.pvs[1].tilt ≈ post["Site"]["latitude"] 
        @test scen.pvs[1].azimuth ≈ 180
    
        ## Scenario 2: Palmdale, CA; array-type = 1 (roof)
        post["PV"]["array_type"] = 1 
        scen = Scenario(post)
    
        @test scen.pvs[1].tilt ≈ 10
    
        ## Scenario 3:Cape Town; array-type = 0 (ground)
        post["Site"]["latitude"] = -33.974732
        post["Site"]["longitude"] = 19.130050
        post["PV"]["array_type"] = 0 
        scen = Scenario(post)
    
        @test scen.pvs[1].tilt ≈ abs(post["Site"]["latitude"])
        @test scen.pvs[1].azimuth ≈ 0
     
    end

    # removed Wind test for two reasons
    # 1. reduce WindToolKit calls in tests
    # 2. HiGHS does not support SOS or indicator constraints, which are needed for export constraints

    # @testset "Minimize Unserved Load" is too slow with Cbc (killed after 8 hours)
end
