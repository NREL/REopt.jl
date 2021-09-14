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
global hdl

using JSON

"""
    SAM_Battery
struct with inner constructor:
    ```julia
    SAM_Battery(file_path::String)
    ```

    where file_path is a path to the battery's JSON definition.
    Fields for the JSON file are defined at https://nrel-pysam.readthedocs.io/en/master/modules/BatteryStateful.html
    An example is provided at test\\data\\test_batt.json     
"""
mutable struct SAM_Battery
    params::AbstractDict
    batt_model::Ptr{Cvoid}
    batt_data::Ptr{Cvoid}

    function SAM_Battery(file_path::String)
        batt_model = nothing
        batt_data = nothing
        global hdl = nothing

        data = JSON.parsefile(file_path)
        print("Read in JSON file\n")
        try        
            if Sys.isapple() 
                libfile = "libssc.dylib"
            elseif Sys.islinux()
                libfile = "libssc.so"
            elseif Sys.iswindows()
                libfile = "ssc.dll"
            else
                @error """Unsupported platform for using the SAM Wind module. 
                        You can alternatively provide the Wind.prod_factor_series_kw"""
            end
            
            global hdl = joinpath(dirname(@__FILE__), "..", "sam", libfile)
            batt_model = @ccall hdl.ssc_module_create("battery_stateful"::Cstring)::Ptr{Cvoid}
            batt_data = @ccall hdl.ssc_data_create()::Ptr{Cvoid}  # data pointer
            @ccall hdl.ssc_module_exec_set_print(0::Cint)::Cvoid

            print("Populating data\n")
            for (key, value) in data
                try
                    if (typeof(value)<:Number)
                        @ccall hdl.ssc_data_set_number(batt_data::Ptr{Cvoid}, key::Cstring, value::Cdouble)::Cvoid
                    elseif (isa(value, Array))
                        if (ndims(value) == 1 && length(value) > 0)
                            if (isa(value[1], Number))
                                @ccall hdl.ssc_data_set_array(batt_data::Ptr{Cvoid}, key::Cstring, 
                                    value::Ptr{Cdouble}, length(value)::Cint)::Cvoid
                            elseif(isa(value[1], Array))
                                nrows = length(value)
                                ncols = length(value[1])
                                @ccall hdl.ssc_data_set_matrix(batt_data::Ptr{Cvoid}, key::Cstring, value::Ptr{Cdouble}, 
                                    Cint(nrows)::Cint, Cint(ncols)::Cint)::Cvoid
                            end
                        elseif (ndims(value) > 1)
                            nrows, ncols = size(value)
                            @ccall hdl.ssc_data_set_matrix(batt_data::Ptr{Cvoid}, key::Cstring, value::Ptr{Cdouble}, 
                                Cint(nrows)::Cint, Cint(ncols)::Cint)::Cvoid
                        else
                            print(key, " had dimension 0\n")
                        end
                    else
                        @error "Unexpected type in battery params array"
                        showerror(stdout, key)
                    end
                catch e
                    print("Error with ", key, "\n")
                    @error "Problem updating battery data in SAM C library!"
                    showerror(stdout, e)
                end
    
            end

            @ccall hdl.ssc_stateful_module_setup(batt_model::Ptr{Cvoid}, batt_data::Ptr{Cvoid})::Cint

        catch e
            @error "Problem calling SAM C library!"
            showerror(stdout, e)
        end

        new(data, batt_model, batt_data)
    end
end

"""
    run_sam_battery(batt::SAM_Battery, power::Vector{Float64})
Function takes a SAM_Battery, and runs it for steps equal to the length of power
Amount of time is defined in dt, as passed to the constructor of SAM_Battery
Units of power are in kW, positive is discharging, negative is charging
"""
function run_sam_battery(batt::SAM_Battery, power::Vector{Float64})
    for p in power
        try
            @ccall hdl.ssc_data_set_number(batt.batt_data::Ptr{Cvoid}, "input_power"::Cstring, p::Cdouble)::Cvoid
            
            if !Bool(@ccall hdl.ssc_module_exec(batt.batt_model::Ptr{Cvoid}, batt.batt_data::Ptr{Cvoid})::Cint)
                log_type = 0
                log_type_ref = Ref(log_type)
                log_time = 0
                log_time_ref = Ref(log_time)
                msg_ptr = @ccall hdl.ssc_module_log(batt.batt_model::Ptr{Cvoid}, 0::Cint, log_type_ref::Ptr{Cvoid}, 
                                                log_time_ref::Ptr{Cvoid})::Cstring
                msg = "no message from ssc_module_log."
                try
                    msg = unsafe_string(msg_ptr)
                finally
                    @error("SAM Battery simulation error: $msg")
                end
            end
        catch e
            @error "Problem running SAM stateful battery"
            showerror(stdout, e)
        end
    end
    return nothing # Should this be success/failure?
end

"""
    get_sam_battery_number(batt::SAM_Battery, key::String)::Float64
Possible keys are defined at https://nrel-pysam.readthedocs.io/en/master/modules/BatteryStateful.html
Only type "float" will be returned from this function, others will either need a seperate function or an extension/renaming of this function
"""
function get_sam_battery_number(batt::SAM_Battery, key::String)::Float64
    if (batt.batt_data != Ptr{Cvoid}(C_NULL) && batt.batt_model != Ptr{Cvoid}(C_NULL)) 
        val = convert(Cdouble, 0.0)
        ref = Ref(val)
        @ccall hdl.ssc_data_get_number(batt.batt_data::Ptr{Cvoid}, key::Cstring, ref::Ptr{Cdouble})::Cuchar #Returns bool
        return Float64(ref[])
    end
    @error "Battery variables were already freed. Can no longer read battery data."
end

"""
free_sam_battery(batt::SAM_Battery)::Nothing
Frees the underlying c memory associated with SAM battery.
If other functions attempt to use SAM_Battery after this is called, they will throw an error
"""
function free_sam_battery(batt::SAM_Battery)::Nothing
    @ccall hdl.ssc_module_free(batt.batt_model::Ptr{Cvoid})::Cvoid  
    batt.batt_model = Ptr{Cvoid}(C_NULL)
    @ccall hdl.ssc_data_free(batt.batt_data::Ptr{Cvoid})::Cvoid
    batt.batt_data = Ptr{Cvoid}(C_NULL)
    return nothing
end