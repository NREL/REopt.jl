# Import necessary libraries
import JuMP
import Xpress
import JSON
import REopt
using Statistics
using Plots
""" 
Comments: 
1) add output of max and min fuel used
2) ensure that battery is charging generator to ensure more resilience
3) fuel accounting needs to be rethought, it doesnt make sense that we are leaving fuel to be unlimited since we have cost and limits on site associated with
those varibles. It might be better to program in fuel based on size of generator or max consumption
4) Maybe make generator size a variable of 10 and place ceiling
5) Output critical_loads 
6) increasing the gen size only slightly will cause it to be infeasible
7) Might be good to get the entire year survival stats rather than just a few to get a good idea of the 
"""

function summarize_reopt_results(reopt_response)
    # Adjusting for the Financial details
    println("LCC (\$) = ", get(reopt_response["Financial"], "lcc", "N/A"))
    println("Capital Cost, Net (\$) = ", get(reopt_response["Financial"], "lifecycle_capital_costs", "N/A"))
    println("Lifecycle Emission Tons (CO2) = ", get(reopt_response["Site"], "lifecycle_emissions_tonnes_CO2", "N/A"))
    println("NPV (\$) = ", get(reopt_response["Financial"], "npv", "N/A"))
    println("LCOE (\$/kWh) = ", get(reopt_response["PV"], "lcoe_per_kwh", "N/A"))

    tech_list = ["PV", "Wind", "ElectricStorage", "CHP", "Generator", "HotThermalStorage",
        "ColdThermalStorage", "AbsorptionChiller", "GHP", "NewBoiler", "SteamTurbine"]

    for tech in tech_list
        if haskey(reopt_response, tech)
            if tech ==   "GHP"
                # Adjusting for GHP details
                println("GHX Number of Boreholes = ", get(reopt_response[tech]["ghpghx_chosen_outputs"], "number_of_boreholes", "N/A"))
                println("GHP Heat Pump Capacity (ton) = ", get(reopt_response[tech]["ghpghx_chosen_outputs"], "peak_combined_heatpump_thermal_ton", "N/A"))
            end
            # Extract sizes for each technology
            for (key, value) in reopt_response[tech]
                if occursin("size", key)
                    println("$(tech) $(key) = $(value)")
                end
            end
        end
    end
end

# ---------------------
# BASE CASE
# ---------------------

# Load inputs for REopt optimization
p =   REoptInputs("./test/scenarios/reopt_inputs.json")

# Initialize the model
model    =   Model(Xpress.Optimizer)
modelbau =   Model(Xpress.Optimizer)

# Run the REopt optimization
results =   run_reopt([modelbau, model], p)

open("./test/scenarios/initial_reopt_results.json", "w") do f
    write(f, JSON.json(results))
end
# ---------------------
# SETTING UP RELIABILITY INPUTS BASED ON BASE CASE RESULTS
# ---------------------

# Load reliability inputs from file
reliability_inputs =   JSON.parsefile("./test/scenarios/backup_reliability_inputs.json")

# Update reliability inputs based on the results from the base case
reliability_inputs["pv_size_kw"]                  =   results["PV"]["size_kw"]
reliability_inputs["critical_loads_kw"]           =   results["ElectricLoad"]["critical_load_series_kw"]
reliability_inputs["generator_size_kw"]           =   results["Generator"]["size_kw"]
reliability_inputs["battery_size_kw"]             =   results["ElectricStorage"]["size_kw"]
reliability_inputs["battery_size_kwh"]            =   results["ElectricStorage"]["size_kwh"]
reliability_inputs["pv_production_factor_series"] =   results["PV"]["production_factor_series"]
reliability_inputs["num_generators"]              =   1

# ---------------------
### COMPUTE RELIABILITY METRICS
# ---------------------

reliability_results =   backup_reliability(results, p, reliability_inputs)

# ---------------------
# SECOND ITERATION: MODIFYING GENERATOR PARAMETERS
# ---------------------
perc_increase =   50
# Increase the number of generators and adjust their size
num_generators                          =   1
reliability_inputs["generator_size_kw"] =   ceil(results["Generator"]["size_kw"] / 10) * 10
reliability_inputs["num_generators"]    =   num_generators

# Re-compute reliability metrics
reliability_results2 =   backup_reliability(results, p, reliability_inputs)

# Update generator parameters for the next optimization
generator_size_kw =   reliability_inputs["generator_size_kw"]
batt_size_kw      =   reliability_inputs["battery_size_kw"]
batt_size_kwh     =   reliability_inputs["battery_size_kwh"]
pv_kw             =   reliability_inputs["pv_size_kw"]

total_fuel_needed =   reliability_results2["max_fuel_used"]

