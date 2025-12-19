# REopt®, Copyright (c) Alliance for Sustainable Energy, LLC. See also https://github.com/NREL/REopt.jl/blob/master/LICENSE.


function run_PowerModelsDistribution_using_just_dss_file()


end


function combine_dss_files_into_aggregated_dss_file(folder, new_file_name, existing_dss_files_list)
	# This function takes multiple separate dss files and combines them into one dss file
	# note: this function was created with the assistance of ChatGPT

	# The order of the files in the existing_dss_files_list matters
	
	aggregated_file_path = folder * "/" * new_file_name # note: the new_file_name should have .dss appended to the end of the string

	open(aggregated_file_path, "w") do x
		for file in existing_dss_files_list
			filepath = folder*"/"* file
			println(x) # this creates a new line
			println(x, "! Data from filename: ", file)
			println(x)

			for line in eachline(filepath)
				println(x, line)
			end
		end
	end

	return aggregated_file_path

end


function prepare_dss_file_for_multinode(Multinode_Inputs_struct, folder, input_dss_filepath) 

	# Convert the syntax "new object=" into simpler syntax
	output_dss_filepath_object_syntax_processed = modify_object_syntax(input_dss_filepath, folder*"/"*"temp_object_syntax_modified.dss")

	# Process the reactors
	output_dss_filepath_reactors_processed = process_reactors(output_dss_filepath_object_syntax_processed, folder*"/"*"temp_reactors_processed.dss")

	output_dss_filepath_redirects_removed = remove_redirect_lines(output_dss_filepath_reactors_processed, folder*"/"*"temp_redirects_removed.dss")

	output_dss_filepath_multiphase_split_into_multiple_lines = split_multiphase_loads_into_separate_lines(output_dss_filepath_redirects_removed, folder*"/"*"temp_multiphase_split_into_multiple_lines.dss")  

	output_dss_filepath_loads_renamed_to_names_of_busses, load_map = rename_load_names_to_names_of_busses_with_phase_label(output_dss_filepath_multiphase_split_into_multiple_lines, folder*"/"*"temp_loads_renamed_to_busses_with_phase_label.dss")

	output_dss_filepath_kw_kvar_modified = set_kw_and_kvar_loads_to_1_if_there_is_an_associated_REopt_node(Multinode_Inputs_struct, output_dss_filepath_loads_renamed_to_names_of_busses, folder*"/"*"temp_kw_and_kvar_loads_with_value_of_1.dss")

	dss_file_export = output_dss_filepath_kw_kvar_modified

	return dss_file_export, load_map
end


function modify_object_syntax(input_filepath::String, output_filepath::String)
	# This function was generated with the assistance of ChatGPT

	open(output_filepath, "w") do output
		for line in eachline(input_filepath)
			println(output, change_object_syntax(line))
		end
	end
	
	return output_filepath
end


function change_object_syntax(line)
	# This funcition was generated with the assistance of ChatGPT

	new_object_syntax_pattern = r"(?i)^\s*new\s+object\s*=\s*(\S+)"

	m = match(new_object_syntax_pattern, line)
	if m !== nothing
		object_name = lowercase(m.captures[1])
		return replace(line, new_object_syntax_pattern => "new $object_name"; count=1)
	else
		return line
	end

	return 
end


function set_kw_and_kvar_loads_to_1_if_there_is_an_associated_REopt_node(Multinode_Inputs, input_dss_file, output_dss_file)
	# This funcition was generated with the assistance of ChatGPT
	
	REopt_nodes = lowercase.(REopt.GenerateREoptNodesList(Multinode_Inputs))

	REopt_nodes = []
	REopt_phases = Dict()
    for i in Multinode_Inputs.REopt_inputs_list
        if string(i["Site"]["node"]) != Multinode_Inputs.facilitymeter_node
            push!(REopt_nodes, i["Site"]["node"])
			REopt_phases[lowercase(i["Site"]["node"])] = i["Settings"]["phase_numbers"]
        end
    end

	# If the node is part of the REopt nodes, then set the kW and the kVAR to 1
	# If the node is not part of the REopt nodes list, then set the kW and kVAR to 0

	open(output_dss_file, "w") do output
		for line in eachline(input_dss_file)
			if occursin(r"(?i)new\s+load\.", line) && occursin(r"(?i)bus1=",line)
				bus, phases = get_bus_and_phases(line)
								
				phase = phases[1] # There will only be one phase listed in each row due to the function split_multiphase_loads_into_separate_lines

				if (bus !== nothing) && (lowercase(bus) in REopt_nodes) 
					if phase in REopt_phases[lowercase(bus)]
						line = replace_kw_and_kvar(line, 1.0, 1.0)
					else
						line = replace_kw_and_kvar(line, 0.0, 0.0)
					end
				else
					line = replace_kw_and_kvar(line, 0.0, 0.0)
				end
			end
			write(output, line*"\n")
		end
	end
	
	return output_dss_file
