using Test
using JuMP
using HiGHS
using JSON
using REopt
using DotEnv
DotEnv.load!()
using Random
using DelimitedFiles
using Logging
using CSV
using DataFrames

@testset "CST" begin
    d = JSON.parsefile("./scenarios/cst.json")
    s = Scenario(d)
    p = REoptInputs(s)
    m = Model(optimizer_with_attributes(HiGHS.Optimizer, "output_flag" => false, "log_to_console" => false))
    results = run_reopt(m, p)
    @test results["CST"]["size_kw"] ≈ 100.0 atol=0.1
end