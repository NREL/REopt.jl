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
function add_thermosyphon_results(m::JuMP.AbstractModel, p::REoptInputs, d::Dict)
    r = Dict{String, Any}()
    r["min_annual_active_cooling_mmbtu"] = p.s.thermosyphon.min_annual_active_cooling_mmbtu
    r["min_monthly_active_cooling_mmbtu"] = p.s.thermosyphon.min_monthly_active_cooling_mmbtu
    r["active_cooling_series_btu_per_hour"] = round.(value.(m[:ThermosyphonActiveCooling]) .* 1000000, digits=6)
    r["annual_active_cooling_mmbtu"] = round(value(sum(m[:ThermosyphonActiveCooling])/p.s.settings.time_steps_per_hour), digits=6)
    r["monthly_active_cooling_mmbtu"] = round.(value.([sum(m[:ThermosyphonActiveCooling][ts] for ts in p.s.electric_tariff.time_steps_monthly[mth])/p.s.settings.time_steps_per_hour for mth in p.months]), digits=6)
    r["electric_consumption_series_kw"] = round.(value.(m[:ThermosyphonElectricConsumption]),digits=4)
    r["annual_electric_consumption_kwh"] = round(value(sum(m[:ThermosyphonElectricConsumption])/p.s.settings.time_steps_per_hour), digits=6)
    r["coefficient_of_performance_series_mmbtu_per_kwh"] = round.(p.s.thermosyphon.coefficient_of_performance_series_mmbtu_per_kwh, digits=4)
    r["annual_average_coefficient_of_performance_mmbtu_per_kwh"] = r["annual_active_cooling_mmbtu"] .* 1000000 ./ r["annual_electric_consumption_kwh"]
    # r["active_cooling_rate_mmbtu_per_hour"] = p.s.thermosyphon.active_cooling_rate_mmbtu_per_hour
    # r["time_steps_can_actively_cool"] = p.s.thermosyphon.time_steps_can_actively_cool
    # r["time_steps_passively_cooling"] = p.s.thermosyphon.time_steps_passively_cooling

    d["Thermosyphon"] = r
    nothing
end