end


function get_bus_and_phases(line::String)
	# This funcition was generated with the assistance of ChatGPT
	m = match(r"(?i)Bus1=([^\s\.]+)((?:\.\d+)*)",line)
	if m === nothing 
		return  nothing, Int[]
	end
	bus = m.captures[1]

	# Extract all digits after dots
	phase_str = m.captures[2]
	phases = isempty(phase_str) ? Int[] : parse.(Int,split(phase_str[2:end], "."))

	return bus, phases
end


function replace_kw_and_kvar(line::String, kw::Float64, kvar::Float64)
	# This funcition was generated with the assistance of ChatGPT
	line = replace(line, r"(?i)kW=[^\s]+" => "kW=$(kw)")
	line = replace(line, r"(?i)kvar=[^\s]+" => "kvar=$(kvar)")
	return line
end


function process_reactors(input_dss_filepath, output_dss_filepath)
	# This function removes features that REopt multinode does not model
	# This funcition was generated with the assistance of ChatGPT

	# Convert the series reactors to lines (series reactors are show as reactor types with two busses listed in the .dss file)
		# add code to remove shunt reactors (reactor types that only have one bus listed)
	new_line_prefix = "RXLine_" # label the lines with RXLine_ after they are converted from reactors
	
	open(output_dss_filepath, "w") do output
		open(input_dss_filepath, "r") do input

			block = String[]

			function flush_block()
				isempty(block) && return

				if isempty(block)
					return
				end

				first_line = block[1]

				stripped_line = strip(first_line) # isa String ? first_line : ""

				if startswith(lowercase(stripped_line), "new reactor.")
					handle_reactor_block(block, output, new_line_prefix)
				else
					# write non-reactor block verbatim
					for y in block
						println(output, y)
					end
				end

				empty!(block)
			end

			for line in eachline(input)
				stripped = line # strip(line) # isa String ? strip(line) : ""
				if startswith(lowercase(stripped), "new")
					# Start a new block
					flush_block()
					push!(block, line)
				elseif startswith(stripped, "~")
					# Continuation line
					push!(block, line)
				else
					flush_block()
					println(output, line)
				end
			end

			flush_block() # final block
		end
	end

	return output_dss_filepath
end


function handle_reactor_block(block, x, prefix)
	# This funcition was generated with the assistance of ChatGPT
	full = join(block, " ")
	has_bus2 = occursin(r"(?i)bus2\s*=", full) # This detects if it is a series reactor (and not a shunt reactor, because shunt reactors won't have a bus 2)
	if has_bus2
		line_def = reactor_block_to_line(full, prefix)
		println(x, line_def)
	else
		println(x, "! Shunt reactor removed:")
		for y in block
			println(x, "! ", y)
		end
	end
end


function reactor_block_to_line(full::String, prefix::String)
	# This function was generated with the assistance of ChatGPT
	
	name = extract_reactor_name(full)
	bus1 = extract_prop(full, "bus1", "UNKNOWN")
	bus2 = extract_prop(full, "bus2", "UNKNOWN")
	phases = extract_prop(full, "phases", "3") 
	r = extract_prop(full, "r", "0.0")
	x = extract_prop(full, "x", "0.0")

	line_name = prefix*name

	lines = ["New Line.$line_name Bus1=$bus1 Bus2=$bus2 Phases=$phases",
			 "~ R1=$r X1=$x Length=1 Units=Ft"]  # line objects in OpenDSS take the resistance and reactance as R1 and X1 variables, respectively. Resistance and reactance can also be entered using other variables in the OpenDSS format.
	return join(lines, "\n")
end


function extract_prop(text::String, key::String, default::String)
	# This function was generated with the assistance of ChatGPT
	m = match(Regex("(?i)$key\\s*=\\s*([^\\s]+)"), text)
	return m == nothing ? default : m.captures[1]
end

function extract_reactor_name(full::String)
	# This function was generated with the assistance of ChatGPT
	m = match(r"(?i)new\s+reactor\.([^\s]+)",full)
	return m == nothing ? "UNKNOWN" : m.captures[1]
end


function remove_redirect_lines(input_filepath::String, output_filepath::String)
	# This function was generated with the assistance of ChatGPT
	open(output_filepath, "w") do output
		open(input_filepath, "r") do input
			for line in eachline(input)
				stripped = strip(line)
				# Skip lines starting with "redirect" (case-insensitive)
				if startswith(lowercase(stripped), "redirect")
					continue
				else
					println(output, line)
				end
			end
		end
	end

	return output_filepath
end


