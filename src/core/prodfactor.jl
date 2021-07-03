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
function prodfactor(pv::PV, latitude::Real, longitude::Real; timeframe="hourly")

    if !(ismissing(pv.prod_factor_series_kw))
        return pv.prod_factor_series_kw
    end

    url = string("https://developer.nrel.gov/api/pvwatts/v6.json", "?api_key=", nrel_developer_key,
        "&lat=", latitude , "&lon=", longitude, "&tilt=", pv.tilt,
        "&system_capacity=1", "&azimuth=", pv.azimuth, "&module_type=", pv.module_type,
        "&array_type=", pv.array_type, "&losses=", round(pv.losses*100, digits=3), "&dc_ac_ratio=", pv.dc_ac_ratio,
        "&gcr=", 0.4, "&inv_eff=", pv.inv_eff*100, "&timeframe=", timeframe, "&dataset=nsrdb",
        "&radius=", 100
    )

    try
        @info "Querying PVWatts for prodfactor with " pv.name
        r = HTTP.get(url)
        response = JSON.parse(String(r.body))
        if r.status != 200
            error("Bad response from PVWatts: $(response["errors"])")
            # julia does not get here even with status != 200 b/c it jumps ahead to CIDER/reopt/src/core/reopt_inputs.jl:114
            # and raises ArgumentError: indexed assignment with a single value to many locations is not supported; perhaps use broadcasting `.=` instead?
        end
        @info "PVWatts success."
        watts = get(response["outputs"], "ac", []) / 1000  # scale to 1 kW system (* 1 kW / 1000 W)

        return collect(watts)
    catch e
        return "Error occurred : $e"
    end
end


function prodfactor(g::AbstractGenerator; ts_per_hour::Int=1)
    return ones(8760 * ts_per_hour)
end
