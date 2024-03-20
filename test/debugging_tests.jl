# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.
using Cbc
using HiGHS
using SCIP
using DelimitedFiles

@testset "Solvers" begin
    
    inputs = JSON.parsefile("./scenarios/res.json")

    # # Cbc
    # m1 = Model(optimizer_with_attributes(Cbc.Optimizer,
    #     "seconds" => 420,
    #     "ratioGap" => 0.001,
    #     "logLevel" => 0)
    # )
    # m2 = Model(optimizer_with_attributes(Cbc.Optimizer,
    #     "seconds" => 420,
    #     "ratioGap" => 0.001,
    #     "logLevel" => 0)
    # )

    # results = run_reopt([m1,m2], inputs)
    # open("res_Cbc_outputs.json","w") do f
    #     JSON.print(f, results, 4)
    # end

    # HiGHS
    m1 = Model(optimizer_with_attributes(HiGHS.Optimizer, 
        "time_limit" => 420.0,
        "mip_rel_gap" => 0.001,
        "output_flag" => false, 
        "log_to_console" => false)
    )
    m2 = Model(optimizer_with_attributes(HiGHS.Optimizer,
        "time_limit" => 420.0,
        "mip_rel_gap" => 0.001,
        "output_flag" => false, 
        "log_to_console" => false)
    )

    results = run_reopt([m1,m2], inputs)
    open("res_HiGHS_outputs.json","w") do f
        JSON.print(f, results, 4)
    end

    #SCIP
    m1 = Model(optimizer_with_attributes(SCIP.Optimizer, 
        "limits/time" => 420,
        "limits/gap" => 0.001,
        "display/verblevel" => 0)
    )
    m2 = Model(optimizer_with_attributes(SCIP.Optimizer, 
        "limits/time" => 420,
        "limits/gap" => 0.001,
        "display/verblevel" => 0)
    )

    results = run_reopt([m1,m2], inputs)
    open("res_SCIP_outputs.json","w") do f
        JSON.print(f, results, 4)
    end
end