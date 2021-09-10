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
using Cbc
using JSON
using REoptLite


if "Xpress" in ARGS
    @testset "test_with_xpress" begin
        include("test_with_xpress.jl")
    end

elseif "CPLEX" in ARGS
    @testset "test_with_cplex" begin
        include("test_with_cplex.jl")
    end

else  # run Cbc tests
    #=
    Cbc can be very slow with integers: if ElectricUtility.allow_simultaneous_export_import == false for example (a 
        test with Xpress and CPLEX) the problem does not solve in under five hours.
    So, we test some simple cases with Cbc to stay aware of solve times with a free solver.
    =#
    @testset "January Export Rates" begin
        model = Model(optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0))
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
        @test results["Financial"]["lcc"] ≈ 430747.0 rtol=1e-5 # with levelization_factor hack the LCC is within 5e-5 of REopt Lite API LCC
        @test all(x == 0.0 for x in results["PV"]["year_one_to_load_series_kw"][1:744])
    end

    @testset "Blended tariff" begin
        model = Model(optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0))
        results = run_reopt(model, "./scenarios/no_techs.json")
        @test results["ElectricTariff"]["year_one_energy_cost"] ≈ 1000.0
        @test results["ElectricTariff"]["year_one_demand_cost"] ≈ 136.99
    end

    @testset "Solar and Storage" begin
        model = Model(optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0))
        r = run_reopt(model, "./scenarios/pv_storage.json")

        @test r["PV"]["size_kw"] ≈ 216.6667 atol=0.01
        @test r["Financial"]["lcc"] ≈ 1.240037e7 rtol=1e-5
        @test r["Storage"]["size_kw"] ≈ 55.9 atol=0.1
        @test r["Storage"]["size_kwh"] ≈ 78.9 atol=0.1
    end

    @testset "Outage with Generator" begin
        model = Model(optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0))
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
        model = Model(optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0))
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
        model = Model(optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0))
        results = run_reopt(model, "./scenarios/incentives.json")
        @test results["Financial"]["lcc"] ≈ 1.1152536e7 atol=5e4  
        # The Cbc LCC is 1.7% higher than the Xpress LCC ? Probably due to integer issues in Cbc
    end

    @testset "Wind" begin
        model = Model(optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0))
        results = run_reopt(model, "./scenarios/wind.json")
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


    ## much too slow with Cbc (killed after 8 hours)
    # @testset "Minimize Unserved Load" begin
    #     m = Model(optimizer_with_attributes(Cbc.Optimizer, "logLevel"=>0))
    #     results = run_reopt(m, "./scenarios/outage.json")

    #     @test results["expected_outage_cost"] ≈ 0
    #     @test results["total_unserved_load"] ≈ 0
    #     @test value(m[:binMGTechUsed]["Generator"]) == 1
    #     @test value(m[:binMGTechUsed]["PV"]) == 0
    #     @test value(m[:binMGStorageUsed]) == 1
    #     @test results["lcc"] ≈ 1.5291695e7
    # end
end
