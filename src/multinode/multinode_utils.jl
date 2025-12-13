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


function prepare_dss_file_for_multinode(folder, input_dss_filepath, output_dss_filepath)

	output_dss_filepath_reactors_processed = process_reactors(input_dss_filepath, folder*"/"*"temp_reactors_processed.dss")

	output_dss_filepath_redirects_removed = remove_redirect_lines(output_dss_filepath_reactors_processed, folder*"/"*"redirects_removed.dss")

	output_dss_filepath_multiphase_split_into_multiple_lines = split_multiphase_loads_into_separate_lines(output_dss_filepath_redirects_removed, folder*"/"*"temp_multiphase_split_into_multiple_lines.dss")  

	output_dss_filepath_loads_renamed_to_names_of_busses = rename_load_names_to_names_of_busses_with_phase_label(output_dss_filepath_multiphase_split_into_multiple_lines, folder*"/"*"temp_loads_renamed_to_busses_with_phase_label.dss")

	return output_dss_filepath_loads_renamed_to_names_of_busses
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
			 "~ R=$r X=$x Length=1 Units=none"]
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


function split_multiphase_loads_into_separate_lines()


	return output_filepath
end


function rename_load_names_to_names_of_busses_with_phase_label()
	

	return output_filepath
end

