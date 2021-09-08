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
module SAM_batt_stateful
export SAM_Battery

global hdl

using JSON

struct SAM_Battery
    params
    batt_model
    batt_data

    function SAM_Battery(file_path::String)
        batt_model = nothing
        batt_data = nothing
        global hdl = nothing

        data = JSON.parsefile(file_path)
        print("Read in JSON file")
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

            print("Populating data")
            for (key, value) in data
                try
                    if (typeof(value)<:Number)
                        @ccall hdl.ssc_data_set_number(batt_data::Ptr{Cvoid}, key::Cstring, value::Cdouble)::Cvoid
                    elseif (isa(value, Array))
                        if (ndims(value) > 1)
                            @ccall hdl.ssc_data_set_array(batt_data::Ptr{Cvoid}, key::Cstring, 
                                value::Ptr{Cdouble}, length(value)::Cint)::Cvoid
                        else
                            nrows, ncols = size(value)
                            @ccall hdl.ssc_data_set_matrix(batt_data::Ptr{Cvoid}, key::Cstring, value::Ptr{Cdouble}, 
                                Cint(nrows)::Cint, Cint(ncols)::Cint)::Cvoid
                        end
                    else
                        @error "Unexpected type in battery params array"
                        showerror(stdout, key)
                    end
                catch e
                    @error "Problem updating battery data in SAM C library!"
                    showerror(stdout, e)
                end
    
            end

        catch e
            @error "Problem calling SAM C library!"
            showerror(stdout, e)
        end

        new(data, batt_model, batt_data)
    end
end

end
