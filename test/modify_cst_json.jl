using JSON

json_file = "./scenarios/pv_cst_tes.json"

# Read with UTF-8 encoding
data_str = open(json_file, "r") do f
    read(f, String)
end

# Parse JSON
data = JSON.parse(data_str)

# Modify CST by adding new parameters
data["CST"]["inlet_temp"] = 250
data["CST"]["outlet_temp"] = 350

# Remove parameters from CST["SSC_inputs"]
keys_to_remove = ["T_loop_in_des", "T_loop_out", "T_tank_hot_inlet_min", "hot_tank_Thtr", "cold_tank_Thtr"]  # Replace with actual keys

for key in keys_to_remove
    delete!(data["CST"]["SSC_Inputs"], key)
end

# Save the modified JSON back to the file
open(json_file, "w") do f
    JSON.print(f, data, 2)  # Pretty-print with indentation
end
