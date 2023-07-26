# Really only meaningful incentives for PV for relevant techs; none for fuel cells or battery
# The program description sometimes describes that the parameters do not fully define the program constraints, 
# e.g. the DC production incentive of $0.5/kWh has a tiered value after 2023, and only applies to 10 kW or less, but
# the parameter_set_id does not have a parameter of source=System, qualifier=max, and units=kW

# ONLY TX has a somewhat competitive capacity-based vs production-based Value
# Most states only have one or the other, and if they do have both, the production is typically the best by far
# Some states have different sizing classes for incentives, but I think that can be done with multiply REopt runs
function get_incentive_data(db::SQLite.DB; state_abbr::String="CO", tech::String="PV")
    # Filter incentives database by technology and state, only keeping state-wide and non-expired incentives
    tech_map = Dict("PV" => 7, "ElectricStorage" => 207, "FuelCellsNonRenewable" => 15, "FuelCellsRenewable" => 124, "Wind" => 8)
    tech_number = tech_map[tech]
    state = DBInterface.execute(db, "SELECT * FROM state WHERE abbreviation='$state_abbr'") |> DataFrame
    state_id = state[1,1]
    todays_date = Dates.today()
    todays_date_str = Dates.format(todays_date, "yyyymmdd")
    state_programs = DBInterface.execute(db, "SELECT * FROM program WHERE (state_id=$state_id) 
        AND (is_entire_state=1)
        AND ((end_date > $todays_date_str) OR (end_date IS NULL))") |> DataFrame
    tech_programs = DBInterface.execute(db, "SELECT * FROM program_technology WHERE technology_id=$tech_number") |> DataFrame
    tech_state_program_ids = intersect(state_programs[!,"id"],tech_programs[!,"program_id"])
    tech_state_program_ids_tuple = tuple(tech_state_program_ids...)
    parameter_set = sql_select_helper_variable_length(db; table_name="parameter_set", column_name="program_id", data_tuple=tech_state_program_ids_tuple)
    # parameter_set = DBInterface.execute(db, "SELECT * FROM parameter_set WHERE program_id IN $tech_state_program_ids_tuple") |> DataFrame
    parameter_set_technology = DBInterface.execute(db, "SELECT * FROM parameter_set_technology WHERE technology_id=$tech_number") |> DataFrame
    tech_state_parameter_set = intersect(parameter_set[!,"id"], parameter_set_technology[!,"set_id"])
    parameter_set_ids_tuple = tuple(tech_state_parameter_set...)
    parameters = sql_select_helper_variable_length(db; table_name="parameter", column_name="parameter_set_id", data_tuple=parameter_set_ids_tuple)

    data = Dict()
    for set_id in unique(parameters[!, "parameter_set_id"])
        program_id = parameter_set[parameter_set[!, "id"].==set_id, "program_id"][1]
        data[program_id] = Dict()
        param_sub = parameters[parameters.parameter_set_id.==set_id, :]
        for param in eachrow(param_sub)
            if !ismissing(param["units"]) && !ismissing(param["source"])
                if occursin("kWh", param["units"]) || occursin("MWh", param["units"])
                    # Production based incentive
                    divide_by = 1.0
                    if occursin("MWh", param["units"])
                        divide_by = 1000.0
                    end
                    data[program_id]["production_based_incentive_per_kwh"] = param["amount"] / divide_by
                    if occursin("year", param["units"])
                        # Limited number of years of production incentive
                        for i in 1:30
                            if occursin("i", param["units"])
                                data[program_id]["production_incentive_years"] = i
                                break
                            end
                        end
                    end
                elseif occursin(r"\$/W", param["units"]) || occursin(r"\$/kW", param["units"])
                    # Capacity-based incentive ($/kW), could be AC or DC basis
                    if occursin(r"\$/W", param["units"])
                        incentive_per_kw = param["amount"] * 1000.0
                    else
                        incentive_per_kw = param["amount"]
                    end
                    data[program_id]["capacity_based_incentive_per_kw"] = incentive_per_kw
                    if occursin("AC", param["units"])
                        data[program_id]["capacity_based_incentive_basis_ac_or_dc"] = "AC"
                    else
                        data[program_id]["capacity_based_incentive_basis_ac_or_dc"] = "DC"
                    end
                elseif ismissing(param["qualifier"]) && occursin(r"\%", param["units"])
                    # %-based incentives
                    data[program_id]["percent_cost_based_incentive"] = param["amount"]
                elseif param["source"] == "System"
                    # Size limits (min/max kW), could be AC or DC basis
                    divide_by = 1000.0  # For W (Watts)
                    if occursin("kW", param["units"])
                        divide_by = 1.0
                    elseif occursin("MW", param["units"])
                        divide_by = 0.001
                    end
                    if param["qualifier"] == "max"
                        data[program_id]["max_kw"]= param["amount"] / divide_by
                    elseif param["qualifier"] == "min"
                        data[program_id]["min_kw"] = param["amount"] / divide_by
                    end
                    if occursin("AC", param["units"])
                        data[program_id]["size_limit_basis_ac_or_dc"] = "AC"
                    else
                        data[program_id]["size_limit_basis_ac_or_dc"] = "DC"
                    end
                elseif !ismissing(param["qualifier"])
                    if param["source"] == "Incentive" && param["units"] == "\$"
                        # Max incentive value in $; some have NULL for qualifier but we can't know if it's max or min, so ignoring those
                        if param["qualifier"] == "max" 
                            data[program_id]["max_incentive_amount_dollar"] = param["amount"]
                        elseif param["qualifier"] == "min"
                            data[program_id]["min_incentive_amount_dollar"] = param["amount"]
                        end
                    elseif param["qualifier"] == "max" && occursin(r"\%", param["units"])
                        # Max incentive as a percentage of cost
                        data[program_id]["max_percent_of_cost"] = param["amount"]
                    end                        
                end
            end
        end
    end

    for program_id in keys(data)
        if isempty(data[program_id])
            delete!(data, program_id)
        elseif !("capacity_based_incentive_per_kw" in keys(data[program_id])) && !("production_based_incentive_per_kwh" in keys(data[program_id]))
            delete!(data, program_id) 
        end
    end

    return data
end


function sql_select_helper_variable_length(db::SQLite.DB; table_name::String="", column_name::String="", data_tuple::Tuple=())
    if length(data_tuple) >= 2
        data_df = DBInterface.execute(db, "SELECT * FROM $table_name WHERE $column_name IN $data_tuple") |> DataFrame
    elseif length(data_tuple) == 1
        data_df = DBInterface.execute(db, "SELECT * FROM $table_name WHERE $column_name=$(data_tuple[1])") |> DataFrame
    else
        data_df = DBInterface.execute(db, "SELECT * FROM $table_name WHERE $column_name=1") |> DataFrame
        delete!(data_df, :)
    end
    return data_df
end