function split_multiphase_loads_into_separate_lines(input_filepath::String, output_filepath::String)
	# This function was generated with assistance from ChatGPT

	# This function handles how voltages will need to be adjusted, depending on if they are delta or wye connected
	
	sqrt3 = sqrt(3.0)

	open(output_filepath, "w") do output
		open(input_filepath, "r") do input
			for line in eachline(input)
				stripped = strip(line)
				
				# Only process New Load lines
				if startswith(lowercase(stripped), "new load.")
					m_name = match(r"(?i)new\s+load\.([^\s]+)",line)
					m_bus = match(r"(?i)bus1\s*=\s*([^\s]+)", line)
					m_phases = match(r"(?i)phases\s*=\s*(\d+)",line)
					m_conn = match(r"(?i)conn\s*=\s*(\w+)",line)
					m_kv = match(r"(?i)kv\s*=\s*([\d\.]+)",line)
					m_kw = match(r"(?i)kw\s*=\s*([\d\.]+)",line)
					m_kvar = match(r"(?i)kvar\s*=\s*([\d\.]+)",line)

					if m_name !== nothing &&
						m_bus !== nothing &&
						m_phases !== nothing &&
						parse(Int,m_phases.captures[1]) > 1 &&
						m_conn !== nothing &&
						m_kv !== nothing &&
						m_kw !== nothing

						orig_name = m_name.captures[1]
						bus_full = m_bus.captures[1]
						nph = parse(Int, m_phases.captures[1])
						conn = lowercase(m_conn.captures[1])
						kv_orig = parse(Float64, m_kv.captures[1])
						kw_orig = parse(Float64, m_kw.captures[1])

						parts = split(bus_full, ".")
						bus_id = parts[1]
						phases = parts[2:end]

						# Voltage scaling
						kv_new = conn == "delta" ? kv_orig / sqrt3 : kv_orig

						# Power scaling
						kw_new = kw_orig / nph

						for ph in phases
							new_name = "$(orig_name)_phase$(ph)"
							newline = line
							#newline = replace(newline, r"(?i)(new\s+load\.)[^\s]+" => "\\1$new_name")
							
							newline = replace_dss_load_name(newline, new_name)

							newline = replace(newline, r"(?i)phases\s*=\s*\d+" => "phases=1")
							newline = replace(newline, r"(?i)bus1\s*=\s*[^\s]+" => "Bus1=$(bus_id).$(ph)")
							newline = replace(newline, r"(?i)kv\s*=\s*[\d\.]+" => "kV=$(round(kv_new, digits=6))")
							newline = replace(newline, r"(?i)kw\s*=\s*[\d\.]+" => "kW=$(round(kw_new, digits=6))")

							println(output, newline)
						end

						continue # used to skip the original multiphase line
					end
				end

				# By default, re-write the unchanged line
				println(output, line)
			end
		end
	end

	return output_filepath
end


function rename_load_names_to_names_of_busses_with_phase_label(input_filepath::String, output_filepath::String)
	# This function was generated with assistance from ChatGPT

	# NOTE: this function will not handle multiphase busses (e.g. Bus1=9.1.2.3). This assumes that all loads have been assigned to a single phase bus (which is what currently is required for multinode)

	load_to_bus_mapping = Dict{String, Tuple{String,String}}()

	open(output_filepath, "w") do output
		open(input_filepath, "r") do input
			for line in eachline(input)
				stripped = strip(line)

				if startswith(lowercase(stripped), "new load.")
					#Extract the original load name
					m_name = match(r"(?i)new\s+load\.([^\s]+)", line)

					# Extract Bus1 information
					m_bus = match(r"(?i)bus1\s*=\s*([^\s]+)",line)

					if (m_name !== nothing) && (m_bus !== nothing)
						orig_name = m_name.captures[1]
						bus_full = m_bus.captures[1]

						parts = split(bus_full,".")
						bus_id = parts[1]
						phase_id = length(parts) > 1 ? parts[2] : "1"  # assume the phase ID is 1 by default

						new_name = "Load$(bus_id)_phase$(phase_id)"

						# Store the mapping
						load_to_bus_mapping[orig_name] = (new_name, bus_full)

						# Replace the load name in the dss file line
						#line = replace(line, r"(?i)(new\s+load\.)[^\s]+"=>"\\1$new_name")
						line = replace_dss_load_name(line, new_name)
					end
				end

				println(output, line)
			end
		end
	end

	return output_filepath, load_to_bus_mapping
end


function replace_dss_load_name(line::String, new_name::String)
	# This function was generated with the assistance of ChatGPT

	m = match(r"(?i)^(new\s+load\.)[^\s]+(.*)$", line)
	if m == nothing
		return line
	end
	prefix = m.captures[1] # This is for "New Load."
	rest = m.captures[2] # everything after the name

	return prefix*new_name*rest

end


