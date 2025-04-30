using JSON, REopt, HiGHS, JuMP

ENV["NREL_DEVELOPER_API_KEY"]="X52RT85w3q8uXkGqAJun7FUQfnWAmW4i1ypRdLle"

m1 = Model(HiGHS.Optimizer)
m2 = Model(HiGHS.Optimizer)
results = run_reopt([m1,m2], "./scenarios/post_1.json")

# Save results to JSON
open("./outputs/post_1.json","w") do f
    JSON.print(f, results, 2)
end