# Load the original JSON file and update generator parameters
erp_data                                =   JSON.parsefile("./test/scenarios/reopt_inputs.json")
erp_data["Generator"]["min_kw"]         =   generator_size_kw
erp_data["Generator"]["max_kw"]         =   generator_size_kw
erp_data["PV"]["min_kw"]                =   pv_kw
erp_data["PV"]["max_kw"]                =   pv_kw
erp_data["ElectricStorage"]["min_kw"]   =   batt_size_kw
erp_data["ElectricStorage"]["max_kw"]   =   batt_size_kw
erp_data["ElectricStorage"]["min_kwh"]  =   batt_size_kwh
erp_data["ElectricStorage"]["max_kwh"]  =   batt_size_kwh
erp_data["Generator"]["fuel_avail_gal"] =   ceil(total_fuel_needed / 10) * 10 * (1 + (perc_increase / 100))

# Save the updated parameters to a new file
open("./test/scenarios/erp_reopt_inputs.json", "w") do f
    write(f, JSON.json(erp_data))
end

# ---------------------
# RERUN OPTIMIZATION WITH MODIFIED PARAMETERS
# ---------------------

# Load the updated inputs
p2 =   REoptInputs("./test/scenarios/erp_reopt_inputs.json")

# Initialize a new model
model2    =   Model(Xpress.Optimizer)
model2bau =   Model(Xpress.Optimizer)

# Run the REopt optimization again
results2 =   run_reopt([model2bau, model2], p2)

open("./test/scenarios/final_reopt_results.json", "w") do f
    write(f, JSON.json(results2))
end
# ---------------------
# FINAL RELIABILITY REPORT
# ---------------------

# Update reliability inputs based on the new results
reliability_inputs2                                =   reliability_inputs
reliability_inputs2["pv_size_kw"]                  =   results2["PV"]["size_kw"]
reliability_inputs2["critical_loads_kw"]           =   results2["ElectricLoad"]["critical_load_series_kw"]
reliability_inputs2["generator_size_kw"]           =   results2["Generator"]["size_kw"]
reliability_inputs2["battery_size_kw"]             =   results2["ElectricStorage"]["size_kw"]
reliability_inputs2["battery_size_kwh"]            =   results2["ElectricStorage"]["size_kwh"]
reliability_inputs2["pv_production_factor_series"] =   results2["PV"]["production_factor_series"]

# Compute final reliability metrics
reliability_results_final =   backup_reliability(results2, p2, reliability_inputs2)

datasets = Dict(
    "Original"    =>   reliability_results,
    "Iteration 2" =>   reliability_results2,
    "Final"       =>   reliability_results_final
)

# Compute descriptive statistics for each dataset
descriptive_statistics_all = Dict(
    name => Dict(
        key =>   isa(value, Vector{Float64}) ? descriptive_stats(value) : value
        for (key, value) in dataset
    )
    for (name, dataset) in datasets
)

println("Descriptive Statistics:")
println(descriptive_statistics_all)

open("./test/scenarios/stats.json", "w") do f
    write(f, JSON.json(descriptive_statistics_all))
end

# Function to plot comparison line charts
function compare_lineplots(key)
    # Assuming the key exists in all datasets
    if isa(datasets["Original"][key], Vector{Float64})
        p = plot(
            datasets["Original"][key] .* 100,  # Multiply by 100
            label     =   "Original",
            title     =   key,
            linewidth =   2,
            ylims     =   (0, 115),   # Set y-axis limits
            ylabel    =   "%",        # Label for y-axis
            legend    =   :topright
        )
        plot!(p, datasets["Iteration 2"][key] .* 100, label="Iteration 2", linewidth=2, linestyle=:dash)  # Multiply by 100
        plot!(p, datasets["Final"][key] .* 100, label="Final", linewidth=2, linestyle=:dot)  # Multiply by 100
        savefig("/Users/bpulluta/.julia/dev/REopt/.bp_local_testing/ERP/results/comparison_$(key)_lineplot.png")
    end
end

# Extract unique keys across all datasets (assuming they all have the same keys)
all_keys =   keys(datasets["Original"])

# Plot comparison line charts for each key
for key in all_keys
    compare_lineplots(key)
end

# Plot line chart for min and max fuel used
p_fuel = plot(
    ["Original", "Iteration 2", "Final"],
    [
        datasets["Original"]["min_fuel_used"],
        datasets["Iteration 2"]["min_fuel_used"],
        datasets["Final"]["min_fuel_used"]
    ],
    label     =   "Min Fuel Used",
    color     =   :blue,
    linewidth =   2,
    marker    =   :circle
)
plot!(
    p_fuel,
    ["Original", "Iteration 2", "Final"],
    [
        datasets["Original"]["max_fuel_used"],
        datasets["Iteration 2"]["max_fuel_used"],
        datasets["Final"]["max_fuel_used"]
    ],
    label     =   "Max Fuel Used",
    color     =   :red,
    linewidth =   2,
    marker    =   :circle
)

title!(p_fuel, "Min and Max Fuel Used Comparison")
xlabel!(p_fuel, "Dataset")
ylabel!(p_fuel, "Fuel Used")
savefig("/Users/bpulluta/.julia/dev/REopt/.bp_local_testing/ERP/results/min_max_fuel_used_comparison.png")

println("")
println("###########First Iteration: ")
summarize_reopt_results(results)

println("")
println("###########Second Iteration: ")
summarize_reopt_results(results2)
