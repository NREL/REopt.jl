using JSON, REopt, HiGHS, JuMP, DataStructures, Dates

ENV["NREL_DEVELOPER_API_KEY"] = "X52RT85w3q8uXkGqAJun7FUQfnWAmW4i1ypRdLle"
ENV["NREL_DEVELOPER_EMAIL"]= "jaret.kadlec@nrel.gov"

start_time = time()  # Record start time

m1 = Model(HiGHS.Optimizer)
m2 = Model(HiGHS.Optimizer)
results = run_reopt([m1,m2], "./scenarios/cst_tes.json")

# Save results to JSON
open("./outputs/cst_tes.json", "w") do f
    JSON.print(f, results)
end

end_time = time()  # Record end time
elapsed_seconds = round(Int, end_time - start_time)  # Get elapsed time in seconds
minutes = div(elapsed_seconds, 60)  # Get minutes
seconds = mod(elapsed_seconds, 60)  # Get remaining seconds

println("Script execution time: ", minutes, " minutes and ", seconds, " seconds")
